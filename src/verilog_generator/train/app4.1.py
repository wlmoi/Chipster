import streamlit as st
import os
import glob
import pandas as pd
from typing import List, TypedDict, Dict
import torch
import re
import json
import graphviz
import subprocess
import difflib

from dotenv import load_dotenv

from langchain_community.document_loaders import CSVLoader
from langchain.text_splitter import RecursiveCharacterTextSplitter
from langchain_community.vectorstores import FAISS
from langchain_huggingface import HuggingFaceEmbeddings
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser
from langchain_core.runnables import RunnablePassthrough

from langgraph.graph import StateGraph, END

# For the web agent
import asyncio
import nest_asyncio
from crawl4ai import AsyncWebCrawler
from googlesearch import search
from langchain.docstore.document import Document

# --- Configuration & Setup ---

load_dotenv()
nest_asyncio.apply()

st.set_page_config(page_title="Chipster Agent", layout="wide")
st.title("🤖 Chipster Agent: A Self-Correcting Verilog Designer")
st.markdown("Powered by LangGraph and Gemini 2.5 Pro")

try:
    GOOGLE_API_KEY = os.environ["GOOGLE_API_KEY"]
except KeyError:
    st.error("🚨 GOOGLE_API_KEY not found! Please create a .env file with your key.")
    st.stop()

# --- Part 1: FAISS Index & Model Loading ---

DATASET_PATH = "../../../data/verilog_datasets"
INDEX_PATH_DATASET = os.path.join(DATASET_PATH, "faiss_verilog_db")
GENERATED_CODE_PATH = "../../../examples/verilog_designs"
MAX_RETRIES = 10 # Maximum number of correction attempts

@st.cache_resource
def get_embedding_model():
    """Loads the local HuggingFace embedding model, cached for performance."""
    st.write("Loading Local Embedding Model (all-MiniLM-L6-v2)...")
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    st.write(f"Using device: {device}")
    return HuggingFaceEmbeddings(model_name='all-MiniLM-L6-v2', model_kwargs={'device': device})

@st.cache_resource
def load_dataset_vectorstore():
    """Loads the dataset FAISS index if it exists."""
    if os.path.exists(INDEX_PATH_DATASET):
        st.write(f"Loading existing dataset FAISS index from '{INDEX_PATH_DATASET}'...")
        return FAISS.load_local(INDEX_PATH_DATASET, get_embedding_model(), allow_dangerous_deserialization=True)
    else:
        st.warning(f"Local dataset index not found at '{INDEX_PATH_DATASET}'. The Dataset Agent will be disabled.")
        return None

db_verilog_dataset = load_dataset_vectorstore()


# --- Part 2: LangGraph Multi-Agent Setup ---

class GraphState(TypedDict):
    query: str
    log: List[str]
    documents: List[Document]
    generation: str
    decomposed_files: Dict[str, str]
    testbench_code: Dict[str, str]
    output_path: str
    simulation_output: str
    error_count: int
    top_module_name: str


