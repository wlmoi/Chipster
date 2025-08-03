`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module ccmult(
    input  wire clk,
    input  wire rst_n,
    input  signed [`TOTAL_WIDTH-1:0] ar, ai,
    input  signed [`TOTAL_WIDTH-1:0] br, bi,
    output reg signed [`TOTAL_WIDTH-1:0] pr, pi
);

    // Pipeline stage 1: Multiplication
    reg signed [`MULT_WIDTH-1:0] p_ar_br_reg, p_ai_bi_reg, p_ar_bi_reg, p_ai_br_reg;
    
    // Pipeline stage 2: Addition/Subtraction and Scaling
    reg signed [`MULT_WIDTH:0] real_sum_reg, imag_sum_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Stage 1 reset
            p_ar_br_reg <= 0;
            p_ai_bi_reg <= 0;
            p_ar_bi_reg <= 0;
            p_ai_br_reg <= 0;
            // Stage 2 reset
            real_sum_reg <= 0;
            imag_sum_reg <= 0;
            // Output reset
            pr <= 0;
            pi <= 0;
        end else begin
            // Stage 1: Perform multiplications
            p_ar_br_reg <= ar * br;
            p_ai_bi_reg <= ai * bi;
            p_ar_bi_reg <= ar * bi;
            p_ai_br_reg <= ai * br;
            
            // Stage 2: Perform additions/subtractions
            real_sum_reg <= p_ar_br_reg - p_ai_bi_reg;
            imag_sum_reg <= p_ar_bi_reg + p_ai_br_reg;
            
            // Stage 3: Scale the results back down
            pr <= real_sum_reg >>> `FRAC_WIDTH;
            pi <= imag_sum_reg >>> `FRAC_WIDTH;
        end
    end
    
endmodule