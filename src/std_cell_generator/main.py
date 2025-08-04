import streamlit as st
import os
import time
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import random
import re
import asyncio
import nest_asyncio
from dotenv import load_dotenv
from langchain.prompts import PromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_google_genai import ChatGoogleGenerativeAI, GoogleGenerativeAIEmbeddings
from langchain_community.vectorstores import FAISS
from langchain.docstore.document import Document

# Fix for the asyncio event loop error in Streamlit's thread
nest_asyncio.apply()


def run():
    """
    This function contains the entire Streamlit UI and logic for the Standard Cell Generator.
    """
    # --- Configuration ---
    FAISS_INDEX_PATH = "data/std_cell_datasets/faiss_mag_index_st"
    GENERATED_MAG_DIR = "examples/std_cells/generated_mag_st"

    # ==============================================================================
    # VISUALIZATION LOGIC
    # ==============================================================================
    _parsed_cell_cache = {}

    def parse_mag_data_hierarchical(file_path, current_dir=None):
        abs_file_path = os.path.abspath(file_path)
        if abs_file_path in _parsed_cell_cache:
            return _parsed_cell_cache[abs_file_path]
        if current_dir is None: current_dir = os.path.dirname(abs_file_path)
        full_file_path = os.path.join(current_dir, os.path.basename(file_path))
        try:
            with open(full_file_path, 'r') as file: mag_content = file.read()
        except FileNotFoundError:
            st.warning(f"Sub-cell file not found: '{os.path.basename(full_file_path)}'. Instance will be skipped.")
            return None
        except Exception as e:
            st.error(f"Error reading file '{full_file_path}': {e}"); return None

        parsed_data = {"header": {}, "layers": {}, "instances": []}
        current_layer, current_instance = None, None
        for line in mag_content.strip().split('\n'):
            line = line.strip()
            if not line: continue
            parts = line.split()
            command = parts[0] if parts else ""
            if line.startswith("<<") and line.endswith(">>"):
                layer_name = line.strip("<<>> ").strip()
                if layer_name != "end":
                    current_layer = layer_name
                    if current_layer not in parsed_data["layers"]:
                        parsed_data["layers"][current_layer] = {"rects": [], "labels": []}
            elif command == "rect" and len(parts) == 5 and current_layer:
                try: parsed_data["layers"][current_layer]["rects"].append({"x1": int(parts[1]), "y1": int(parts[2]), "x2": int(parts[3]), "y2": int(parts[4])})
                except (ValueError, IndexError): pass
            elif command == "use":
                if current_instance: parsed_data["instances"].append(current_instance)
                if len(parts) >= 3:
                    sub_file_path = os.path.join(os.path.dirname(full_file_path), f"{parts[1]}.mag")
                    current_instance = {"cell_type": parts[1], "instance_name": parts[2], "parsed_content": parse_mag_data_hierarchical(sub_file_path, os.path.dirname(full_file_path)),"transform": [1, 0, 0, 0, 1, 0], "box": [0, 0, 0, 0]}
                    if not current_instance["parsed_content"]: current_instance = None
            elif command == "transform" and current_instance:
                try: current_instance["transform"] = [int(v) for v in parts[1:]]
                except (ValueError, IndexError): pass
            elif command == "box" and current_instance:
                try: current_instance["box"] = [int(v) for v in parts[1:]]
                except (ValueError, IndexError): pass
            elif line == "<< end >>" and current_instance:
                parsed_data["instances"].append(current_instance)
                current_instance = None
        if current_instance: parsed_data["instances"].append(current_instance)
        _parsed_cell_cache[abs_file_path] = parsed_data
        return parsed_data

    def visualize_hierarchical_layout(file_path: str):
        _parsed_cell_cache.clear()
        parsed_data = parse_mag_data_hierarchical(file_path)
        if not parsed_data: return None
        fig, ax = plt.subplots(figsize=(15, 12))
        min_x, max_x, min_y, max_y = float('inf'), float('-inf'), float('inf'), float('-inf')
        layer_colors = {}
        def get_random_color(): return (random.random(), random.random(), random.random())
        def _apply_transform(x, y, T): return (T[0] * x + T[1] * y + T[2], T[3] * x + T[4] * y + T[5])
        def _draw_elements(data_to_draw, current_transform=[1, 0, 0, 0, 1, 0]):
            nonlocal min_x, max_x, min_y, max_y
            for layer_name, layer_data in data_to_draw["layers"].items():
                if layer_name not in layer_colors: layer_colors[layer_name] = get_random_color()
                color = layer_colors[layer_name]
                for rect in layer_data.get("rects", []):
                    tx1, ty1 = _apply_transform(rect["x1"], rect["y1"], current_transform)
                    tx2, ty2 = _apply_transform(rect["x2"], rect["y2"], current_transform)
                    width, height = abs(tx2 - tx1), abs(ty2 - ty1)
                    x_start, y_start = min(tx1, tx2), min(ty1, ty2)
                    min_x, max_x = min(min_x, x_start), max(max_x, x_start + width)
                    min_y, max_y = min(min_y, y_start), max(max_y, y_start + height)
                    ax.add_patch(patches.Rectangle((x_start, y_start), width, height, linewidth=1, edgecolor='black', facecolor=color, alpha=0.7))
            for instance in data_to_draw.get("instances", []):
                if instance.get("parsed_content"): _draw_elements(instance["parsed_content"], instance["transform"])
        _draw_elements(parsed_data)
        if not all(v != float('inf') and v != float('-inf') for v in [min_x, max_x, min_y, max_y]):
            plt.close(fig); return None
        padding = (max_x - min_x) * 0.1 if (max_x > min_x) else 10
        ax.set_xlim(min_x - padding, max_x + padding)
        ax.set_ylim(min_y - padding, max_y + padding)
        ax.set_aspect('equal', adjustable='box'); ax.set_title(f"Hierarchical Layout: {os.path.basename(file_path)}", fontsize=16); ax.grid(True, linestyle='--', alpha=0.6)
        return fig

    # ==============================================================================
    # DATA LOADING & AI GENERATION
    # ==============================================================================
    @st.cache_resource(show_spinner="Initializing Vector Store...")
    def get_retriever():
        load_dotenv(); api_key = os.getenv("GOOGLE_API_KEY")
        if not api_key: st.error("GOOGLE_API_KEY not found."); st.stop()
        embeddings = GoogleGenerativeAIEmbeddings(model="models/embedding-001", google_api_key=api_key)
        if not os.path.exists(FAISS_INDEX_PATH):
            st.error(f"FAISS index not found at '{FAISS_INDEX_PATH}'. Please ensure the index is created and available.")
            st.stop()
        vector_store = FAISS.load_local(FAISS_INDEX_PATH, embeddings, allow_dangerous_deserialization=True)
        return vector_store.as_retriever(search_kwargs={"k": 3})

    class MagicLayoutGenerator:
        def __init__(self, retriever):
            load_dotenv(); api_key = os.getenv("GOOGLE_API_KEY")
            if not api_key: raise ValueError("GOOGLE_API_KEY not found.")
            self.llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", google_api_key=api_key, temperature=0.1)
            self.retriever = retriever
            self.synthesis_chain = PromptTemplate.from_template("CONTEXTS:\n{context}\n\nQUESTION:\n{question}\n\nBased on the contexts, generate a .mag file for the question. The response must be ONLY the raw .mag file content, starting with 'magic' and ending with '<< end >>'.") | self.llm
            self.improvement_chain = PromptTemplate.from_template("ORIGINAL .MAG FILE:\n{original_mag}\n\nUSER'S IMPROVEMENT REQUEST:\n{improvement_request}\n\nRegenerate the .mag file to incorporate the request. The output MUST be a complete, valid .mag file.") | self.llm

        def stream_single_cell(self, query: str):
            """Yields context first, then streams the LLM response for the .mag file."""
            retrieved_docs = self.retriever.invoke(query)
            if not retrieved_docs:
                yield {"type": "context", "data": "No relevant contexts found."}
                yield {"type": "content_chunk", "data": ""}
                return

            context_str = "".join([f"--- CONTEXT {i+1}: From file '{os.path.basename(doc.metadata.get('source', 'Unknown'))}' ---\n{doc.page_content}\n\n" for i, doc in enumerate(retrieved_docs)])
            yield {"type": "context", "data": context_str}
            
            llm_stream = self.synthesis_chain.stream({"context": context_str, "question": query})
            for chunk in llm_stream:
                yield {"type": "content_chunk", "data": chunk.content}

        def improve_single_cell(self, original_mag_content: str, improvement_request: str):
            response = self.improvement_chain.invoke({"original_mag": original_mag_content, "improvement_request": improvement_request})
            new_mag_content = response.content
            dependencies = set(re.findall(r"^\s*use\s+([\w\d_]+)", new_mag_content, re.MULTILINE))
            return {"content": new_mag_content, "dependencies": dependencies}

    # ==============================================================================
    # STREAMLIT APPLICATION UI
    # ==============================================================================
    try:
        retriever = get_retriever()
        generator = MagicLayoutGenerator(retriever)
    except Exception as e:
        st.error(f"💥 **Initialization Error:** {e}"); st.stop()

    if "generation_queue" not in st.session_state: st.session_state.generation_queue = []
    if "completed_cells" not in st.session_state: st.session_state.completed_cells = {}
    if "current_cell_data" not in st.session_state: st.session_state.current_cell_data = None
    if "mode" not in st.session_state: st.session_state.mode = "Automatic"

    st.title("🤖 Interactive Chip Layout Designer")
    st.write("An AI tool for generating, visualizing, and iteratively refining VLSI layouts.")

    with st.container(border=True):
        st.subheader("⚙️ Control Panel")
        st.session_state.mode = st.radio("**Select Mode**", ["Automatic", "Strict Review"], horizontal=True, help="**Automatic**: Generate all components at once. **Strict Review**: Pause to review and improve each component.")
        with st.form(key='design_form'):
            query = st.text_input("**Design Prompt**", "a 2-input NAND gate")
            filename = st.text_input("**Top-level Filename**", "my_nand.mag")
            if st.form_submit_button(label="🚀 Start New Generation", use_container_width=True):
                if query and filename:
                    st.session_state.generation_queue = [(query, os.path.splitext(filename)[0])]
                    st.session_state.completed_cells = {}
                    st.session_state.current_cell_data = None
                    os.makedirs(GENERATED_MAG_DIR, exist_ok=True)
                else: st.error("Please provide both a prompt and a filename.")
    st.divider()

    if st.session_state.generation_queue:
        if st.session_state.current_cell_data is None:
            current_query, current_cell_name = st.session_state.generation_queue[0]
            st.header(f"Processing: `{current_cell_name}`")
            st.info("Live generation in progress...", icon="⚡")

            col1, col2 = st.columns(2)
            with col1: st.subheader("📄 Live Generated Code"); code_area = st.empty()
            with col2: st.subheader("🖼️ Live Visualization"); plot_area = st.empty()
            context_area = st.empty()

            fig, ax = plt.subplots(figsize=(15, 12))
            ax.set_aspect('equal', adjustable='box'); ax.set_title("Live Layout Generation", fontsize=18); ax.grid(True, linestyle='--', alpha=0.6)
            plot_area.pyplot(fig)

            full_mag_content, line_buffer, current_layer = "", "", None
            layer_colors = {}
            def get_random_color(): return (random.random(), random.random(), random.random())

            response_stream = generator.stream_single_cell(current_query)
            for response in response_stream:
                if response["type"] == "context":
                    context_area.expander("View AI Context Used for this Generation").text(response["data"])
                elif response["type"] == "content_chunk":
                    chunk = response["data"]
                    full_mag_content += chunk
                    line_buffer += chunk
                    code_area.code(full_mag_content, language='text')
                    if '\n' in line_buffer:
                        lines, line_buffer = line_buffer.rsplit('\n', 1)
                        for line in lines.split('\n'):
                            line = line.strip()
                            parts = line.split()
                            if line.startswith("<<"):
                                layer_name = line.strip("<<>> ").strip()
                                if layer_name != "end" and layer_name not in layer_colors:
                                    current_layer = layer_name
                                    layer_colors[current_layer] = get_random_color()
                                    ax.legend(handles=[patches.Patch(color=c, label=n, alpha=0.7) for n, c in layer_colors.items()], loc='upper right')
                            elif parts and parts[0] == "rect" and len(parts) == 5 and current_layer:
                                try:
                                    x1, y1, x2, y2 = map(int, parts[1:5])
                                    width, height = abs(x2 - x1), abs(y2 - y1)
                                    x_start, y_start = min(x1, x2), min(y1, y2)
                                    ax.add_patch(patches.Rectangle((x_start, y_start), width, height, linewidth=1.5, edgecolor='black', facecolor=layer_colors[current_layer], alpha=0.75))
                                    ax.relim(); ax.autoscale_view()
                                    plot_area.pyplot(fig)
                                except (ValueError, IndexError): continue
            
            st.session_state.current_cell_data = {"name": current_cell_name, "content": full_mag_content}
            plt.close(fig)

        if st.session_state.current_cell_data:
            data = st.session_state.current_cell_data
            cell_name, mag_content = data['name'], data['content']
            
            file_path = os.path.join(GENERATED_MAG_DIR, f"{cell_name}.mag")
            with open(file_path, "w") as f: f.write(mag_content)

            dependencies = set(re.findall(r"^\s*use\s+([\w\d_]+)", mag_content, re.MULTILINE))

            if st.session_state.mode == "Strict Review":
                st.info("Generation complete. Please review the final layout below.", icon="✅")
                st.subheader("🔬 Review Component")
                with st.container(border=True):
                    with st.form("review_form"):
                        improvement_prompt = st.text_area("Improvement Request (optional)", placeholder="e.g., Make the routing more compact.")
                        approve_button = st.form_submit_button("👍 Looks Good, Continue", use_container_width=True)
                        improve_button = st.form_submit_button("💡 Improve This Component", use_container_width=True)
                    
                    if approve_button:
                        st.session_state.completed_cells[cell_name] = mag_content
                        st.session_state.generation_queue.pop(0)
                        for dep in dependencies:
                            if dep not in st.session_state.completed_cells and all(dep != item[1] for item in st.session_state.generation_queue):
                                st.session_state.generation_queue.append((f"a {dep} layout", dep))
                        st.session_state.current_cell_data = None
                        st.rerun()
                    
                    if improve_button and improvement_prompt:
                        with st.spinner(f"AI is improving '{cell_name}'..."):
                            improved_result = generator.improve_single_cell(mag_content, improvement_prompt)
                            st.session_state.current_cell_data = {
                                "name": cell_name,
                                "content": improved_result['content']
                            }
                        st.rerun()
            else: # Automatic Mode
                st.session_state.completed_cells[cell_name] = mag_content
                st.session_state.generation_queue.pop(0)
                for dep in dependencies:
                    if dep not in st.session_state.completed_cells and all(dep != item[1] for item in st.session_state.generation_queue):
                        st.session_state.generation_queue.append((f"a {dep} layout", dep))
                st.session_state.current_cell_data = None
                st.success(f"Automatically approved '{cell_name}'. Continuing...")
                time.sleep(1)
                st.rerun()

    elif st.session_state.completed_cells:
        st.balloons(); st.header("🎉 Generation Complete!"); st.write("All components have been successfully generated.")