def get_graph_viz(active_node: str = None):
    """Generates a Graphviz object to visualize the agent workflow."""
    dot = graphviz.Digraph(comment='Chipster Agent Workflow')
    dot.attr('node', shape='box', style='rounded,filled', fillcolor='lightgrey')
    dot.attr(rankdir='TB', splines='ortho')

    nodes = {
        "dataset_retriever": "1. Dataset Retriever",
        "web_retriever": "2. Web Researcher",
        "code_generator": "3. Verilog Generator",
        "decomposer": "4. Decomposer",
        "testbench_generator": "5. Testbench Writer",
        "file_writer": "6. File Writer",
        "simulator": "7. Icarus Simulator",
        "check_simulation": "8. Check Results",
        "module_corrector": "9a. Module Corrector",
        "testbench_corrector": "9b. Testbench Corrector"
    }
    for name, label in nodes.items():
        fillcolor = 'lightblue' if name == active_node else 'lightgrey'
        fontcolor = "black"
        if "Corrector" in label:
            fillcolor = 'lightcoral' if name == active_node else '#FFD2D2' # Reddish for correctors
        elif "Check" in label:
             fillcolor = 'orange' if name == active_node else 'moccasin' # Orange for router
        dot.node(name, label, fillcolor=fillcolor, fontcolor=fontcolor)

    # Main flow
    dot.edge("dataset_retriever", "web_retriever")
    dot.edge("web_retriever", "code_generator")
    dot.edge("code_generator", "decomposer")
    dot.edge("decomposer", "testbench_generator")
    dot.edge("testbench_generator", "file_writer")
    dot.edge("file_writer", "simulator")
    dot.edge("simulator", "check_simulation")

    # Add an END node for clarity
    dot.node("END", "🏁 END", shape="ellipse", style="filled", fillcolor="palegreen")

    # Conditional Edges from Router
    dot.edge("check_simulation", "END", label="Success", color="green", style="bold")
    dot.edge("check_simulation", "testbench_corrector", label="Fix Testbench", color="orange", style="dashed")
    dot.edge("check_simulation", "module_corrector", label="Fix Design", color="red", style="dashed")

    # Correction loop paths
    dot.edge("testbench_corrector", "file_writer", style="dashed")
    dot.edge("module_corrector", "file_writer", style="dashed") # CORRECTED FLOW

    return dot

# --- Helper Functions ---
def log_code_changes(log: List[str], filename: str, old_code: str, new_code: str) -> List[str]:
    """Generates a diff and adds it to the log."""
    diff = difflib.unified_diff(
        old_code.splitlines(keepends=True),
        new_code.splitlines(keepends=True),
        fromfile=f"a/{filename}",
        tofile=f"b/{filename}",
    )
    diff_str = "".join(diff)
    if diff_str:
        log.append(f"🔍 Code changes for `{filename}`:\n```diff\n{diff_str}```")
    else:
        log.append(f"🔍 No functional changes detected for `{filename}`.")
    return log

# --- Agent Nodes ---

def dataset_retriever_node(state):
    query = state["query"]
    log = state.get("log", []) + ["\n--- AGENT: Dataset Retriever ---"]
    if db_verilog_dataset is None:
        log.append("Skipping: No local index.")
        return {"documents": [], "log": log}
    retriever = db_verilog_dataset.as_retriever(search_kwargs={"k": 5})
    docs = retriever.invoke(query)
    log.append(f"Found {len(docs)} docs in local DB.")
    return {"documents": docs, "log": log}

def web_retriever_node(state):
    return asyncio.run(web_retriever_node_async(state))

async def web_retriever_node_async(state):
    query = state["query"]
    existing_docs = state.get("documents", [])
    log = state.get("log", []) + ["\n--- AGENT: Web Researcher ---"]
    embeddings = get_embedding_model()
    sanitized_prompt = re.sub(r'\W+', '_', query).lower()
    index_name = f"faiss_github_{sanitized_prompt}"
    INDEX_PATH_WEB = os.path.join(DATASET_PATH, index_name)
    log.append(f"Checking for cached web index: '{INDEX_PATH_WEB}'")
    web_vectorstore = None
    if os.path.exists(INDEX_PATH_WEB):
        log.append("✅ Cached index found! Loading.")
        web_vectorstore = FAISS.load_local(INDEX_PATH_WEB, embeddings, allow_dangerous_deserialization=True)
    else:
        log.append("❌ No cache. Crawling web...")
        urls = list(search(f"{query} verilog github", num_results=5, lang="en"))
        
        if not urls:
             log.append("⚠️ No relevant URLs found on Google search.")
             return {"documents": existing_docs, "log": log}

        new_web_docs = []
        async with AsyncWebCrawler() as crawler:
            for url in urls:
                try:
                    result = await crawler.arun(url=url)
                    if result and result.markdown:
                        new_web_docs.append(Document(page_content=result.markdown, metadata={"source": url}))
                except Exception as e:
                    log.append(f"⚠️ Failed to crawl {url}: {e}")

        if new_web_docs:
            split_docs = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=150).split_documents(new_web_docs)
            web_vectorstore = FAISS.from_documents(split_docs, embeddings)
            web_vectorstore.save_local(INDEX_PATH_WEB)
            log.append(f"✅ New web index saved.")
            
    docs_from_web = []
    if web_vectorstore:
        retriever = web_vectorstore.as_retriever(search_kwargs={"k": 5})
        docs_from_web = retriever.invoke(query)
        log.append(f"Found {len(docs_from_web)} docs from web.")
        
    return {"documents": existing_docs + docs_from_web, "log": log}

