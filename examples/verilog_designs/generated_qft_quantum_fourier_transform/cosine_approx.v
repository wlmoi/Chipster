`include "shared_header.vh"

// Pipelined cosine approximation: y = 1 - x^2/2
// Latency: 5 cycles
module cosine_approx(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] x,      // Input angle (S3.4)
    output reg  signed [`TOTAL_WIDTH-1:0] y       // Output cos(x) (S3.4)
);
    // Pipeline registers
    reg signed [`TOTAL_WIDTH-1:0] x_p1;
    reg signed [`MULT_WIDTH-1:0] x_sq_p2;
    reg signed [`MULT_WIDTH-1:0] x_sq_div2_p3;
    reg signed [`ADD_WIDTH-1:0]  result_p4;
    
    localparam ONE_S3_4 = 16; // 1.0 in S3.4 format

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_p1 <= 0;
            x_sq_p2 <= 0;
            x_sq_div2_p3 <= 0;
            result_p4 <= 0;
            y <= 0;
        end else begin
            // P1: Register input
            x_p1 <= x;
            // P2: Calculate x^2. x(S3.4) * x(S3.4) -> x_sq(S6.8)
            x_sq_p2 <= x_p1 * x_p1;
            // P3: Calculate x^2/2. x_sq(S6.8) / 2 -> S7.7
            x_sq_div2_p3 <= x_sq_p2 >>> 1;
            // P4: Subtract from 1. Align formats to S7.7
            // ONE(S3.4) -> ONE(S7.7) by shifting left by 3
            result_p4 <= (ONE_S3_4 <<< 3) - x_sq_div2_p3;
            // P5: Scale result back to S3.4 by shifting right by 3
            y <= result_p4 >>> 3;
        end
    end
endmodule
