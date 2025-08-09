/**
 * Verilog Testbench for qft3_top
 * 
 * Author: AI Testbench Expert
 * Date:   2023-10-27
 * 
 * Description:
 * This testbench verifies the functionality of the 3-qubit Quantum Fourier Transform
 * (QFT) top-level module (`qft3_top`). It performs the following steps:
 * 1.  Includes the shared header file for parameter definitions.
 * 2.  Generates a clock and handles the active-low reset sequence.
 * 3.  Instantiates the Device Under Test (DUT).
 * 4.  Provides two test cases to verify the QFT logic:
 *     - Test Case 1: Input state |000>. The expected output is an equal
 *       superposition of all basis states.
 *     - Test Case 2: Input state |101>. The expected output is a complex
 *       superposition state with varying phases.
 * 5.  The test cases are sent back-to-back to test the pipeline's ability to
 *     handle continuous data.
 * 6.  Monitors the `valid_out` signal and displays the 8 complex output amplitudes
 *     when the result is ready.
 * 7.  Generates a VCD waveform file (`design.vcd`) for debugging.
 * 8.  Terminates the simulation automatically using `$finish`.
 */

`include "shared_header.vh"

`timescale 1ns / 1ps

module qft3_top_tb;

    //------------------------------------------------------------------------
    // Testbench Parameters
    //------------------------------------------------------------------------
    localparam CLK_PERIOD = 10; // Clock period in ns

    // Fixed-point format for state vectors. Assumed Q4.12 based on common practice.
    // This must match the format used in the DUT's submodules.
    // `TOTAL_WIDTH` is defined in shared_header.vh, but we define it here
    // for clarity in case the header is not available.
    localparam TB_TOTAL_WIDTH = `TOTAL_WIDTH; 
    localparam FRAC_WIDTH   = 12;

    // Fixed-point representations of common values for test vectors
    localparam signed [TB_TOTAL_WIDTH-1:0] FP_ZERO = 0;
    localparam signed [TB_TOTAL_WIDTH-1:0] FP_ONE  = 1'b1 << FRAC_WIDTH; // 1.0 * 2^12 = 4096
    
    // Latency of the DUT pipeline (from valid_in to valid_out)
    localparam PIPELINE_LATENCY = 35;

    //------------------------------------------------------------------------
    // Testbench Signals
    //------------------------------------------------------------------------
    // DUT Inputs
    reg                                   clk;
    reg                                   rst_n;
    reg                                   valid_in;
    reg signed [TB_TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i;
    reg signed [TB_TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i;

    // DUT Outputs
    wire signed [TB_TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i, f010_r, f010_i, f011_r, f011_i;
    wire signed [TB_TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i, f110_r, f110_i, f111_r, f111_i;
    wire                               valid_out;

    integer test_case_count = 0;

    //------------------------------------------------------------------------
    // DUT Instantiation
    //------------------------------------------------------------------------
    qft3_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        
        .i000_r(i000_r), .i000_i(i000_i), .i001_r(i001_r), .i001_i(i001_i),
        .i010_r(i010_r), .i010_i(i010_i), .i011_r(i011_r), .i011_i(i011_i),
        .i100_r(i100_r), .i100_i(i100_i), .i101_r(i101_r), .i101_i(i101_i),
        .i110_r(i110_r), .i110_i(i110_i), .i111_r(i111_r), .i111_i(i111_i),

        .f000_r(f000_r), .f000_i(f000_i), .f001_r(f001_r), .f001_i(f001_i),
        .f010_r(f010_r), .f010_i(f010_i), .f011_r(f011_r), .f011_i(f011_i),
        .f100_r(f100_r), .f100_i(f100_i), .f101_r(f101_r), .f101_i(f101_i),
        .f110_r(f110_r), .f110_i(f110_i), .f111_r(f111_r), .f111_i(f111_i),
        
        .valid_out(valid_out)
    );

    //------------------------------------------------------------------------
    // Clock Generator
    //------------------------------------------------------------------------
    always #((CLK_PERIOD)/2) clk = ~clk;

    //------------------------------------------------------------------------
    // Main Test Sequence
    //------------------------------------------------------------------------
    initial begin
        // CRITICAL: These two lines are required for waveform generation.
        $dumpfile("design.vcd");
        $dumpvars(0, qft3_top_tb);

        $display("\n[INFO] Starting QFT3 Testbench...");
        
        // Initialize signals and apply reset
        initialize_ports();
        apply_reset();

        // --- Test Case 1: Input state |000> --- 
        // Expected output: 1/sqrt(8) * sum(|k>) for k=0 to 7.
        // All real parts should be ~0.3535, all imaginary parts should be 0.
        // 0.3535 * 2^12 = 1448
        $display("\n[%0t] TB: === TEST CASE 1: Input |000> ===", $time);
        apply_input_vector(FP_ONE, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, 
                             FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO);

        // Wait a few cycles before sending the next input to test pipelining
        repeat(5) @(posedge clk);

        // --- Test Case 2: Input state |101> (decimal 5) ---
        // Expected output: 1/sqrt(8) * sum(exp(2*pi*i*5*k/8) * |k>)
        // This will produce complex outputs.
        $display("\n[%0t] TB: === TEST CASE 2: Input |101> ===", $time);
        apply_input_vector(FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, 
                             FP_ZERO, FP_ZERO, FP_ONE, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO, FP_ZERO);

        // Wait for all test cases to propagate through the pipeline and exit
        // Wait for latency of second test case + some margin
        repeat(PIPELINE_LATENCY + 20) @(posedge clk);

        $display("\n[INFO] Testbench finished.");
        $finish;
    end

    //------------------------------------------------------------------------
    // Result Monitoring and Display
    //------------------------------------------------------------------------
    always @(posedge clk)
    begin
        if (valid_out)
        begin
            test_case_count = test_case_count + 1;
            $display("-----------------------------------------------------------------");
            $display("[%0t] TB: Valid output received for Test Case %0d", $time, test_case_count);
            $display("  f|000> = (%6d, %6d) [r, i]", f000_r, f000_i);
            $display("  f|001> = (%6d, %6d) [r, i]", f001_r, f001_i);
            $display("  f|010> = (%6d, %6d) [r, i]", f010_r, f010_i);
            $display("  f|011> = (%6d, %6d) [r, i]", f011_r, f011_i);
            $display("  f|100> = (%6d, %6d) [r, i]", f100_r, f100_i);
            $display("  f|101> = (%6d, %6d) [r, i]", f101_r, f101_i);
            $display("  f|110> = (%6d, %6d) [r, i]", f110_r, f110_i);
            $display("  f|111> = (%6d, %6d) [r, i]", f111_r, f111_i);
            $display("-----------------------------------------------------------------");
        end
    end

    //------------------------------------------------------------------------
    // Tasks for Stimulus Application
    //------------------------------------------------------------------------

    // Task to initialize all input ports to a known state
    task initialize_ports;
    begin
        clk <= 1'b0;
        rst_n <= 1'b0;
        valid_in <= 1'b0;
        {i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i,
         i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i} = 0;
    end
    endtask

    // Task to apply and release the active-low reset
    task apply_reset;
    begin
        $display("[%0t] TB: Applying reset...", $time);
        rst_n <= 1'b0;
        repeat(3) @(posedge clk);
        rst_n <= 1'b1;
        $display("[%0t] TB: Reset released.", $time);
        @(posedge clk);
    end
    endtask

    // Task to apply a full 8-element complex input vector
    task apply_input_vector;
        input signed [TB_TOTAL_WIDTH-1:0] v0_r, v0_i, v1_r, v1_i, v2_r, v2_i, v3_r, v3_i;
        input signed [TB_TOTAL_WIDTH-1:0] v4_r, v4_i, v5_r, v5_i, v6_r, v6_i, v7_r, v7_i;
    begin
        @(posedge clk);
        // Assign inputs
        i000_r <= v0_r; i000_i <= v0_i;
        i001_r <= v1_r; i001_i <= v1_i;
        i010_r <= v2_r; i010_i <= v2_i;
        i011_r <= v3_r; i011_i <= v3_i;
        i100_r <= v4_r; i100_i <= v4_i;
        i101_r <= v5_r; i101_i <= v5_i;
        i110_r <= v6_r; i110_i <= v6_i;
        i111_r <= v7_r; i111_i <= v7_i;
        
        // Assert valid_in for one cycle
        valid_in <= 1'b1;
        
        @(posedge clk);
        valid_in <= 1'b0;
        
        // Clear inputs to avoid holding large values on the bus
        {i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i,
         i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i} = 0;
    end
    endtask

endmodule