def code_generator_node(state):
    query = state["query"]
    documents = state["documents"]
    log = state.get("log", []) + ["\n--- AGENT: Verilog Generator ---"]
    log.append("✍️ Generating monolithic code from scratch...")
    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.2, google_api_key=GOOGLE_API_KEY)
    
    prompt_template = """You are an expert Verilog HDL designer.
Based on the context from reference documents and the user's request, generate the complete, monolithic Verilog code for the requested module.
Your output **MUST** be only the Verilog code, enclosed in a single markdown block.
Do not include any other explanations.

**CONTEXT:**
{context}

**REQUEST:**
{question}

**GENERATED VERILOG CODE:**
```verilog
"""
    prompt = ChatPromptTemplate.from_template(prompt_template)
    
    def format_docs(docs):
        if not docs: return "No context documents found."
        return "\n\n".join(f"Source: {doc.metadata.get('source', 'N/A')}\n\n{doc.page_content}" for doc in docs)
        
    rag_chain = ({"context": lambda x: format_docs(x["documents"]), "question": RunnablePassthrough()}| prompt | llm | StrOutputParser())
    generation = rag_chain.invoke({"documents": documents, "question": query}).replace("```", "").strip()
    log.append("✅ Monolithic code generated.")
    
    return {"generation": generation, "log": log, "simulation_output": ""} # Reset simulation output

def module_corrector_node(state):
    log = state.get("log", []) + ["\n--- AGENT: Verilog Module Corrector ---"]
    log.append("♻️ Attempting to fix previous design error...")
    
    decomposed_files = state["decomposed_files"]
    error_log = state["simulation_output"]
    
    # Identify the likely faulty file from the error log
    faulty_filename = None
    for fname in decomposed_files.keys():
        if fname in error_log:
            faulty_filename = fname
            break
    
    # If no specific file is mentioned, we can't proceed with this targeted correction
    if not faulty_filename:
        log.append("⚠️ Could not identify a specific faulty module from the error log. No correction applied.")
        return {"decomposed_files": decomposed_files, "log": log}

    faulty_code = decomposed_files[faulty_filename]
    log.append(f"Identified faulty file: {faulty_filename}")

    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.2, google_api_key=GOOGLE_API_KEY)
    
    prompt_template = """You are an expert Verilog debugger.
**TASK:** You are given a single Verilog module that failed during simulation. Analyze the error message and the code, identify the bug, and provide a corrected version of **only that module's code**.
Your output **MUST** be only the corrected Verilog code for the module, enclosed in a single markdown block.

**FAULTY VERILOG MODULE (`{faulty_filename}`):**
```verilog
{faulty_code}
```

**SIMULATION ERROR LOG:**
```
{error_log}
```

**YOUR RESPONSE (Corrected, Complete Verilog Code for the Module Only):**
```verilog
"""
    prompt = ChatPromptTemplate.from_template(prompt_template)
    chain = prompt | llm | StrOutputParser()
    
    corrected_module_code = chain.invoke({
        "faulty_filename": faulty_filename,
        "faulty_code": faulty_code,
        "error_log": error_log
    }).replace("```", "").strip().replace("verilog", "", 1)

    # Update the specific file in the state
    updated_files = decomposed_files.copy()
    updated_files[faulty_filename] = corrected_module_code
    log.append(f"✅ Design correction generated for {faulty_filename}.")
    
    # Log the changes
    log = log_code_changes(log, faulty_filename, faulty_code, corrected_module_code)

    return {"decomposed_files": updated_files, "log": log}


