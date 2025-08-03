`include "fixed_point_params.vh"

module h_gate(
    input  signed [`TOTAL_WIDTH-1:0] alpha_r, alpha_i,
    input  signed [`TOTAL_WIDTH-1:0] beta_r,  beta_i,
    output signed [`TOTAL_WIDTH-1:0] new_alpha_r, new_alpha_i,
    output signed [`TOTAL_WIDTH-1:0] new_beta_r,  new_beta_i
);
    // S3.4 constant for 1/sqrt(2) ~ 0.7071 => round(0.7071 * 16) = 11
    localparam signed [`TOTAL_WIDTH-1:0] ONE_OVER_SQRT2 = 11;

    wire signed [`ADD_WIDTH-1:0] add_r, add_i, sub_r, sub_i;

    // (alpha + beta) and (alpha - beta)
    cadd adder    (.ar(alpha_r), .ai(alpha_i), .br(beta_r), .bi(beta_i), .pr(add_r), .pi(add_i));
    cadd subtractor(.ar(alpha_r), .ai(alpha_i), .br(-beta_r),.bi(-beta_i),.pr(sub_r), .pi(sub_i));
    
    // Multiply by 1/sqrt(2).
    // Note: We truncate the adder's S4.4 output back to S3.4 before multiplying.
    ccmult mult_add(.ar(add_r), .ai(add_i), .br(ONE_OVER_SQRT2), .bi(0), .pr(new_alpha_r), .pi(new_alpha_i));
    ccmult mult_sub(.ar(sub_r), .ai(sub_i), .br(ONE_OVER_SQRT2), .bi(0), .pr(new_beta_r),  .pi(new_beta_i));

endmodule