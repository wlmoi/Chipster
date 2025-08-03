`include "fixed_point_params.vh"

module cadd(
    input  signed [`TOTAL_WIDTH-1:0] ar, ai, // Input A
    input  signed [`TOTAL_WIDTH-1:0] br, bi, // Input B
    output signed [`ADD_WIDTH-1:0]   pr, pi  // Output P (wider to prevent overflow)
);

    assign pr = ar + br;
    assign pi = ai + bi;

endmodule