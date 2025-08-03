`timescale 1ns/1ps
`include "fixed_point_params.vh"

module h_gate_tb;
    // --- Testbench signals ---
    reg  signed [`TOTAL_WIDTH-1:0] alpha_r_in, alpha_i_in, beta_r_in, beta_i_in;
    wire signed [`TOTAL_WIDTH-1:0] alpha_r_out, alpha_i_out, beta_r_out, beta_i_out;
    integer test_num = 0;

    // --- Instantiate the DUT (Device Under Test) ---
    h_gate uut (
        .alpha_r(alpha_r_in), .alpha_i(alpha_i_in),
        .beta_r(beta_r_in),   .beta_i(beta_i_in),
        .new_alpha_r(alpha_r_out), .new_alpha_i(alpha_i_out),
        .new_beta_r(beta_r_out),   .new_beta_i(beta_i_out)
    );

    // --- Fixed-Point Constants for easy reference in S3.4 format ---
    localparam S34_ONE         = 16; // Represents 1.0
    localparam S34_SQRT2_INV   = 11; // Represents 1/sqrt(2) ~ 0.7071
    localparam S34_HH_UNITY    = 15; // Represents the result of H*H*|0>. Ideally 16 (1.0), but 15 due to rounding.

    // --- Reusable Task to run a single test case ---
    task run_test;
        input [127:0] test_name;
        input signed [`TOTAL_WIDTH-1:0] ar_in, ai_in, br_in, bi_in; // Inputs
        input signed [`TOTAL_WIDTH-1:0] ar_exp, ai_exp, br_exp, bi_exp; // Expected Outputs
        begin
            test_num = test_num + 1;
            #10; // Wait for a moment
            alpha_r_in = ar_in; alpha_i_in = ai_in;
            beta_r_in  = br_in; beta_i_in  = bi_in;
            #1; // Allow combinational logic time to settle before checking
            
            $display("--- Test Case %0d: %s ---", test_num, test_name);
            $display("Input:  alpha=(%3d, %3di), beta=(%3d, %3di)", ar_in, ai_in, br_in, bi_in);
            $display("Output: alpha=(%3d, %3di), beta=(%3d, %3di)", alpha_r_out, alpha_i_out, beta_r_out, beta_i_out);
            $display("Expect: alpha=(%3d, %3di), beta=(%3d, %3di)", ar_exp, ai_exp, br_exp, bi_exp);

            if (alpha_r_out == ar_exp && alpha_i_out == ai_exp && beta_r_out == br_exp && beta_i_out == bi_exp)
                $display("Result: PASSED ✅\n");
            else
                $display("Result: FAILED ❌\n");
        end
    endtask

    // --- Test Sequence ---
    initial begin
        // Test 1: Apply Hadamard to the |0> state
        run_test("Hadamard on |0>",
                 S34_ONE, 0, 0, 0,                                  // Input: alpha=1.0, beta=0.0
                 S34_SQRT2_INV, 0, S34_SQRT2_INV, 0);               // Expect: alpha=1/√2, beta=1/√2

        // Test 2: Apply Hadamard to the |1> state
        run_test("Hadamard on |1>",
                 0, 0, S34_ONE, 0,                                  // Input: alpha=0.0, beta=1.0
                 S34_SQRT2_INV, 0, -S34_SQRT2_INV, 0);              // Expect: alpha=1/√2, beta=-1/√2

        // Test 3: Test the identity H*H = I.
        // We apply H to the output of the first test (the |+> state).
        // The result should be the original |0> state.
        // NOTE: The result is 15 instead of 16 due to fixed-point rounding errors, which is expected.
        run_test("Hadamard on |+> state (H*H=I check)",
                 S34_SQRT2_INV, 0, S34_SQRT2_INV, 0,                // Input: alpha=1/√2, beta=1/√2
                 S34_HH_UNITY, 0, 0, 0);                            // Expect: alpha=1.0, beta=0.0 (with rounding)

        // Test 4: Apply Hadamard to a state with an imaginary component
        // Input: (1/√2)|0> + (i/√2)|1>
        // S3.4 In: alpha=(11, 0), beta=(0, 11)
        // Math: ( (11+0) + i*(0+11) ) * 11 => (11+11i)*11 => (121+121i)>>>4 => (7.56+7.56i) => 8+8i
        //       ( (11-0) + i*(0-11) ) * 11 => (11-11i)*11 => (121-121i)>>>4 => (7.56-7.56i) => 8-8i
        run_test("Hadamard on state with imaginary part",
                 S34_SQRT2_INV, 0, 0, S34_SQRT2_INV,                // Input: alpha=1/√2, beta=i/√2
                 8, 8, 8, -8);                                     // Expect: alpha=(0.5+0.5i), beta=(0.5-0.5i)

        #10 $finish;
    end
endmodule