`timescale 1ns/1ps
`include "fixed_point_params.vh"

module qft3_top_tb;
    // --- Inputs to the DUT ---
    reg  signed [`TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i;
    reg  signed [`TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i;
    // --- Outputs from the DUT ---
    wire signed [`TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i, f010_r, f010_i, f011_r, f011_i;
    wire signed [`TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i, f110_r, f110_i, f111_r, f111_i;

    // --- Instantiate the DUT (Corrected) ---
    // We explicitly connect each port of the qft3_top module
    // to the corresponding reg or wire in this testbench.
    qft3_top uut (
        .i000_r(i000_r), .i000_i(i000_i), .i001_r(i001_r), .i001_i(i001_i),
        .i010_r(i010_r), .i010_i(i010_i), .i011_r(i011_r), .i011_i(i011_i),
        .i100_r(i100_r), .i100_i(i100_i), .i101_r(i101_r), .i101_i(i101_i),
        .i110_r(i110_r), .i110_i(i110_i), .i111_r(i111_r), .i111_i(i111_i),

        .f000_r(f000_r), .f000_i(f000_i), .f001_r(f001_r), .f001_i(f001_i),
        .f010_r(f010_r), .f010_i(f010_i), .f011_r(f011_r), .f011_i(f011_i),
        .f100_r(f100_r), .f100_i(f100_i), .f101_r(f101_r), .f101_i(f101_i),
        .f110_r(f110_r), .f110_i(f110_i), .f111_r(f111_r), .f111_i(f111_i)
    );

    // --- Fixed-Point Constants for Test ---
    localparam S34_ONE = 16;
    localparam S34_AMP = 6;

    // --- Test Sequence ---
    initial begin
        $display("--- 3-Qubit QFT Top Level Testbench (Corrected) ---");

        // Test Case: Apply QFT to the state |110> (the number 6)
        // This is our state preparation step. We set the amplitude for |110> to 1.0.
        {i000_r,i000_i,i001_r,i001_i,i010_r,i010_i,i011_r,i011_i} = 0;
        {i100_r,i100_i,i101_r,i101_i,i110_r,i110_i,i111_r,i111_i} = 0;
        i110_r = S34_ONE;

        #20; // Wait for combinational logic to settle

        // --- Verification ---
        // Expected Math Result: (1/√8) * [ 1, -i, -1, i, 1, -i, -1, i ]
        // Expected Fixed-Point (S3.4) values:
        // f000 = ( 6,  0i)
        // f001 = ( 0, -6i)
        // f010 = (-6,  0i)
        // f011 = ( 0,  6i)
        // f100 = ( 6,  0i)
        // f101 = ( 0, -6i)
        // f110 = (-6,  0i)
        // f111 = ( 0,  6i)
        $display("Testing QFT on state |110> (6)");
        $display("Final State:   [ (%d,%di), (%d,%di), (%d,%di), (%d,%di), (%d,%di), (%d,%di), (%d,%di), (%d,%di) ]",
                  f000_r,f000_i, f001_r,f001_i, f010_r,f010_i, f011_r,f011_i,
                  f100_r,f100_i, f101_r,f101_i, f110_r,f110_i, f111_r,f111_i);
        $display("Expected State:  [ (6,0i), (0,-6i), (-6,0i), (0,6i), (6,0i), (0,-6i), (-6,0i), (0,6i) ]");

        // Check against the expected S3.4 values, allowing for small rounding errors
        if (f000_r > (S34_AMP-2) && f001_i < (-S34_AMP+2) && f010_r < (-S34_AMP+2) && f011_i > (S34_AMP-2)) begin
            $display("\nResult: PASSED ✅");
        end else begin
            $display("\nResult: FAILED ❌");
        end
        
        #10 $finish;
    end
endmodule