//------------------------------------------------------------------------------
// Module: FFT
// Description: Top-level module for a 64-point Radix-2^2 SDF FFT.
//------------------------------------------------------------------------------
module FFT #(
    parameter   WIDTH = 16,
    parameter   N_LOG2 = 6  // Set to 6 for 64-point FFT
)(
    input               clock,
    input               reset,
    input               di_en,
    input   [WIDTH-1:0] di_re,
    input   [WIDTH-1:0] di_im,
    output              do_en,
    output  [WIDTH-1:0] do_re,
    output  [WIDTH-1:0] do_im
);

    //
    // scaling
    //
    wire    [WIDTH-1:0]     s_di_re;
    wire    [WIDTH-1:0]     s_di_im;

    // Scale input by 1/2 to prevent overflow in butterfly stages
    assign s_di_re = {{di_re[WIDTH-1]}, di_re[WIDTH-1:1]};
    assign s_di_im = {{di_im[WIDTH-1]}, di_im[WIDTH-1:1]};

    //
    // stage 1 (Radix-2^2)
    //
    wire                    s1_en;
    wire    [WIDTH-1:0]     s1_re;
    wire    [WIDTH-1:0]     s1_im;

    SdfUnit2 #(
        .WIDTH(WIDTH),
        .DELAY(1<<(N_LOG2-2)),
        .ADDR_WIDTH(N_LOG2-2)
    ) u_stage1 (
        .clock(clock),
        .reset(reset),
        .in_en(di_en),
        .in_re(s_di_re),
        .in_im(s_di_im),
        .out_en(s1_en),
        .out_re(s1_re),
        .out_im(s1_im)
    );

    //
    // stage 2
    //
    wire                    s2_en;
    wire    [WIDTH-1:0]     s2_re;
    wire    [WIDTH-1:0]     s2_im;
    wire    [N_LOG2-3-1:0]  s2_tw_addr;

    SdfUnit #(
        .WIDTH(WIDTH),
        .DELAY(1<<(N_LOG2-3)),
        .ADDR_WIDTH(N_LOG2-3),
        .TW_ADDR_WIDTH(N_LOG2-3)
    ) u_stage2 (
        .clock(clock),
        .reset(reset),
        .in_en(s1_en),
        .in_re(s1_re),
        .in_im(s1_im),
        .out_en(s2_en),
        .out_re(s2_re),
        .out_im(s2_im),
        .tw_addr(s2_tw_addr)
    );

    //
    // stage 3
    //
    wire                    s3_en;
    wire    [WIDTH-1:0]     s3_re;
    wire    [WIDTH-1:0]     s3_im;
    wire    [N_LOG2-4-1:0]  s3_tw_addr;

    SdfUnit #(
        .WIDTH(WIDTH),
        .DELAY(1<<(N_LOG2-4)),
        .ADDR_WIDTH(N_LOG2-4),
        .TW_ADDR_WIDTH(N_LOG2-4)
    ) u_stage3 (
        .clock(clock),
        .reset(reset),
        .in_en(s2_en),
        .in_re(s2_re),
        .in_im(s2_im),
        .out_en(s3_en),
        .out_re(s3_re),
        .out_im(s3_im),
        .tw_addr(s3_tw_addr)
    );

    //
    // stage 4
    //
    wire                    s4_en;
    wire    [WIDTH-1:0]     s4_re;
    wire    [WIDTH-1:0]     s4_im;
    wire    [N_LOG2-5-1:0]  s4_tw_addr;

    SdfUnit #(
        .WIDTH(WIDTH),
        .DELAY(1<<(N_LOG2-5)),
        .ADDR_WIDTH(N_LOG2-5),
        .TW_ADDR_WIDTH(N_LOG2-5)
    ) u_stage4 (
        .clock(clock),
        .reset(reset),
        .in_en(s3_en),
        .in_re(s3_re),
        .in_im(s3_im),
        .out_en(s4_en),
        .out_re(s4_re),
        .out_im(s4_im),
        .tw_addr(s4_tw_addr)
    );

    //
    // stage 5
    //
    wire                    s5_en;
    wire    [WIDTH-1:0]     s5_re;
    wire    [WIDTH-1:0]     s5_im;
    wire    [N_LOG2-6-1:0]  s5_tw_addr; // This will be 0 bits wide for N_LOG2=6

    SdfUnit #(
        .WIDTH(WIDTH),
        .DELAY(1<<(N_LOG2-6)),
        .ADDR_WIDTH(N_LOG2-6),
        .TW_ADDR_WIDTH(N_LOG2-6)
    ) u_stage5 (
        .clock(clock),
        .reset(reset),
        .in_en(s4_en),
        .in_re(s4_re),
        .in_im(s4_im),
        .out_en(s5_en),
        .out_re(s5_re),
        .out_im(s5_im),
        .tw_addr(s5_tw_addr)
    );

    //
    // twiddle factor
    //
    wire    [3:0]           tw_addr;
    wire    [WIDTH-1:0]     tw_re;
    wire    [WIDTH-1:0]     tw_im;

    // Concatenate addresses from stages to form the final twiddle address
    assign tw_addr = {s5_tw_addr, s4_tw_addr, s3_tw_addr, s2_tw_addr};

    Twiddle #(
        .WIDTH(WIDTH)
    ) u_tw (
        .clock(clock),
        .addr(tw_addr),
        .w_re(tw_re),
        .w_im(tw_im)
    );

    //
    // multiply
    //
    wire                    mul_en;
    wire    [WIDTH-1:0]     mul_re;
    wire    [WIDTH-1:0]     mul_im;

    Multiply #(
        .WIDTH(WIDTH)
    ) u_mul (
        .clock(clock),
        .reset(reset),
        .in_en(s5_en),
        .a_re(s5_re),
        .a_im(s5_im),
        .b_re(tw_re),
        .b_im(tw_im),
        .out_en(mul_en),
        .c_re(mul_re),
        .c_im(mul_im)
    );

    //
    // output
    //
    assign do_en = mul_en;
    assign do_re = mul_re;
    assign do_im = mul_im;

endmodule
