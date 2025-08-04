`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module sine_approx(
    input  wire signed [`TOTAL_WIDTH-1:0] x,
    output wire signed [`TOTAL_WIDTH-1:0] y
);

    // Breakpoints for sin(x) [-2pi, 2pi] from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        BP_N101 = -101, BP_N88 = -88, BP_N75 = -75, BP_N63 = -63,
        BP_N50 = -50,  BP_N38 = -38, BP_N25 = -25, BP_N13 = -13,
        BP_0   = 0,    BP_P13 = 13,  BP_P25 = 25,  BP_P38 = 38,
        BP_P50 = 50,  BP_P63 = 63,  BP_P75 = 75,  BP_P88 = 88;

    // Slopes for each segment from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        S0 = 14, S1 = 6,  S2 = -6, S3 = -14, S4 = -14, S5 = -6,
        S6 = 6,  S7 = 14, S8 = 14, S9 = 6,   S10= -6,  S11= -14,
        S12= -14,S13= -6, S14= 6,  S15= 14;

    // Intercepts for each segment from your CSV
    localparam signed [`TOTAL_WIDTH-1:0]
        I0 = 91, I1 = 44,  I2 = -12, I3 = -45, I4 = -45, I5 = -25,
        I6 = -7, I7 = 0,   I8 = 0,   I9 = 7,   I10= 25,  I11= 45,
        I12= 45, I13= 12,  I14= -44, I15= -91;

    wire signed [`TOTAL_WIDTH-1:0] slope, intercept;
    wire signed [`TOTAL_WIDTH*2-1:0] temp_mult;
    wire signed [`TOTAL_WIDTH-1:0] scaled_mult;

    // Selection logic based on the new breakpoints
    assign slope = (x < BP_N88) ? S0 : (x < BP_N75) ? S1 : (x < BP_N63) ? S2 : (x < BP_N50) ? S3 :
                   (x < BP_N38) ? S4 : (x < BP_N25) ? S5 : (x < BP_N13) ? S6 : (x < BP_0)   ? S7 :
                   (x < BP_P13) ? S8 : (x < BP_P25) ? S9 : (x < BP_P38) ? S10: (x < BP_P50) ? S11:
                   (x < BP_P63) ? S12: (x < BP_P75) ? S13: (x < BP_P88) ? S14: S15;

    assign intercept = (x < BP_N88) ? I0 : (x < BP_N75) ? I1 : (x < BP_N63) ? I2 : (x < BP_N50) ? I3 :
                       (x < BP_N38) ? I4 : (x < BP_N25) ? I5 : (x < BP_N13) ? I6 : (x < BP_0)   ? I7 :
                       (x < BP_P13) ? I8 : (x < BP_P25) ? I9 : (x < BP_P38) ? I10: (x < BP_P50) ? I11:
                       (x < BP_P63) ? I12: (x < BP_P75) ? I13: (x < BP_P88) ? I14: I15;

    // y = m*x + c
    assign temp_mult   = x * slope;
    assign scaled_mult = temp_mult >>> `FRAC_WIDTH;
    assign y           = scaled_mult + intercept;

endmodule