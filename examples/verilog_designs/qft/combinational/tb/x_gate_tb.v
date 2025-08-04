`timescale 1ns/1ps
`include "fixed_point_params.vh"

module x_gate_tb;
    // --- Testbench signals ---
    reg  signed [`TOTAL_WIDTH-1:0] alpha_r_in, alpha_i_in;
    reg  signed [`TOTAL_WIDTH-1:0] beta_r_in,  beta_i_in;
    wire signed [`TOTAL_WIDTH-1:0] alpha_r_out, alpha_i_out;
    wire signed [`TOTAL_WIDTH-1:0] beta_r_out,  beta_i_out;

    // --- Instantiate the DUT (Corrected) ---
    // We explicitly connect each port on the x_gate module to the
    // corresponding reg or wire in this testbench.
    x_gate uut (
        .alpha_r(alpha_r_in),
        .alpha_i(alpha_i_in),
        .beta_r(beta_r_in),
        .beta_i(beta_i_in),
        .new_alpha_r(alpha_r_out),
        .new_alpha_i(alpha_i_out),
        .new_beta_r(beta_r_out),
        .new_beta_i(beta_i_out)
    );

    // --- Test Sequence ---
    initial begin
        $display("--- X-Gate Testbench ---");
        // State: 0.6|0> + 0.8i|1> -> S3.4: (10)|0> + (13i)|1>
        alpha_r_in = 10; alpha_i_in = 0;
        beta_r_in  = 0;  beta_i_in  = 13;
        #10;

        // Expected: 0.8i|0> + 0.6|1> -> S3.4: (0, 13i) and (10, 0i)
        if (alpha_r_out == 0 && alpha_i_out == 13 && beta_r_out == 10 && beta_i_out == 0)
            $display("Result: PASSED ✅");
        else
            $display("Result: FAILED ❌");
            
        #10 $finish;
    end
endmodule