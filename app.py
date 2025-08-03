import streamlit as st
from src.verilog_generator import main as verilog_gen
from src.std_cell_generator import main as std_cell_gen

# --- Page Configuration ---
st.set_page_config(
    page_title="Chipster - AI for Chip Design",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# --- Custom CSS for modern UI elements ---
st.markdown("""
<style>
    /* Main container styling */
    .main .block-container {
        padding-top: 2rem;
        padding-bottom: 2rem;
    }
    /* Hide the default Streamlit header */
    header {visibility: hidden;}
    /* Custom Title */
    .title {
        font-size: 3.5rem; /* Increased font size */
        font-weight: bold;
        text-align: center;
        margin-bottom: 0.5rem;
    }
    .subtitle {
        text-align: center;
        color: #a0a0a0;
        margin-bottom: 2rem;
    }
</style>
""", unsafe_allow_html=True)

# --- Session State for Navigation ---
if 'page' not in st.session_state:
    st.session_state.page = 'Home'

# --- Page Navigation Functions ---
def go_to_verilog():
    st.session_state.page = 'Verilog'

def go_to_std_cell():
    st.session_state.page = 'StdCell'

def go_home():
    st.session_state.page = 'Home'


# --- Page Routing ---
if st.session_state.page == 'Home':
    st.markdown('<p class="title">Chipster 🤖</p>', unsafe_allow_html=True)
    st.markdown('<p class="subtitle">An AI-powered assistant for the digital design workflow.</p>', unsafe_allow_html=True)
    st.markdown("---")

    st.header("Select a Tool")
    
    col1, col2 = st.columns(2)
    with col1:
        if st.button("📝 Verilog Generator", use_container_width=True):
            go_to_verilog()
            st.rerun()
        st.write("Convert natural language prompts into synthesizable Verilog and run a complete RTL-to-GDSII flow.")

    with col2:
        if st.button("🛠️ Standard Cell Generator", use_container_width=True):
            go_to_std_cell()
            st.rerun()
        st.write("Generate physical layouts (.mag files) for standard cells from simple, high-level descriptions.")

elif st.session_state.page == 'Verilog':
    if st.button("⬅️ Back to Home"):
        go_home()
        st.rerun()
    verilog_gen.run()

elif st.session_state.page == 'StdCell':
    if st.button("⬅️ Back to Home"):
        go_home()
        st.rerun()
    std_cell_gen.run()
