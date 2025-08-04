`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// Pipelined Controlled-Rotation (CROT) Gate
// Rotates a complex amplitude by a given angle theta.
// This is done by multiplying the input by e^(i*theta).
// e^(i*theta) = cos(theta) + i*sin(theta)
module crot_gate(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] in_r, in_i,      // Input complex amplitude
    input  wire signed [`TOTAL_WIDTH-1:0] theta,           // Rotation angle in S3.4 format
    output wire signed [`TOTAL_WIDTH-1:0] out_r, out_i     // Output rotated complex amplitude
);

    // Wires to hold the results of the sin/cos approximation
    wire signed [`TOTAL_WIDTH-1:0] cos_theta;
    wire signed [`TOTAL_WIDTH-1:0] sin_theta;

    // --- Step 1: Calculate cos(theta) and sin(theta) ---
    // Instantiate the pipelined approximation modules
    cosine_approx cos_unit (
        .clk(clk),
        .rst_n(rst_n),
        .x(theta),
        .y(cos_theta)
    );

    sine_approx sin_unit (
        .clk(clk),
        .rst_n(rst_n),
        .x(theta),
        .y(sin_theta)
    );

    // --- Step 2: Perform the complex multiplication ---
    // Multiply the input amplitude by the (cos + i*sin) vector.
    // Note: Input needs to be delayed to match the trigonometric function pipeline delay
    reg signed [`TOTAL_WIDTH-1:0] in_r_delayed[0:3], in_i_delayed[0:3];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            in_r_delayed[0] <= 0; in_i_delayed[0] <= 0;
            in_r_delayed[1] <= 0; in_i_delayed[1] <= 0;
            in_r_delayed[2] <= 0; in_i_delayed[2] <= 0;
            in_r_delayed[3] <= 0; in_i_delayed[3] <= 0;
        end else begin
            in_r_delayed[0] <= in_r;     in_i_delayed[0] <= in_i;
            in_r_delayed[1] <= in_r_delayed[0]; in_i_delayed[1] <= in_i_delayed[0];
            in_r_delayed[2] <= in_r_delayed[1]; in_i_delayed[2] <= in_i_delayed[1];
            in_r_delayed[3] <= in_r_delayed[2]; in_i_delayed[3] <= in_i_delayed[2];
        end
    end
    
    ccmult rotation_multiplier (
        .clk(clk),
        .rst_n(rst_n),
        .ar(in_r_delayed[3]), .ai(in_i_delayed[3]),
        .br(cos_theta),       .bi(sin_theta),
        .pr(out_r),           .pi(out_i)
    );

endmodule