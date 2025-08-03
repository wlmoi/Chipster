`include "fixed_point_params.vh"

module ccmult(
    input  signed [`TOTAL_WIDTH-1:0] ar, ai,
    input  signed [`TOTAL_WIDTH-1:0] br, bi,
    output signed [`TOTAL_WIDTH-1:0] pr, pi
);

    // Intermediate products are twice the width
    wire signed [`MULT_WIDTH-1:0] p_ar_br = ar * br;
    wire signed [`MULT_WIDTH-1:0] p_ai_bi = ai * bi;
    wire signed [`MULT_WIDTH-1:0] p_ar_bi = ar * bi;
    wire signed [`MULT_WIDTH-1:0] p_ai_br = ai * br;

    // Sum results are one bit wider than the products
    wire signed [`MULT_WIDTH:0] real_sum = p_ar_br - p_ai_bi;
    wire signed [`MULT_WIDTH:0] imag_sum = p_ar_bi + p_ai_br;
    
    // Scale the result back down using an arithmetic right shift.
    // This is the key step for fixed-point multiplication.
    assign pr = real_sum >>> `FRAC_WIDTH;
    assign pi = imag_sum >>> `FRAC_WIDTH;
    
endmodule