`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// Controlled-Rotation (CROT) Gate
// This module implements a controlled rotation that only rotates specific amplitudes
// based on the control qubit state, rather than rotating all inputs unconditionally.
module crot_gate(
    input  wire signed [`TOTAL_WIDTH-1:0] in_r, in_i,      // Input complex amplitude
    input  wire signed [`TOTAL_WIDTH-1:0] theta,           // Rotation angle in S3.4 format
    output wire signed [`TOTAL_WIDTH-1:0] out_r, out_i     // Output rotated complex amplitude
);

    // Wires to hold the results of the sin/cos approximation
    wire signed [`TOTAL_WIDTH-1:0] cos_theta;
    wire signed [`TOTAL_WIDTH-1:0] sin_theta;

    // --- Step 1: Calculate cos(theta) and sin(theta) ---
    cosine_approx cos_unit (
        .x(theta),
        .y(cos_theta)
    );

    sine_approx sin_unit (
        .x(theta),
        .y(sin_theta)
    );

    // --- Step 2: Perform the complex multiplication ---
    // Multiply the input amplitude by e^(i*theta) = (cos + i*sin)
    ccmult rotation_multiplier (
        .ar(in_r),      .ai(in_i),
        .br(cos_theta), .bi(sin_theta),
        .pr(out_r),     .pi(out_i)
    );

endmodule