def decomposer_node(state):
    generation = state["generation"]
    log = state.get("log", []) + ["\n--- AGENT: Verilog Decomposer ---"]
    log.append("Decomposing code...")
    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.0, google_api_key=GOOGLE_API_KEY)
    
    decomposer_prompt_template = """You are a highly intelligent Verilog code refactoring tool.
Your task is to analyze the provided monolithic Verilog code and decompose it into separate files for each module.
You must return a single, valid JSON object containing two keys: "top_module_name" and "files".

**RULES:**
1.  The `top_module_name` key must hold a string with the name of the top-level module.
2.  The `files` key must hold an object where each key is a filename (e.g., `module_name.v`) and the corresponding value is the complete Verilog code for that module.
3.  Your final output **MUST** be a single, valid JSON object. Do not add any text, explanations, or markdown formatting like ```json before or after the JSON object.

**USER REQUEST:** {query}
**MONOLITHIC VERILOG CODE TO DECOMPOSE:**
```verilog
{verilog_code}
```

**RESPONSE (Valid JSON object only):**
"""
    decomposer_prompt = ChatPromptTemplate.from_template(decomposer_prompt_template)
    
    chain = decomposer_prompt | llm | StrOutputParser()
    response = chain.invoke({"verilog_code": generation, "query": state["query"]})
    
    try:
        # Clean the response to find the JSON blob
        json_match = re.search(r'\{.*\}', response, re.DOTALL)
        if not json_match:
            raise json.JSONDecodeError("No JSON object found in the LLM response.", response, 0)
        
        json_str = json_match.group(0)
        parsed_json = json.loads(json_str)
        
        decomposed_files = parsed_json.get("files", {})
        top_module_name = parsed_json.get("top_module_name", "")

        if not decomposed_files or not top_module_name:
             raise ValueError("Parsed JSON is missing 'files' or 'top_module_name' keys.")

        log.append(f"✅ Decomposed into {len(decomposed_files)} files. Top module: {top_module_name}")

    except (json.JSONDecodeError, ValueError) as e:
        log.append(f"❌ Failed to parse valid JSON from decomposer. Error: {e}. Falling back to monolithic code.")
        log.append(f"   Raw LLM Response: {response}") # Add this for debugging
        top_module_match = re.search(r'module\s+(\w+)', generation)
        top_module_name = top_module_match.group(1) if top_module_match else "unknown_module"
        decomposed_files = {f"{top_module_name}.v": generation}
        
    return {"decomposed_files": decomposed_files, "top_module_name": top_module_name, "log": log}

def testbench_generator_node(state):
    log = state.get("log", []) + ["\n--- AGENT: Testbench Writer ---"]
    decomposed_files = state["decomposed_files"]
    top_module_name = state["top_module_name"]

    # Defensive check to prevent IndexError if decomposer fails
    if not decomposed_files:
        log.append("❌ Cannot generate testbench: No decomposed module files were provided.")
        return {"testbench_code": {}, "log": log}

    log.append("✍️ Generating new testbench...")
    top_module_code = decomposed_files.get(f"{top_module_name}.v", list(decomposed_files.values())[0])

    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.2, google_api_key=GOOGLE_API_KEY)
    
    prompt_template = """You are an expert in Verilog testbench design.
**TASK:** Write a comprehensive testbench for the provided top-level module.
- The testbench should instantiate the DUT, provide realistic stimuli, and use `$display` or `$monitor` to show results.
- It must include a clock signal if needed and terminate automatically using `$finish`.
- Your final output **MUST** be a single, valid JSON object with one key-value pair: the key is the testbench filename (e.g., "{top_module_name}_tb.v") and the value is the complete testbench code.

**TOP-LEVEL MODULE CODE:**
```verilog
{top_module_code}
```
**RESPONSE (Valid JSON object only):**
"""
    prompt = ChatPromptTemplate.from_template(prompt_template)
    
    chain = prompt | llm | StrOutputParser()
    response = chain.invoke({
        "top_module_name": top_module_name,
        "top_module_code": top_module_code,
    })

    try:
        json_str = response[response.find('{'):response.rfind('}')+1]
        testbench_json = json.loads(json_str)
        log.append(f"✅ Testbench generated: {list(testbench_json.keys())[0]}")
    except Exception as e:
        log.append(f"❌ Failed to generate valid testbench JSON. Error: {e}")
        testbench_json = {}
        
    return {"testbench_code": testbench_json, "log": log}

