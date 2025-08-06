import streamlit as st
import os
import glob
import pandas as pd
from typing import List, TypedDict
import torch
import re

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
st.title("🤖 Chipster Agent: Your Verilog Design Assistant")
st.markdown("Powered by LangGraph and Gemini 2.5 Pro")

try:
    GOOGLE_API_KEY = os.environ["GOOGLE_API_KEY"]
except KeyError:
    st.error("🚨 GOOGLE_API_KEY not found! Please create a .env file with your key.")
    st.stop()


# --- Part 1: FAISS Index Paths and Functions ---

DATASET_PATH = "../../../data/verilog_datasets"
# --- UPDATED: Use the specified name for the local dataset index ---
INDEX_PATH_DATASET = os.path.join(DATASET_PATH, "faiss_verilog_db")
# Note: The web index path is now generated dynamically inside the web agent node.

@st.cache_resource
def get_embedding_model():
    """Loads the local HuggingFace embedding model, cached for performance."""
    st.write("Loading Local Embedding Model (all-MiniLM-L6-v2)...")
    device = 'cuda' if torch.cuda.is_available() else 'cpu'
    st.write(f"Using device: {device}")
    return HuggingFaceEmbeddings(
        model_name='all-MiniLM-L6-v2',
        model_kwargs={'device': device}
    )

def create_dataset_vectorstore():
    """Creates a FAISS vectorstore from all CSVs in the specified directory."""
    # (This function remains logically the same, just uses the new path)
    all_docs = []
    if not os.path.exists(DATASET_PATH):
        os.makedirs(DATASET_PATH); st.info(f"Created directory: {DATASET_PATH}")
    
    csv_files = glob.glob(os.path.join(DATASET_PATH, "*.csv"))
    if not csv_files:
        st.warning(f"No CSV files found in {DATASET_PATH}. The Dataset Agent will be disabled."); return None

    st.write(f"Found {len(csv_files)} CSV file(s) to index...")
    for file_path in csv_files:
        loader = CSVLoader(file_path=file_path); all_docs.extend(loader.load())

    text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=150)
    split_docs = text_splitter.split_documents(all_docs)
    embeddings = get_embedding_model()
    vectorstore = FAISS.from_documents(split_docs, embeddings)
    vectorstore.save_local(INDEX_PATH_DATASET)
    st.success(f"FAISS index for dataset saved to '{INDEX_PATH_DATASET}'")
    return vectorstore

@st.cache_resource
def load_dataset_vectorstore():
    """Loads the dataset FAISS index if it exists, otherwise creates it."""
    if os.path.exists(INDEX_PATH_DATASET):
        st.write(f"Loading existing dataset FAISS index from '{INDEX_PATH_DATASET}'...")
        embeddings = get_embedding_model()
        return FAISS.load_local(INDEX_PATH_DATASET, embeddings, allow_dangerous_deserialization=True)
    else:
        return create_dataset_vectorstore()

db_verilog_dataset = load_dataset_vectorstore()


# --- Part 2: LangGraph Multi-Agent Setup ---

class GraphState(TypedDict):
    query: str
    log: List[str]
    documents: List[Document]
    generation: str

# --- Agent Nodes ---

def dataset_retriever_node(state):
    # This node is unchanged
    query = state["query"]
    log = state.get("log", []) + ["\n--- AGENT: Dataset Retriever ---"]
    if db_verilog_dataset is None:
        log.append("Skipping dataset retrieval: No index loaded.")
        return {"documents": [], "log": log}
    log.append(f"Searching local dataset index for: '{query}'")
    retriever = db_verilog_dataset.as_retriever(search_kwargs={"k": 3})
    docs = retriever.invoke(query)
    log.append(f"Found {len(docs)} relevant document(s) in local dataset.")
    existing_docs = state.get("documents", [])
    return {"documents": existing_docs + docs, "log": log}

