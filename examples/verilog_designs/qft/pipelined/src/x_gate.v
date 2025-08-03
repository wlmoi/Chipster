`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// The X-Gate (or quantum NOT gate) swaps the |0> and |1>
// amplitudes of a single qubit's state vector.
module x_gate(
    input  wire clk,
    input  wire rst_n,
    input  signed [`TOTAL_WIDTH-1:0] alpha_r, alpha_i, // Amplitude of |0>
    input  signed [`TOTAL_WIDTH-1:0] beta_r,  beta_i,  // Amplitude of |1>
    output reg signed [`TOTAL_WIDTH-1:0] new_alpha_r, new_alpha_i,
    output reg signed [`TOTAL_WIDTH-1:0] new_beta_r,  new_beta_i
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            new_alpha_r <= 0;
            new_alpha_i <= 0;
            new_beta_r <= 0;
            new_beta_i <= 0;
        end else begin
            // New alpha is the old beta
            new_alpha_r <= beta_r;
            new_alpha_i <= beta_i;
            
            // New beta is the old alpha
            new_beta_r <= alpha_r;
            new_beta_i <= alpha_i;
        end
    end
    
endmodule