def testbench_corrector_node(state):
    log = state.get("log", []) + ["\n--- AGENT: Testbench Corrector ---"]
    log.append("♻️ Attempting to fix previous testbench error...")

    decomposed_files = state["decomposed_files"]
    top_module_name = state["top_module_name"]
    faulty_tb_code_dict = state["testbench_code"]
    error_log = state["simulation_output"]

    top_module_code = decomposed_files.get(f"{top_module_name}.v", list(decomposed_files.values())[0])
    faulty_tb_filename = list(faulty_tb_code_dict.keys())[0] if faulty_tb_code_dict else f"{top_module_name}_tb.v"
    faulty_tb_code = list(faulty_tb_code_dict.values())[0] if faulty_tb_code_dict else "# Faulty testbench code was not found"

    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.2, google_api_key=GOOGLE_API_KEY)
    
    prompt_template = """You are an expert Verilog testbench debugger.
**TASK:** You are given a testbench that failed during simulation. Analyze the error message, the testbench code, and the module it is testing (DUT). Provide a corrected version of the testbench.
Your final output **MUST** be a single JSON object containing the corrected testbench. The key must be the original testbench filename.

**SIMULATION ERROR LOG:**
```
{error_log}
```

**FAULTY TESTBENCH CODE (`{faulty_tb_filename}`):**
```verilog
{faulty_tb_code}
```

**DEVICE UNDER TEST (DUT) CODE (`{top_module_name}.v`):**
```verilog
{top_module_code}
```

**RESPONSE (Valid JSON object only):**
"""
    prompt = ChatPromptTemplate.from_template(prompt_template)
    chain = prompt | llm | StrOutputParser()
    
    response = chain.invoke({
        "top_module_name": top_module_name,
        "top_module_code": top_module_code,
        "error_log": error_log,
        "faulty_tb_filename": faulty_tb_filename,
        "faulty_tb_code": faulty_tb_code
    })

    try:
        # Use robust JSON extraction
        json_match = re.search(r'\{.*\}', response, re.DOTALL)
        if not json_match:
            raise json.JSONDecodeError("No JSON object found in the LLM response.", response, 0)
        
        json_str = json_match.group(0)
        corrected_testbench_json = json.loads(json_str)

        if not isinstance(corrected_testbench_json, dict) or not corrected_testbench_json:
            raise ValueError("Parsed JSON is not a valid, non-empty dictionary.")
        
        corrected_tb_filename = list(corrected_testbench_json.keys())[0]
        corrected_tb_code = corrected_testbench_json[corrected_tb_filename]

        log.append(f"✅ Testbench correction generated for: {corrected_tb_filename}")
        log = log_code_changes(log, corrected_tb_filename, faulty_tb_code, corrected_tb_code)

    except (json.JSONDecodeError, ValueError) as e:
        log.append(f"❌ Failed to generate valid corrected testbench JSON. Error: {e}")
        log.append(f"   Raw LLM Response: {response}") # Add this for debugging
        corrected_testbench_json = faulty_tb_code_dict # Fallback to the faulty code
        
    return {"testbench_code": corrected_testbench_json, "log": log}


