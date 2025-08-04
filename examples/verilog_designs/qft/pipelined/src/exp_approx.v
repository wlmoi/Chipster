`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module exp_approx(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] x,
    output reg signed [`TOTAL_WIDTH-1:0] y
);
    // Breakpoints for exp(x) from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        BP_N80 = -80, BP_N70 = -70, BP_N60 = -60, BP_N50 = -50,
        BP_N40 = -40, BP_N30 = -30, BP_N20 = -20, BP_N10 = -10,
        BP_0   = 0,   BP_P10 = 10,  BP_P20 = 20,  BP_P30 = 30,
        BP_P40 = 40,  BP_P50 = 50,  BP_P60 = 60,  BP_P70 = 70;

    // !! CRITICAL: Using 32-bit width for slopes/intercepts to prevent overflow !!
    localparam signed [31:0]
        S0=0, S1=0, S2=1, S3=1, S4=2, S5=3, S6=6, S7=12,
        S8=22, S9=42, S10=78, S11=145, S12=271, S13=506, S14=945, S15=1766;
    localparam signed [31:0]
        I0=1, I1=1, I2=2, I3=4, I4=6, I5=9, I6=13, I7=16,
        I8=16, I9=4, I10=-41,I11=-167,I12=-482,I13=-1217,I14=-2864,I15=-6454;

    // Pipeline registers
    reg signed [`TOTAL_WIDTH-1:0] x_reg;
    reg signed [31:0] slope_reg, intercept_reg;
    reg signed [`TOTAL_WIDTH+31:0] temp_mult_reg;
    reg signed [31:0] result_wide_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_reg <= 0;
            slope_reg <= 0;
            intercept_reg <= 0;
            temp_mult_reg <= 0;
            result_wide_reg <= 0;
            y <= 0;
        end else begin
            // Stage 1: Register input and determine slope/intercept
            x_reg <= x;
            
            slope_reg <= (x < BP_N70) ? S0 : (x < BP_N60) ? S1 : (x < BP_N50) ? S2 :
                         (x < BP_N40) ? S3 : (x < BP_N30) ? S4 : (x < BP_N20) ? S5 :
                         (x < BP_N10) ? S6 : (x < BP_0)   ? S7 : (x < BP_P10) ? S8 :
                         (x < BP_P20) ? S9 : (x < BP_P30) ? S10: (x < BP_P40) ? S11:
                         (x < BP_P50) ? S12: (x < BP_P60) ? S13: (x < BP_P70) ? S14: S15;

            intercept_reg <= (x < BP_N70) ? I0 : (x < BP_N60) ? I1 : (x < BP_N50) ? I2 :
                             (x < BP_N40) ? I3 : (x < BP_N30) ? I4 : (x < BP_N20) ? I5 :
                             (x < BP_N10) ? I6 : (x < BP_0)   ? I7 : (x < BP_P10) ? I8 :
                             (x < BP_P20) ? I9 : (x < BP_P30) ? I10: (x < BP_P40) ? I11:
                             (x < BP_P50) ? I12: (x < BP_P60) ? I13: (x < BP_P70) ? I14: I15;
            
            // Stage 2: Multiply
            temp_mult_reg <= x_reg * slope_reg;
            
            // Stage 3: Scale and add intercept
            result_wide_reg <= (temp_mult_reg >>> `FRAC_WIDTH) + intercept_reg;
            
            // Stage 4: Saturation and casting back to 8-bit output
            y <= (result_wide_reg > 127)  ? 127 :       // Clamp if > max signed 8-bit
                 (result_wide_reg < -128) ? -128 :      // Clamp if < min signed 8-bit
                 result_wide_reg[`TOTAL_WIDTH-1:0];     // Otherwise, cast to output width
        end
    end
endmodule