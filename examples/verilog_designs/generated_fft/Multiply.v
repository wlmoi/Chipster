//------------------------------------------------------------------------------
// Module: Multiply
// Description: Complex multiplier with a 3-stage pipeline.
// c = a * b
// c_re = a_re * b_re - a_im * b_im
// c_im = a_re * b_im + a_im * b_re
//------------------------------------------------------------------------------
module Multiply #(
    parameter   WIDTH = 16
)(
    input                   clock,
    input                   reset,
    input                   in_en,
    input   [WIDTH-1:0]     a_re,
    input   [WIDTH-1:0]     a_im,
    input   [WIDTH-1:0]     b_re,
    input   [WIDTH-1:0]     b_im,
    output                  out_en,
    output  [WIDTH-1:0]     c_re,
    output  [WIDTH-1:0]     c_im
);

    //
    // pipeline stage 1
    //
    reg                     s1_en;
    reg     [WIDTH-1:0]     s1_a_re;
    reg     [WIDTH-1:0]     s1_a_im;
    reg     [WIDTH-1:0]     s1_b_re;
    reg     [WIDTH-1:0]     s1_b_im;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s1_en <= 1'b0;
        end else begin
            s1_en <= in_en;
        end
    end

    always @(posedge clock) begin
        if (in_en) begin
            s1_a_re <= a_re;
            s1_a_im <= a_im;
            s1_b_re <= b_re;
            s1_b_im <= b_im;
        end
    end

    //
    // pipeline stage 2
    //
    reg                     s2_en;
    reg     signed [2*WIDTH-1:0]    p1; // a_re * b_re
    reg     signed [2*WIDTH-1:0]    p2; // a_im * b_im
    reg     signed [2*WIDTH-1:0]    p3; // a_re * b_im
    reg     signed [2*WIDTH-1:0]    p4; // a_im * b_re

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s2_en <= 1'b0;
        end else begin
            s2_en <= s1_en;
        end
    end

    always @(posedge clock) begin
        if (s1_en) begin
            p1 <= $signed(s1_a_re) * $signed(s1_b_re);
            p2 <= $signed(s1_a_im) * $signed(s1_b_im);
            p3 <= $signed(s1_a_re) * $signed(s1_b_im);
            p4 <= $signed(s1_a_im) * $signed(s1_b_re);
        end
    end

    //
    // pipeline stage 3
    //
    reg                     s3_en;
    reg     signed [2*WIDTH:0]      c_re_w;
    reg     signed [2*WIDTH:0]      c_im_w;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            s3_en <= 1'b0;
        end else begin
            s3_en <= s2_en;
        end
    end

    always @(posedge clock) begin
        if (s2_en) begin
            c_re_w <= p1 - p2;
            c_im_w <= p3 + p4;
        end
    end

    //
    // output
    //
    assign out_en = s3_en;
    assign c_re = c_re_w[2*WIDTH-2:WIDTH-1];
    assign c_im = c_im_w[2*WIDTH-2:WIDTH-1];

endmodule
