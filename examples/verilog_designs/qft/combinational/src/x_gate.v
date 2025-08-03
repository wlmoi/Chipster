`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// The X-Gate (or quantum NOT gate) swaps the |0> and |1>
// amplitudes of a single qubit's state vector.
module x_gate(
    input  signed [`TOTAL_WIDTH-1:0] alpha_r, alpha_i, // Amplitude of |0>
    input  signed [`TOTAL_WIDTH-1:0] beta_r,  beta_i,  // Amplitude of |1>
    output signed [`TOTAL_WIDTH-1:0] new_alpha_r, new_alpha_i,
    output signed [`TOTAL_WIDTH-1:0] new_beta_r,  new_beta_i
);
    // New alpha is the old beta
    assign new_alpha_r = beta_r;
    assign new_alpha_i = beta_i;
    
    // New beta is the old alpha
    assign new_beta_r = alpha_r;
    assign new_beta_i = alpha_i;
    
endmodule