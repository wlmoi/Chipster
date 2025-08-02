import streamlit as st
from src.verilog_generator import main as verilog_gen
from src.std_cell_generator import main as std_cell_gen

st.set_page_config(
    page_title="Chipster - LLM for Chip Design",
    layout="wide"
)

st.sidebar.title("Chipster Tools")
selection = st.sidebar.radio("Go to", ["Home", "Verilog Generator", "Standard Cell Generator"])

if selection == "Home":
    st.title("Welcome to Chipster 🤖")
    st.write("Your AI assistant for chip design. Select a tool from the sidebar to begin.")
    st.info("👈 **Verilog Generator**: Convert natural language prompts into synthesizable Verilog and run it through a complete RTL-to-GDSII flow.")
    st.info("👈 **Standard Cell Generator**: Generate physical layouts (.mag files) for standard cells from simple descriptions.")

elif selection == "Verilog Generator":
    verilog_gen.run() # Assuming the app logic is wrapped in a run() function

elif selection == "Standard Cell Generator":
    std_cell_gen.run() # Assuming the app logic is wrapped in a run() function