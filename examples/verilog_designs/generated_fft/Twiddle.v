//------------------------------------------------------------------------------
// Module: Twiddle
// Description: Twiddle Factor ROM for 64-point FFT.
//------------------------------------------------------------------------------
module Twiddle #(
    parameter   WIDTH = 16
)(
    input                   clock,
    input       [3:0]       addr,
    output      [WIDTH-1:0] w_re,
    output      [WIDTH-1:0] w_im
);

    reg     [WIDTH-1:0]     re;
    reg     [WIDTH-1:0]     im;

    assign w_re = re;
    assign w_im = im;

    localparam W16_0_RE = 16'h7fff; localparam W16_0_IM = 16'h0000;
    localparam W16_1_RE = 16'h7f62; localparam W16_1_IM = 16'hef89;
    localparam W16_2_RE = 16'h7d8a; localparam W16_2_IM = 16'hdee8;
    localparam W16_3_RE = 16'h7a7d; localparam W16_3_IM = 16'heca3;
    localparam W16_4_RE = 16'h7642; localparam W16_4_IM = 16'he925;
    localparam W16_5_RE = 16'h70e3; localparam W16_5_IM = 16'he4d5;
    localparam W16_6_RE = 16'h6a6e; localparam W16_6_IM = 16'he01f;
    localparam W16_7_RE = 16'h62f2; localparam W16_7_IM = 16'hdaae;
    localparam W16_8_RE = 16'h5a82; localparam W16_8_IM = 16'hd492;
    localparam W16_9_RE = 16'h5184; localparam W16_9_IM = 16'hcdde;
    localparam W16_10_RE = 16'h47d7; localparam W16_10_IM = 16'hc6a1;
    localparam W16_11_RE = 16'h3d92; localparam W16_11_IM = 16'hbeae;
    localparam W16_12_RE = 16'h32c8; localparam W16_12_IM = 16'hb655;
    localparam W16_13_RE = 16'h2794; localparam W16_13_IM = 16'hadab;
    localparam W16_14_RE = 16'h1c0a; localparam W16_14_IM = 16'ha4c1;
    localparam W16_15_RE = 16'h103e; localparam W16_15_IM = 16'h9b49;

    always @(posedge clock) begin
        case (addr)
            4'h0: begin re <= W16_0_RE; im <= W16_0_IM; end
            4'h1: begin re <= W16_1_RE; im <= W16_1_IM; end
            4'h2: begin re <= W16_2_RE; im <= W16_2_IM; end
            4'h3: begin re <= W16_3_RE; im <= W16_3_IM; end
            4'h4: begin re <= W16_4_RE; im <= W16_4_IM; end
            4'h5: begin re <= W16_5_RE; im <= W16_5_IM; end
            4'h6: begin re <= W16_6_RE; im <= W16_6_IM; end
            4'h7: begin re <= W16_7_RE; im <= W16_7_IM; end
            4'h8: begin re <= W16_8_RE; im <= W16_8_IM; end
            4'h9: begin re <= W16_9_RE; im <= W16_9_IM; end
            4'ha: begin re <= W16_10_RE; im <= W16_10_IM; end
            4'hb: begin re <= W16_11_RE; im <= W16_11_IM; end
            4'hc: begin re <= W16_12_RE; im <= W16_12_IM; end
            4'hd: begin re <= W16_13_RE; im <= W16_13_IM; end
            4'he: begin re <= W16_14_RE; im <= W16_14_IM; end
            4'hf: begin re <= W16_15_RE; im <= W16_15_IM; end
            default: begin re <= 16'h0; im <= 16'h0; end
        endcase
    end

endmodule
