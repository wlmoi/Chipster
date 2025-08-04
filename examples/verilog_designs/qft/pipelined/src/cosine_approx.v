`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module cosine_approx(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] x,
    output reg signed [`TOTAL_WIDTH-1:0] y
);
    // Breakpoints for cos(x) [-2pi, 2pi] from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        BP_N101 = -101, BP_N88 = -88, BP_N75 = -75, BP_N63 = -63,
        BP_N50 = -50,  BP_N38 = -38, BP_N25 = -25, BP_N13 = -13,
        BP_0   = 0,    BP_P13 = 13,  BP_P25 = 25,  BP_P38 = 38,
        BP_P50 = 50,  BP_P63 = 63,  BP_P75 = 75,  BP_P88 = 88;

    // Slopes for each segment from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        S0 = -6, S1 = -14, S2 = -14, S3 = -6, S4 = 6,  S5 = 14, S6 = 14,  S7 = 6,
        S8 = -6, S9 = -14, S10= -14, S11= -6, S12= 6,  S13= 14, S14= 14, S15= 6;

    // Intercepts for each segment from your CSV (CORRECTED)
    localparam signed [`TOTAL_WIDTH-1:0]
        I0 = -21, I1 = -68, I2 = -68, I3 = -35, I4 = 3,  I5 = 23, I6 = 23,  I7 = 16,
        I8 = 16,  I9 = 23,  I10= 23,  I11= 3,   I12= -35,I13= -68,I14= -68, I15= -21;

    // Pipeline registers
    reg signed [`TOTAL_WIDTH-1:0] x_reg;
    reg signed [`TOTAL_WIDTH-1:0] slope_reg, intercept_reg;
    reg signed [`TOTAL_WIDTH*2-1:0] temp_mult_reg;
    reg signed [`TOTAL_WIDTH-1:0] scaled_mult_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 0;
            slope_reg <= 0;
            intercept_reg <= 0;
            temp_mult_reg <= 0;
            scaled_mult_reg <= 0;
            y <= 0;
        end else begin
            // Stage 1: Register input and determine slope/intercept
            x_reg <= x;
            
            slope_reg <= (x < BP_N88) ? S0 : (x < BP_N75) ? S1 : (x < BP_N63) ? S2 : (x < BP_N50) ? S3 :
                         (x < BP_N38) ? S4 : (x < BP_N25) ? S5 : (x < BP_N13) ? S6 : (x < BP_0)   ? S7 :
                         (x < BP_P13) ? S8 : (x < BP_P25) ? S9 : (x < BP_P38) ? S10: (x < BP_P50) ? S11:
                         (x < BP_P63) ? S12: (x < BP_P75) ? S13: (x < BP_P88) ? S14: S15;

            intercept_reg <= (x < BP_N88) ? I0 : (x < BP_N75) ? I1 : (x < BP_N63) ? I2 : (x < BP_N50) ? I3 :
                             (x < BP_N38) ? I4 : (x < BP_N25) ? I5 : (x < BP_N13) ? I6 : (x < BP_0)   ? I7 :
                             (x < BP_P13) ? I8 : (x < BP_P25) ? I9 : (x < BP_P38) ? I10: (x < BP_P50) ? I11:
                             (x < BP_P63) ? I12: (x < BP_P75) ? I13: (x < BP_P88) ? I14: I15;
            
            // Stage 2: Multiply
            temp_mult_reg <= x_reg * slope_reg;
            
            // Stage 3: Scale and add intercept
            scaled_mult_reg <= temp_mult_reg >>> `FRAC_WIDTH;
            
            // Stage 4: Final result
            y <= scaled_mult_reg + intercept_reg;
        end
    end
endmodule