def file_writer_node(state):
    log = state.get("log", []) + ["\n--- AGENT: File Writer ---"]
    query = state["query"]
    decomposed_files = state["decomposed_files"]
    testbench_code = state.get("testbench_code", {})
    sanitized_prompt = re.sub(r'\W+', '_', query).lower()
    output_path = os.path.join(GENERATED_CODE_PATH, f"generated_{sanitized_prompt}")
    os.makedirs(output_path, exist_ok=True)
    log.append(f"Writing files to: '{output_path}'")

    all_files_to_write = {**decomposed_files, **testbench_code}
    for filename, content in all_files_to_write.items():
        if isinstance(content, str):
            with open(os.path.join(output_path, filename), 'w') as f:
                f.write(content)
            log.append(f"  - Wrote {filename}")
        else:
            log.append(f"  - ⚠️ Skipped writing {filename} due to invalid content type.")
            
    return {"output_path": output_path, "log": log}

def simulator_node(state):
    log = state.get("log", []) + ["\n--- AGENT: Icarus Simulator ---"]
    output_path = state["output_path"]
    log.append(f"Preparing to simulate files in '{output_path}'")

    verilog_files = glob.glob(os.path.join(output_path, "*.v"))
    if not verilog_files:
        log.append("❌ No .v files found to simulate.")
        return {"simulation_output": "Error: No Verilog files found.", "log": log}
    
    output_vvp_file = os.path.join(output_path, "design.vvp")
    command = ["iverilog", "-o", output_vvp_file] + verilog_files
    
    simulation_output = ""
    try:
        log.append(f"Running command: `{' '.join(command)}`")
        compile_process = subprocess.run(command, capture_output=True, text=True, timeout=30)
        
        if compile_process.returncode != 0:
            raise subprocess.CalledProcessError(compile_process.returncode, compile_process.args, output=compile_process.stdout, stderr=compile_process.stderr)
            
        log.append("✅ Compilation successful.")
        
        sim_command = ["vvp", output_vvp_file]
        log.append(f"Running command: `{' '.join(sim_command)}`")
        sim_process = subprocess.run(sim_command, capture_output=True, text=True, check=True, timeout=30)
        simulation_output = sim_process.stdout
        log.append("✅ Simulation finished.")
        
    except subprocess.CalledProcessError as e:
        error_message = e.stderr or e.stdout or "Unknown simulation error."
        simulation_output = f"ERROR during {'compilation' if 'iverilog' in ' '.join(e.cmd) else 'simulation'}:\n{error_message}"
        log.append(f"❌ Simulation Failed.")
    except subprocess.TimeoutExpired:
        simulation_output = "ERROR: Simulation timed out. The testbench may have an infinite loop or is not finishing with `$finish`."
        log.append(f"❌ {simulation_output}")

    # Reset simulation output in state if successful
    if "ERROR" not in simulation_output:
        return {"simulation_output": "", "log": log}
    else:
        error_count = state.get("error_count", 0) + 1
        return {"simulation_output": simulation_output, "error_count": error_count, "log": log}


def check_simulation_results_node(state):
    """Router node to decide the next step based on simulation outcome."""
    log = state.get("log", []) + ["\n--- ROUTER: Checking Results ---"]
    simulation_output = state.get("simulation_output", "")
    error_count = state.get("error_count", 0)
    
    if not simulation_output:
        log.append("✅ Success! No errors found in simulation.")
        return "end"

    log.append(f"⚠️ Error detected on attempt {error_count}.")
    if error_count >= MAX_RETRIES:
        log.append(f"❌ Maximum retry limit ({MAX_RETRIES}) reached. Halting workflow.")
        return "end"
    
    tb_files = [f for f in state.get("testbench_code", {}).keys()]
    is_tb_error = any(tb_file in simulation_output for tb_file in tb_files if tb_file) or "timeout" in simulation_output.lower()

    if is_tb_error:
        log.append("Routing to: Testbench Corrector")
        return "fix_testbench"
    else:
        log.append("Routing to: Module Corrector")
        return "fix_design"

