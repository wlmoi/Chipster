`timescale 1ns/1ps
`include "fixed_point_params.vh"

module swap_gate_tb;
    // --- Testbench signals ---
    reg  signed [`TOTAL_WIDTH-1:0] in_001_r, in_001_i, in_100_r, in_100_i;
    reg  signed [`TOTAL_WIDTH-1:0] in_011_r, in_011_i, in_110_r, in_110_i;
    wire signed [`TOTAL_WIDTH-1:0] out_001_r, out_001_i, out_100_r, out_100_i;
    wire signed [`TOTAL_WIDTH-1:0] out_011_r, out_011_i, out_110_r, out_110_i;

    // --- Instantiate the DUT ---
    swap_gate uut (
        .in_001_r(in_001_r), .in_001_i(in_001_i),
        .in_100_r(in_100_r), .in_100_i(in_100_i),
        .in_011_r(in_011_r), .in_011_i(in_011_i),
        .in_110_r(in_110_r), .in_110_i(in_110_i),
        .out_001_r(out_001_r), .out_001_i(out_001_i),
        .out_100_r(out_100_r), .out_100_i(out_100_i),
        .out_011_r(out_011_r), .out_011_i(out_011_i),
        .out_110_r(out_110_r), .out_110_i(out_110_i)
    );

    // --- Test Sequence ---
    initial begin
        $display("--- SWAP Gate Testbench ---");

        // --- Inputs ---
        // Assign distinct values to test the swap.
        in_001_r =  8; in_001_i =  0; // Input |001> = ( 8,  0i) which is 0.5
        in_100_r = -8; in_100_i =  0; // Input |100> = (-8,  0i) which is -0.5
        in_011_r =  0; in_011_i =  8; // Input |011> = ( 0,  8i) which is 0.5i
        in_110_r =  0; in_110_i = -8; // Input |110> = ( 0, -8i) which is -0.5i
        
        #10; // Wait for combinational logic to settle

        // --- Expected Outputs ---
        // The outputs should be the swapped version of the inputs.
        // Expected |001> = Input |100> = (-8, 0i)
        // Expected |100> = Input |001> = ( 8, 0i)
        // Expected |011> = Input |110> = ( 0,-8i)
        // Expected |110> = Input |011> = ( 0, 8i)
        
        // --- Verification ---
        if (out_001_r == -8 && out_001_i == 0  &&
            out_100_r ==  8 && out_100_i == 0  &&
            out_011_r ==  0 && out_011_i == -8 &&
            out_110_r ==  0 && out_110_i == 8)
             $display("Result: PASSED ✅");
        else
             $display("Result: FAILED ❌");

        #10 $finish;
    end
endmodule