//////////////////////////////////////////////////////////////////////////////////
//
// Company: 
// Engineer: 
// 
// Create Date: 2023-10-27
// Design Name: fir_filter
// Module Name: fir_filter_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A comprehensive testbench for a parallel FIR filter.
//
// Dependencies: shared_header.vh
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
//
//////////////////////////////////////////////////////////////////////////////////

`include "shared_header.vh"

module fir_filter_tb;

    //================================================================
    // Testbench Parameters
    //================================================================
    // These parameters are assumed to be defined in "shared_header.vh"
    // They are defined here as localparams for testbench completeness.
    localparam IWIDTH      = 16;
    localparam OWIDTH      = 16;
    localparam COEFWIDTH   = 16;
    localparam NTAPS       = 11;

    // Clock period (e.g., 10 ns for a 100 MHz clock)
    localparam CLK_PERIOD = 10;

    // DUT latency, derived from the DUT's pipeline stages (1+1+4 = 6)
    localparam PIPELINE_STAGES = 6;

    //================================================================
    // Testbench Signals
    //================================================================
    // Inputs to DUT
    reg                         clk;
    reg                         arst;
    reg                         input_valid;
    reg signed [IWIDTH-1:0]     din;

    // Outputs from DUT
    wire                        output_valid;
    wire signed [OWIDTH-1:0]    dout;

    //================================================================
    // Instantiate the Design Under Test (DUT)
    //================================================================
    fir_filter dut (
        .clk(clk),
        .arst(arst),
        .input_valid(input_valid),
        .din(din),
        .output_valid(output_valid),
        .dout(dout)
    );

    //================================================================
    // Clock Generator
    //================================================================
    initial begin
        clk = 0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    //================================================================
    // Stimulus and Test Sequence
    //================================================================
    initial begin
        // CRITICAL: These two lines are required for waveform generation.
        $dumpfile("design.vcd");
        $dumpvars(0, fir_filter_tb);

        // ---[ 1. Reset Phase ]---
        $display("T=%0t: [TB] Simulation started. Applying reset.", $time);
        arst = 1;
        input_valid = 0;
        din = 0;
        repeat (2) @(posedge clk);
        arst = 0;
        $display("T=%0t: [TB] Reset released.", $time);
        @(posedge clk);

        // ---[ 2. Impulse Response Test ]---
        // An impulse input should produce the filter's coefficients at the output,
        // scaled by the impulse magnitude and delayed by the pipeline latency.
        $display("\nT=%0t: [TB] Starting Impulse Response Test.", $time);
        // Send a single non-zero sample (the impulse)
        input_valid <= 1;
        din <= 100; // Use a value > 1 to see scaling effects
        @(posedge clk);
        // Follow the impulse with zeros to flush the filter
        din <= 0;
        // Keep input_valid high for NTAPS cycles to see the full response
        repeat (NTAPS + 5) @(posedge clk);
        input_valid <= 0;
        $display("T=%0t: [TB] Impulse stimulus finished.", $time);

        // Wait for the last of the impulse response to exit the pipeline
        repeat (PIPELINE_STAGES + 2) @(posedge clk);

        // ---[ 3. Step Response Test ]---
        // A constant (DC) input should cause the output to settle to a constant value.
        $display("\nT=%0t: [TB] Starting Step Response Test.", $time);
        input_valid <= 1;
        din <= 25; // A constant DC value
        // Send the constant value for long enough to fill the filter's shift register
        // and observe a steady-state output.
        repeat (NTAPS + PIPELINE_STAGES + 5) @(posedge clk);
        input_valid <= 0;
        $display("T=%0t: [TB] Step stimulus finished.", $time);

        // Wait for the last of the step response to exit the pipeline
        repeat (PIPELINE_STAGES + 2) @(posedge clk);

        // ---[ 4. Alternating Input Test ]---
        // This is a simple high-frequency signal. Since the DUT is a low-pass filter,
        // the output magnitude should be significantly attenuated.
        $display("\nT=%0t: [TB] Starting Alternating Input Test.", $time);
        input_valid <= 1;
        repeat (20) begin
            din <= 200;
            @(posedge clk);
            din <= -200;
            @(posedge clk);
        end
        input_valid <= 0;
        $display("T=%0t: [TB] Alternating stimulus finished.", $time);

        // Wait for final outputs to flush through the pipeline
        repeat (PIPELINE_STAGES + 5) @(posedge clk);

        // ---[ 5. End Simulation ]---
        $display("\nT=%0t: [TB] All tests complete. Finishing simulation.", $time);
        $finish;
    end

    //================================================================
    // Results Monitoring
    //================================================================
    // This block displays the input and output values on each clock cycle
    // when the respective valid signals are asserted.
    always @(posedge clk)
    begin
        if (input_valid)
        begin
            $display("T=%0t: [IN]  din = %6d", $time, din);
        end
        if (output_valid)
        begin
            $display("T=%0t: [OUT] dout = %6d", $time, dout);
        end
    end

endmodule