# --- Graph Definition ---
def build_graph():
    workflow = StateGraph(GraphState)
    workflow.add_node("dataset_retriever", dataset_retriever_node)
    workflow.add_node("web_retriever", web_retriever_node)
    workflow.add_node("code_generator", code_generator_node)
    workflow.add_node("module_corrector", module_corrector_node)
    workflow.add_node("decomposer", decomposer_node)
    workflow.add_node("testbench_generator", testbench_generator_node)
    workflow.add_node("testbench_corrector", testbench_corrector_node)
    workflow.add_node("file_writer", file_writer_node)
    workflow.add_node("simulator", simulator_node)

    workflow.set_entry_point("dataset_retriever")
    workflow.add_edge("dataset_retriever", "web_retriever")
    workflow.add_edge("web_retriever", "code_generator")
    workflow.add_edge("code_generator", "decomposer")
    workflow.add_edge("decomposer", "testbench_generator")
    workflow.add_edge("testbench_generator", "file_writer")
    workflow.add_edge("file_writer", "simulator")

    # Add correction loop edges
    workflow.add_edge("module_corrector", "file_writer") # Corrected edge
    workflow.add_edge("testbench_corrector", "file_writer")
    
    # Add the conditional router
    workflow.add_conditional_edges(
        "simulator",
        check_simulation_results_node,
        {
            "fix_testbench": "testbench_corrector",
            "fix_design": "module_corrector",
            "end": END
        }
    )
    
    return workflow.compile()

app = build_graph()


# --- Part 3: Streamlit UI ---
st.sidebar.header("Controls")
user_query = st.sidebar.text_area("Describe the Verilog module you want to build:", height=150, value="risc v 32 bit")

if st.sidebar.button("✨ Generate & Verify Code", use_container_width=True):
    if not user_query:
        st.sidebar.error("Please enter a description for the Verilog module.")
    else:
        st.subheader("🚀 Agent Workflow Visualization")
        graph_placeholder = st.empty()
        
        col1, col2 = st.columns([1, 2])
        log_placeholder = col1.expander("Agent Activity Log", expanded=True)
        log_container = log_placeholder.container()
        results_placeholder = col2.expander("Final Results & Files", expanded=True)

        graph_placeholder.graphviz_chart(get_graph_viz())
        inputs = {"query": user_query, "error_count": 0}
        
        with st.spinner("Chipster Agent is thinking..."):
            final_result = None
            log_messages = []
            
            for s in app.stream(inputs, stream_mode="values"):
                active_node = list(s.keys())[-1]
                graph_placeholder.graphviz_chart(get_graph_viz(active_node))
                final_result = s
                if "log" in final_result:
                    new_logs = final_result["log"][len(log_messages):]
                    for msg in new_logs:
                        log_container.markdown(f"{msg.strip()}", unsafe_allow_html=True)
                        log_messages.append(msg)
            
            graph_placeholder.graphviz_chart(get_graph_viz("END"))
            
            results_placeholder.subheader("🏁 Final Outcome")
            if final_result.get("error_count", 0) >= MAX_RETRIES:
                results_placeholder.error(f"Workflow halted with an error after {final_result.get('error_count', 0)} retries.")
                with results_placeholder.expander("🚨 View Final Simulation Error", expanded=True):
                    st.code(final_result.get("simulation_output"), language='bash')
            else:
                st.balloons()
                results_placeholder.success(f"✅ All Verilog files generated, verified, and saved to: `{final_result.get('output_path', 'N/A')}`")
            
            results_placeholder.write("---")
            results_placeholder.subheader("Generated Files & Content")
            if final_result.get("decomposed_files"):
                for filename, content in final_result.get("decomposed_files", {}).items():
                    with results_placeholder.expander(f"📄 **{filename}**"):
                        st.code(content, language='verilog')
            if final_result.get("testbench_code"):
                for filename, content in final_result.get("testbench_code", {}).items():
                    with results_placeholder.expander(f"🧪 **{filename}**"):
                        st.code(content, language='verilog')
else:
    st.info("Enter your Verilog design requirements in the sidebar and click 'Generate & Verify'.")
