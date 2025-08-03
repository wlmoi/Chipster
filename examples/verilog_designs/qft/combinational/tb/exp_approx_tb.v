`timescale 1ns/1ps
`include "fixed_point_params.vh"

module exp_approx_tb;

    // --- Testbench signals ---
    reg  signed [`TOTAL_WIDTH-1:0] x_in;
    wire signed [`TOTAL_WIDTH-1:0] y_out;
    integer i;

    // --- Instantiate the DUT ---
    exp_approx uut (.x(x_in), .y(y_out));

    // --- Test Sequence using a for loop ---
    initial begin
        $display("--- Exponential Approximation Full Range Test ---");
        $display("Input (S3.4) | Output (S3.4)");
        $display("----------------------------------");

        // Loop through every possible input value from -128 to 127
        for (i = -128; i < 128; i = i + 1) begin
            x_in = i;
            // Wait for combinational logic to settle
            #1;
            $display("      %d      |      %d", x_in, y_out);
        end

        #10 $finish;
    end
endmodule

