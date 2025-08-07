//------------------------------------------------------------------------------
// Module: SdfUnit2
// Description: Radix-2^2 Single-path Delay Feedback Unit (first stage).
//------------------------------------------------------------------------------
module SdfUnit2 #(
    parameter   WIDTH = 16,
    parameter   DELAY = 16,
    parameter   ADDR_WIDTH = 4
)(
    input                   clock,
    input                   reset,
    input                   in_en,
    input   [WIDTH-1:0]     in_re,
    input   [WIDTH-1:0]     in_im,
    output                  out_en,
    output  [WIDTH-1:0]     out_re,
    output  [WIDTH-1:0]     out_im
);

    //
    // butterfly
    //
    wire                    bf_en;
    wire    [WIDTH-1:0]     bf_a_re;
    wire    [WIDTH-1:0]     bf_a_im;
    wire    [WIDTH-1:0]     bf_b_re;
    wire    [WIDTH-1:0]     bf_b_im;
    wire                    bf_out_en;
    wire    [WIDTH-1:0]     bf_c_re;
    wire    [WIDTH-1:0]     bf_c_im;
    wire    [WIDTH-1:0]     bf_d_re;
    wire    [WIDTH-1:0]     bf_d_im;

    assign bf_en = in_en;
    assign bf_a_re = in_re;
    assign bf_a_im = in_im;

    Butterfly #(
        .WIDTH(WIDTH)
    ) u_bf (
        .clock(clock),
        .reset(reset),
        .in_en(bf_en),
        .a_re(bf_a_re),
        .a_im(bf_a_im),
        .b_re(bf_b_re),
        .b_im(bf_b_im),
        .out_en(bf_out_en),
        .c_re(bf_c_re),
        .c_im(bf_c_im),
        .d_re(bf_d_re),
        .d_im(bf_d_im)
    );

    //
    // delay buffer
    //
    wire                    db_re_en;
    wire    [WIDTH-1:0]     db_re_in;
    wire                    db_re_out_en;
    wire    [WIDTH-1:0]     db_re_out;
    wire                    db_im_en;
    wire    [WIDTH-1:0]     db_im_in;
    wire                    db_im_out_en;
    wire    [WIDTH-1:0]     db_im_out;

    assign db_re_en = bf_out_en;
    assign db_re_in = bf_c_re;
    assign db_im_en = bf_out_en;
    assign db_im_in = bf_c_im;

    assign bf_b_re = db_re_out;
    assign bf_b_im = db_im_out;

    DelayBuffer #(
        .WIDTH(WIDTH),
        .DELAY(DELAY),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_db_re (
        .clock(clock),
        .reset(reset),
        .in_en(db_re_en),
        .in_data(db_re_in),
        .out_en(db_re_out_en),
        .out_data(db_re_out)
    );

    DelayBuffer #(
        .WIDTH(WIDTH),
        .DELAY(DELAY),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) u_db_im (
        .clock(clock),
        .reset(reset),
        .in_en(db_im_en),
        .in_data(db_im_in),
        .out_en(db_im_out_en),
        .out_data(db_im_out)
    );

    //
    // output
    //
    assign out_en = bf_out_en;
    assign out_re = bf_d_re;
    assign out_im = bf_d_im;

endmodule
