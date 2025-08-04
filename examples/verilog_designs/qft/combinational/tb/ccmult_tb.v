`timescale 1ns/1ps
`include "fixed_point_params.vh"

module ccmult_tb;

    reg  signed [`TOTAL_WIDTH-1:0] ar, ai, br, bi;
    wire signed [`TOTAL_WIDTH-1:0] pr, pi;

    ccmult uut (.ar(ar), .ai(ai), .br(br), .bi(bi), .pr(pr), .pi(pi));

    initial begin
        $display("--- Complex Multiplier Testbench ---");

        // Test 1: (1.5 + 1.0i) * (2.0 + 0.5i) = (3 - 0.5) + i(0.75 + 2) = 2.5 + 2.75i
        // S3.4 In: (24 + 16i) * (32 + 8i)
        // S3.4 Out: (40 + 44i)
        ar = 24; ai = 16; br = 32; bi = 8;
        #10;
        if (pr == 40 && pi == 44) $display("Test 1 PASSED");
        else $display("Test 1 FAILED: Got (%d, %d), Expected (40, 44)", pr, pi);
        
        #10 $finish;
    end
endmodule