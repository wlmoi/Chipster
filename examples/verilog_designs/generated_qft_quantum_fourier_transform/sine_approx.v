`include "shared_header.vh"

// Pipelined sine approximation: y = x - x^3/6
// Latency: 5 cycles
module sine_approx(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] x,      // Input angle (S3.4)
    output reg  signed [`TOTAL_WIDTH-1:0] y       // Output sin(x) (S3.4)
);
    // Pipeline registers
    reg signed [`TOTAL_WIDTH-1:0] x_p1, x_p2, x_p3, x_p4;
    reg signed [`MULT_WIDTH-1:0] x_sq_p2;
    reg signed [`TOTAL_WIDTH+`MULT_WIDTH-1:0] x_cubed_p3;
    reg signed [`TOTAL_WIDTH-1:0] x_cubed_div6_p4;

    // Constant for 1/6. In S0.7 format, round(0.1666 * 128) = 21.
    localparam C_INV_6_S0_7 = 7'd21;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            x_p1 <= 0; x_p2 <= 0; x_p3 <= 0; x_p4 <= 0;
            x_sq_p2 <= 0;
            x_cubed_p3 <= 0;
            x_cubed_div6_p4 <= 0;
            y <= 0;
        end else begin
            // P1: Register input and start delay chain for x
            x_p1 <= x;
            x_p2 <= x_p1;

            // P2: Calculate x^2. x(S3.4) * x(S3.4) -> x_sq(S6.8)
            x_sq_p2 <= x_p1 * x_p1;
            x_p3 <= x_p2;

            // P3: Calculate x^3. x_sq(S6.8) * x(S3.4) -> x_cubed(S9.12)
            x_cubed_p3 <= x_sq_p2 * x_p2;
            x_p4 <= x_p3;

            // P4: Calculate x^3/6 and scale to S3.4
            // x_cubed(S9.12) * C_INV_6(S0.7) -> S(9,19)
            // To scale to S3.4, shift right by (19-4)=15.
            x_cubed_div6_p4 <= (x_cubed_p3 * C_INV_6_S0_7) >>> 15;

            // P5: Subtract from x
            y <= x_p4 - x_cubed_div6_p4;
        end
    end
endmodule
