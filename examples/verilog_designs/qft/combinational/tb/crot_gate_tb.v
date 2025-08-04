`timescale 1ns/1ps
`include "fixed_point_params.vh"

module crot_gate_tb;

    // --- Testbench signals ---
    reg  signed [`TOTAL_WIDTH-1:0] in_r, in_i;
    reg  signed [`TOTAL_WIDTH-1:0] theta;
    wire signed [`TOTAL_WIDTH-1:0] out_r, out_i;

    // --- Instantiate the DUT ---
    crot_gate uut (
        .in_r(in_r), .in_i(in_i),
        .theta(theta),
        .out_r(out_r), .out_i(out_i)
    );

    // --- Constants for the test case ---
    localparam S34_ONE = 16; // Represents 1.0
    localparam PI_OVER_2 = 25; // Represents PI/2 (~1.57 rad)

    // --- Test Sequence ---
    initial begin
        $display("--- CROT Gate Testbench ---");

        // Test Case: Rotate the state |1> by an angle of PI/2
        // Input amplitude is (1.0 + 0i) -> S3.4: (16, 0)
        in_r  = S34_ONE;
        in_i  = 0;

        // Angle theta = PI/2 -> S3.4: 25
        theta = PI_OVER_2;

        #10; // Wait for the combinational logic to settle

        // --- Verification ---
        // For theta=25, we expect:
        // cos_approx(25) -> should be close to 0
        // sin_approx(25) -> should be close to 1.0 (which is 16 in S3.4)
        // We are multiplying (16, 0) by (approx 0, approx 16)
        // Expected result: (0, 16i)
        
        $display("Test: Rotating (1.0 + 0i) by theta = PI/2");
        $display("Input Amp: (%d, %di), Theta: %d", in_r, in_i, theta);
        $display("Output Amp: (%d, %di)", out_r, out_i);
        $display("Expected Amp: (0, 16i)");

        // Check if the result is correct, allowing for small fixed-point errors
        if (out_r > -2 && out_r < 2 && out_i > (S34_ONE - 2))
            $display("\nResult: PASSED ✅");
        else
            $display("\nResult: FAILED ❌");

        #10 $finish;
    end
endmodule