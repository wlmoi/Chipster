`include "shared_header.vh"

// Pipelined Controlled-Rotation (CROT) Gate
// Latency: 11 cycles
module crot_gate(
    input  wire clk,
    input  wire rst_n,
    input  wire signed [`TOTAL_WIDTH-1:0] in_r, in_i,
    input  wire signed [`TOTAL_WIDTH-1:0] theta,
    output reg signed [`TOTAL_WIDTH-1:0] out_r, out_i
);
    // --- Wires ---
    wire signed [`TOTAL_WIDTH-1:0] cos_theta_w;
    wire signed [`TOTAL_WIDTH-1:0] sin_theta_w;

    // --- Pipeline Registers ---
    // Stage 1-5: Delay inputs to match sin/cos latency
    reg signed [`TOTAL_WIDTH-1:0] in_r_p5, in_i_p5;
    reg signed [`TOTAL_WIDTH-1:0] in_r_pipe[0:4], in_i_pipe[0:4];

    // Stage 6: Register sin/cos results
    reg signed [`TOTAL_WIDTH-1:0] cos_theta_p6, sin_theta_p6;

    // Stage 7: Multiplication results
    reg signed [`MULT_WIDTH-1:0] r_term1_p7, r_term2_p7, i_term1_p7, i_term2_p7;

    // Stage 8: Scaled multiplication results
    reg signed [`TOTAL_WIDTH-1:0] r_term1_s_p8, r_term2_s_p8, i_term1_s_p8, i_term2_s_p8;

    // Stage 9: Addition/Subtraction results
    reg signed [`ADD_WIDTH-1:0] out_r_p9, out_i_p9;
    
    // Stage 10 & 11: Final output registers
    reg signed [`ADD_WIDTH-1:0] out_r_p10, out_i_p10;

    // --- Instantiate sin/cos units (5 cycles latency) ---
    cosine_approx cos_unit ( .clk(clk), .rst_n(rst_n), .x(theta), .y(cos_theta_w) );
    sine_approx   sin_unit ( .clk(clk), .rst_n(rst_n), .x(theta), .y(sin_theta_w) );

    // --- Pipelined Logic ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all pipeline registers
            for (integer i=0; i<5; i=i+1) begin
                in_r_pipe[i] <= 0; in_i_pipe[i] <= 0;
            end
            in_r_p5 <= 0; in_i_p5 <= 0;
            cos_theta_p6 <= 0; sin_theta_p6 <= 0;
            r_term1_p7 <= 0; r_term2_p7 <= 0; i_term1_p7 <= 0; i_term2_p7 <= 0;
            r_term1_s_p8 <= 0; r_term2_s_p8 <= 0; i_term1_s_p8 <= 0; i_term2_s_p8 <= 0;
            out_r_p9 <= 0; out_i_p9 <= 0;
            out_r_p10 <= 0; out_i_p10 <= 0;
            out_r <= 0; out_i <= 0;
        end else begin
            // Stage 1-5: Input delay pipeline
            in_r_pipe[0] <= in_r;
            in_i_pipe[0] <= in_i;
            for (integer i=1; i<5; i=i+1) begin
                in_r_pipe[i] <= in_r_pipe[i-1];
                in_i_pipe[i] <= in_i_pipe[i-1];
            end
            in_r_p5 <= in_r_pipe[4];
            in_i_p5 <= in_i_pipe[4];

            // Stage 6: Latch sin/cos results (available after 5 cycles)
            cos_theta_p6 <= cos_theta_w;
            sin_theta_p6 <= sin_theta_w;

            // Stage 7: Perform multiplications
            r_term1_p7 <= in_r_p5 * cos_theta_p6; // in_r * cos
            r_term2_p7 <= in_i_p5 * sin_theta_p6; // in_i * sin
            i_term1_p7 <= in_r_p5 * sin_theta_p6; // in_r * sin
            i_term2_p7 <= in_i_p5 * cos_theta_p6; // in_i * cos

            // Stage 8: Scale multiplication results
            r_term1_s_p8 <= r_term1_p7 >>> `FRAC_WIDTH;
            r_term2_s_p8 <= r_term2_p7 >>> `FRAC_WIDTH;
            i_term1_s_p8 <= i_term1_p7 >>> `FRAC_WIDTH;
            i_term2_s_p8 <= i_term2_p7 >>> `FRAC_WIDTH;

            // Stage 9: Perform additions/subtractions
            out_r_p9 <= r_term1_s_p8 - r_term2_s_p8;
            out_i_p9 <= i_term1_s_p8 + i_term2_s_p8;

            // Stage 10: Register before final output
            out_r_p10 <= out_r_p9;
            out_i_p10 <= out_i_p9;
            
            // Stage 11: Latch into final output register (truncating)
            out_r <= out_r_p10[`TOTAL_WIDTH-1:0];
            out_i <= out_i_p10[`TOTAL_WIDTH-1:0];
        end
    end
endmodule
