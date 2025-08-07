//------------------------------------------------------------------------------
// Module: Butterfly
// Description: Radix-2 butterfly unit.
// c = a + b
// d = a - b
//------------------------------------------------------------------------------
module Butterfly #(
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
    output  [WIDTH-1:0]     c_im,
    output  [WIDTH-1:0]     d_re,
    output  [WIDTH-1:0]     d_im
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
    // output
    //
    assign out_en = s1_en;
    assign c_re = s1_a_re + s1_b_re;
    assign c_im = s1_a_im + s1_b_im;
    assign d_re = s1_a_re - s1_b_re;
    assign d_im = s1_a_im - s1_b_im;

endmodule