async def web_retriever_node_async(state):
    """Agent 2: Retrieves from a persistent, dynamically named web crawl index."""
    query = state["query"]
    log = state.get("log", []) + ["\n--- AGENT: Web Researcher ---"]
    embeddings = get_embedding_model()
    web_vectorstore = None
    
    # --- UPDATED: Dynamic index path generation ---
    sanitized_prompt = re.sub(r'\W+', '_', query).lower()
    index_name = f"faiss_github_{sanitized_prompt}"
    INDEX_PATH_WEB = os.path.join(DATASET_PATH, index_name)
    log.append(f"Using web index path: '{INDEX_PATH_WEB}'")

    if os.path.exists(INDEX_PATH_WEB):
        log.append(f"Loading existing web FAISS index...")
        web_vectorstore = FAISS.load_local(INDEX_PATH_WEB, embeddings, allow_dangerous_deserialization=True)
    else:
        log.append("No existing web FAISS index found for this prompt. Will create a new one.")
        
    log.append(f"Searching web for: '{query} verilog'")
    try:
        urls = list(search(f"{query} verilog github", num_results=3, lang="en"))
        log.append(f"Found {len(urls)} potential URLs.")
    except Exception as e:
        log.append(f"Could not perform web search: {e}"); urls = []
        
    new_web_docs = []
    if urls:
        async with AsyncWebCrawler() as crawler:
            for url in urls:
                log.append(f"Crawling {url}...")
                try:
                    result = await crawler.arun(url=url)
                    if result and result.markdown:
                        new_web_docs.append(Document(page_content=result.markdown, metadata={"source": url}))
                except Exception as e:
                    log.append(f"Failed to crawl {url}: {e}")
                    
    if new_web_docs:
        log.append(f"Adding {len(new_web_docs)} new documents to the web index.")
        text_splitter = RecursiveCharacterTextSplitter(chunk_size=1000, chunk_overlap=150)
        split_docs = text_splitter.split_documents(new_web_docs)
        if web_vectorstore:
            web_vectorstore.add_documents(split_docs)
        else:
            web_vectorstore = FAISS.from_documents(split_docs, embeddings)
        log.append(f"Saving updated web index to disk.")
        web_vectorstore.save_local(INDEX_PATH_WEB)
        
    docs_from_web = []
    if web_vectorstore:
        log.append(f"Searching web index for: '{query}'")
        retriever = web_vectorstore.as_retriever(search_kwargs={"k": 3})
        docs_from_web = retriever.invoke(query)
        log.append(f"Found {len(docs_from_web)} relevant document(s) from web index.")
    else:
        log.append("No web documents to search.")
        
    existing_docs = state.get("documents", [])
    return {"documents": existing_docs + docs_from_web, "log": log}

def web_retriever_node(state):
    return asyncio.run(web_retriever_node_async(state))

def code_generator_node(state):
    query = state["query"]
    documents = state["documents"]
    log = state.get("log", []) + ["\n--- AGENT: Verilog Code Generator ---"]
    log.append("Preparing to generate Verilog code with Gemini 2.5 Pro...")
    llm = ChatGoogleGenerativeAI(model="gemini-2.5-pro", temperature=0.2, google_api_key=GOOGLE_API_KEY)
    prompt_template = """You are an expert Verilog HDL designer. Your task is to write clean, synthesizable, and well-commented Verilog code based on the user's request and the provided context.

    **CONTEXT FROM DATASETS AND WEB RESEARCH:**
    {context}
    
    **USER'S REQUEST:**
    {question}
    
    **INSTRUCTIONS:**
    1.  Carefully analyze the user's request and the context.
    2.  If the context provides a relevant example, use it as a strong reference.
    3.  Generate only the Verilog module code inside a single markdown code block. Do not add explanations before or after the code block.
    4.  Ensure the module has a clear interface (inputs/outputs).
    5.  Add comments to explain complex parts of the code.
    
    **GENERATED VERILOG CODE:**
    """
    prompt = ChatPromptTemplate.from_template(prompt_template)
    def format_docs(docs):
        return "\n\n".join(f"Source: {doc.metadata.get('source', 'N/A')}\n\n{doc.page_content}" for doc in docs)
    rag_chain = (
        {"context": lambda x: format_docs(x["documents"]), "question": RunnablePassthrough()}
        | prompt | llm | StrOutputParser()
    )
    log.append("Invoking RAG chain...")
    generation = rag_chain.invoke({"documents": documents, "question": query})
    log.append("Code generation complete.")
    return {"generation": generation, "log": log}


# Define the Graph
def build_graph():
    workflow = StateGraph(GraphState)
    workflow.add_node("dataset_retriever", dataset_retriever_node)
    workflow.add_node("web_retriever", web_retriever_node)
    workflow.add_node("code_generator", code_generator_node)
    workflow.set_entry_point("dataset_retriever")
    workflow.add_edge("dataset_retriever", "web_retriever")
    workflow.add_edge("web_retriever", "code_generator")
    workflow.add_edge("code_generator", END)
    return workflow.compile()

app = build_graph()


# --- Part 3: Streamlit UI ---
st.sidebar.header("Controls")
user_query = st.sidebar.text_area("Describe the Verilog module you want to build:", height=150)

if st.sidebar.button("✨ Generate Verilog Code"):
    if not user_query:
        st.sidebar.error("Please enter a description for the Verilog module.")
    else:
        with st.spinner("Chipster Agent is thinking..."):
            inputs = {"query": user_query}
            log_placeholder = st.expander("Agent Activity Log", expanded=True)
            log_container = log_placeholder.container()
            final_result = None
            log_messages = []
            
            for s in app.stream(inputs, stream_mode="values"):
                final_result = s
                if "log" in final_result:
                    new_logs = final_result["log"][len(log_messages):]
                    for msg in new_logs:
                        log_container.markdown(f"* {msg}")
                        log_messages.append(msg)
            
            st.subheader("Generated Verilog Code")
            if final_result and final_result.get("generation"):
                st.code(final_result["generation"], language="verilog")
            else:
                st.error("Sorry, the agent could not generate the code.")
else:
    st.info("Enter your Verilog design requirements in the sidebar and click 'Generate'.")