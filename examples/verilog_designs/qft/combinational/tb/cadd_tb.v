`timescale 1ns/1ps
`include "fixed_point_params.vh"

module cadd_tb;

    reg  signed [`TOTAL_WIDTH-1:0] ar, ai, br, bi;
    wire signed [`ADD_WIDTH-1:0]   pr, pi;

    cadd uut (.ar(ar), .ai(ai), .br(br), .bi(bi), .pr(pr), .pi(pi));

    initial begin
        $display("--- Complex Adder Testbench ---");

        // Test 1: (1.5 + 2.25i) + (1.0 - 0.5i) = 2.5 + 1.75i
        // S3.4 In: (24 + 36i) + (16 - 8i)
        // S3.4 Out: (40 + 28i)
        ar = 24; ai = 36; br = 16; bi = -8;
        #10;
        if (pr == 40 && pi == 28) $display("Test 1 PASSED");
        else $display("Test 1 FAILED: Got (%d, %d), Expected (40, 28)", pr, pi);

        #10 $finish;
    end
endmodule