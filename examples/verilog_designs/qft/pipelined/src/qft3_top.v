`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// Pipelined Top-level module for a 3-Qubit Quantum Fourier Transform
// Total pipeline depth: approximately 30+ clock cycles
module qft3_top(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,  // Input valid signal
    
    // Initial 3-qubit state vector [α000, ..., α111]
    input  signed [`TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i,
    input  signed [`TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i,

    // Final state vector after the QFT
    output reg signed [`TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i, f010_r, f010_i, f011_r, f011_i,
    output reg signed [`TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i, f110_r, f110_i, f111_r, f111_i,
    output reg valid_out  // Output valid signal
);

    // --- Define Rotation Angles ---
    localparam THETA_PI_2 = 25;  // π/2 in S3.4 format
    localparam THETA_PI_4 = 13;  // π/4 in S3.4 format

    // --- Pipeline Stage Registers (changed from wire to reg) ---
    // Each stage needs multiple pipeline registers due to different gate delays
    
    // Stage 1: H on q2 (1 + 3 = 4 cycles for cadd + ccmult)
    reg signed [`TOTAL_WIDTH-1:0] s1_r[0:7], s1_i[0:7];
    
    // Stage 2: CROT(π/2) from q1 to q2 (4 + 7 = 11 cycles for trig + ccmult)  
    reg signed [`TOTAL_WIDTH-1:0] s2_r[0:7], s2_i[0:7];
    
    // Stage 3: CROT(π/4) from q0 to q2 (4 + 7 = 11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] s3_r[0:7], s3_i[0:7];
    
    // Stage 4: H on q1 (4 cycles)
    reg signed [`TOTAL_WIDTH-1:0] s4_r[0:7], s4_i[0:7];
    
    // Stage 5: CROT(π/2) from q0 to q1 (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] s5_r[0:7], s5_i[0:7];
    
    // Stage 6: H on q0 (4 cycles)
    reg signed [`TOTAL_WIDTH-1:0] s6_r[0:7], s6_i[0:7];
    
    // Stage 7: SWAP q0 and q2 (1 cycle)
    reg signed [`TOTAL_WIDTH-1:0] s7_r[0:7], s7_i[0:7];

    // Intermediate wires for gate outputs
    wire signed [`TOTAL_WIDTH-1:0] h_q2_out_r[0:7], h_q2_out_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] crot21_out_r[0:1], crot21_out_i[0:1];
    wire signed [`TOTAL_WIDTH-1:0] crot20_out_r[0:1], crot20_out_i[0:1];
    wire signed [`TOTAL_WIDTH-1:0] h_q1_out_r[0:7], h_q1_out_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] crot10_out_r[0:1], crot10_out_i[0:1];
    wire signed [`TOTAL_WIDTH-1:0] h_q0_out_r[0:7], h_q0_out_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] swap_out_r[0:3], swap_out_i[0:3];

    // Valid signal pipeline - track through all stages
    reg [31:0] valid_pipeline;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipeline <= 0;
            valid_out <= 0;
        end else begin
            valid_pipeline <= {valid_pipeline[30:0], valid_in};
            valid_out <= valid_pipeline[31]; // Adjust this based on actual total pipeline depth
        end
    end

    // --- STAGE 1: H on q2 (bit 2) ---
    h_gate h_q2_p0 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(i000_r), .alpha_i(i000_i), .beta_r(i100_r), .beta_i(i100_i), 
        .new_alpha_r(h_q2_out_r[0]), .new_alpha_i(h_q2_out_i[0]), .new_beta_r(h_q2_out_r[4]), .new_beta_i(h_q2_out_i[4])
    );
    h_gate h_q2_p1 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(i001_r), .alpha_i(i001_i), .beta_r(i101_r), .beta_i(i101_i), 
        .new_alpha_r(h_q2_out_r[1]), .new_alpha_i(h_q2_out_i[1]), .new_beta_r(h_q2_out_r[5]), .new_beta_i(h_q2_out_i[5])
    );
    h_gate h_q2_p2 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(i010_r), .alpha_i(i010_i), .beta_r(i110_r), .beta_i(i110_i), 
        .new_alpha_r(h_q2_out_r[2]), .new_alpha_i(h_q2_out_i[2]), .new_beta_r(h_q2_out_r[6]), .new_beta_i(h_q2_out_i[6])
    );
    h_gate h_q2_p3 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(i011_r), .alpha_i(i011_i), .beta_r(i111_r), .beta_i(i111_i), 
        .new_alpha_r(h_q2_out_r[3]), .new_alpha_i(h_q2_out_i[3]), .new_beta_r(h_q2_out_r[7]), .new_beta_i(h_q2_out_i[7])
    );

    // Stage 1 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s1_r[i] <= 0;
                s1_i[i] <= 0;
            end
        end else begin
            s1_r[0] <= h_q2_out_r[0]; s1_i[0] <= h_q2_out_i[0];
            s1_r[1] <= h_q2_out_r[1]; s1_i[1] <= h_q2_out_i[1];
            s1_r[2] <= h_q2_out_r[2]; s1_i[2] <= h_q2_out_i[2];
            s1_r[3] <= h_q2_out_r[3]; s1_i[3] <= h_q2_out_i[3];
            s1_r[4] <= h_q2_out_r[4]; s1_i[4] <= h_q2_out_i[4];
            s1_r[5] <= h_q2_out_r[5]; s1_i[5] <= h_q2_out_i[5];
            s1_r[6] <= h_q2_out_r[6]; s1_i[6] <= h_q2_out_i[6];
            s1_r[7] <= h_q2_out_r[7]; s1_i[7] <= h_q2_out_i[7];
        end
    end

    // --- STAGE 2: CROT(π/2) from q1 to q2 ---
    // Apply rotation only to states where q1=1 AND q2=1: indices 6,7
    crot_gate c21_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s1_r[6]), .in_i(s1_i[6]), .theta(THETA_PI_2), 
        .out_r(crot21_out_r[0]), .out_i(crot21_out_i[0])
    );
    crot_gate c21_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s1_r[7]), .in_i(s1_i[7]), .theta(THETA_PI_2), 
        .out_r(crot21_out_r[1]), .out_i(crot21_out_i[1])
    );
    
    // Delay non-rotated signals to match CROT delay (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage2[0:10][0:5][0:1]; // [delay][signal_index][real/imag]
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage2[d][i][0] <= 0;
                    delay_stage2[d][i][1] <= 0;
                end
            end
        end else begin
            // Input from stage 1
            delay_stage2[0][0][0] <= s1_r[0]; delay_stage2[0][0][1] <= s1_i[0];
            delay_stage2[0][1][0] <= s1_r[1]; delay_stage2[0][1][1] <= s1_i[1];
            delay_stage2[0][2][0] <= s1_r[2]; delay_stage2[0][2][1] <= s1_i[2];
            delay_stage2[0][3][0] <= s1_r[3]; delay_stage2[0][3][1] <= s1_i[3];
            delay_stage2[0][4][0] <= s1_r[4]; delay_stage2[0][4][1] <= s1_i[4];
            delay_stage2[0][5][0] <= s1_r[5]; delay_stage2[0][5][1] <= s1_i[5];
            
            // Pipeline delays
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage2[d][i][0] <= delay_stage2[d-1][i][0];
                    delay_stage2[d][i][1] <= delay_stage2[d-1][i][1];
                end
            end
        end
    end
    
    // Stage 2 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s2_r[i] <= 0;
                s2_i[i] <= 0;
            end
        end else begin
            s2_r[0] <= delay_stage2[10][0][0]; s2_i[0] <= delay_stage2[10][0][1];
            s2_r[1] <= delay_stage2[10][1][0]; s2_i[1] <= delay_stage2[10][1][1];
            s2_r[2] <= delay_stage2[10][2][0]; s2_i[2] <= delay_stage2[10][2][1];
            s2_r[3] <= delay_stage2[10][3][0]; s2_i[3] <= delay_stage2[10][3][1];
            s2_r[4] <= delay_stage2[10][4][0]; s2_i[4] <= delay_stage2[10][4][1];
            s2_r[5] <= delay_stage2[10][5][0]; s2_i[5] <= delay_stage2[10][5][1];
            s2_r[6] <= crot21_out_r[0]; s2_i[6] <= crot21_out_i[0];
            s2_r[7] <= crot21_out_r[1]; s2_i[7] <= crot21_out_i[1];
        end
    end

    // --- STAGE 3: CROT(π/4) from q0 to q2 ---  
    // Apply rotation only to states where q0=1 AND q2=1: indices 5,7
    crot_gate c20_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s2_r[5]), .in_i(s2_i[5]), .theta(THETA_PI_4), 
        .out_r(crot20_out_r[0]), .out_i(crot20_out_i[0])
    );
    crot_gate c20_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s2_r[7]), .in_i(s2_i[7]), .theta(THETA_PI_4), 
        .out_r(crot20_out_r[1]), .out_i(crot20_out_i[1])
    );
    
    // Delay non-rotated signals (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage3[0:10][0:5][0:1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage3[d][i][0] <= 0;
                    delay_stage3[d][i][1] <= 0;
                end
            end
        end else begin
            delay_stage3[0][0][0] <= s2_r[0]; delay_stage3[0][0][1] <= s2_i[0];
            delay_stage3[0][1][0] <= s2_r[1]; delay_stage3[0][1][1] <= s2_i[1];
            delay_stage3[0][2][0] <= s2_r[2]; delay_stage3[0][2][1] <= s2_i[2];
            delay_stage3[0][3][0] <= s2_r[3]; delay_stage3[0][3][1] <= s2_i[3];
            delay_stage3[0][4][0] <= s2_r[4]; delay_stage3[0][4][1] <= s2_i[4];
            delay_stage3[0][5][0] <= s2_r[6]; delay_stage3[0][5][1] <= s2_i[6];
            
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage3[d][i][0] <= delay_stage3[d-1][i][0];
                    delay_stage3[d][i][1] <= delay_stage3[d-1][i][1];
                end
            end
        end
    end
    
    // Stage 3 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s3_r[i] <= 0;
                s3_i[i] <= 0;
            end
        end else begin
            s3_r[0] <= delay_stage3[10][0][0]; s3_i[0] <= delay_stage3[10][0][1];
            s3_r[1] <= delay_stage3[10][1][0]; s3_i[1] <= delay_stage3[10][1][1];
            s3_r[2] <= delay_stage3[10][2][0]; s3_i[2] <= delay_stage3[10][2][1];
            s3_r[3] <= delay_stage3[10][3][0]; s3_i[3] <= delay_stage3[10][3][1];
            s3_r[4] <= delay_stage3[10][4][0]; s3_i[4] <= delay_stage3[10][4][1];
            s3_r[5] <= crot20_out_r[0]; s3_i[5] <= crot20_out_i[0];
            s3_r[6] <= delay_stage3[10][5][0]; s3_i[6] <= delay_stage3[10][5][1];
            s3_r[7] <= crot20_out_r[1]; s3_i[7] <= crot20_out_i[1];
        end
    end

    // --- STAGE 4: H on q1 (bit 1) ---
    h_gate h_q1_p0 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s3_r[0]), .alpha_i(s3_i[0]), .beta_r(s3_r[2]), .beta_i(s3_i[2]), 
        .new_alpha_r(h_q1_out_r[0]), .new_alpha_i(h_q1_out_i[0]), .new_beta_r(h_q1_out_r[2]), .new_beta_i(h_q1_out_i[2])
    );
    h_gate h_q1_p1 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s3_r[1]), .alpha_i(s3_i[1]), .beta_r(s3_r[3]), .beta_i(s3_i[3]), 
        .new_alpha_r(h_q1_out_r[1]), .new_alpha_i(h_q1_out_i[1]), .new_beta_r(h_q1_out_r[3]), .new_beta_i(h_q1_out_i[3])
    );
    h_gate h_q1_p2 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s3_r[4]), .alpha_i(s3_i[4]), .beta_r(s3_r[6]), .beta_i(s3_i[6]), 
        .new_alpha_r(h_q1_out_r[4]), .new_alpha_i(h_q1_out_i[4]), .new_beta_r(h_q1_out_r[6]), .new_beta_i(h_q1_out_i[6])
    );
    h_gate h_q1_p3 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s3_r[5]), .alpha_i(s3_i[5]), .beta_r(s3_r[7]), .beta_i(s3_i[7]), 
        .new_alpha_r(h_q1_out_r[5]), .new_alpha_i(h_q1_out_i[5]), .new_beta_r(h_q1_out_r[7]), .new_beta_i(h_q1_out_i[7])
    );

    // Stage 4 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s4_r[i] <= 0;
                s4_i[i] <= 0;
            end
        end else begin
            s4_r[0] <= h_q1_out_r[0]; s4_i[0] <= h_q1_out_i[0];
            s4_r[1] <= h_q1_out_r[1]; s4_i[1] <= h_q1_out_i[1];
            s4_r[2] <= h_q1_out_r[2]; s4_i[2] <= h_q1_out_i[2];
            s4_r[3] <= h_q1_out_r[3]; s4_i[3] <= h_q1_out_i[3];
            s4_r[4] <= h_q1_out_r[4]; s4_i[4] <= h_q1_out_i[4];
            s4_r[5] <= h_q1_out_r[5]; s4_i[5] <= h_q1_out_i[5];
            s4_r[6] <= h_q1_out_r[6]; s4_i[6] <= h_q1_out_i[6];
            s4_r[7] <= h_q1_out_r[7]; s4_i[7] <= h_q1_out_i[7];
        end
    end

    // --- STAGE 5: CROT(π/2) from q0 to q1 ---
    // Apply rotation only to states where q0=1 AND q1=1: indices 3,7
    crot_gate c10_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s4_r[3]), .in_i(s4_i[3]), .theta(THETA_PI_2), 
        .out_r(crot10_out_r[0]), .out_i(crot10_out_i[0])
    );
    crot_gate c10_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s4_r[7]), .in_i(s4_i[7]), .theta(THETA_PI_2), 
        .out_r(crot10_out_r[1]), .out_i(crot10_out_i[1])
    );
    
    // Delay non-rotated signals (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage5[0:10][0:5][0:1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage5[d][i][0] <= 0;
                    delay_stage5[d][i][1] <= 0;
                end
            end
        end else begin
            delay_stage5[0][0][0] <= s4_r[0]; delay_stage5[0][0][1] <= s4_i[0];
            delay_stage5[0][1][0] <= s4_r[1]; delay_stage5[0][1][1] <= s4_i[1];
            delay_stage5[0][2][0] <= s4_r[2]; delay_stage5[0][2][1] <= s4_i[2];
            delay_stage5[0][3][0] <= s4_r[4]; delay_stage5[0][3][1] <= s4_i[4];
            delay_stage5[0][4][0] <= s4_r[5]; delay_stage5[0][4][1] <= s4_i[5];
            delay_stage5[0][5][0] <= s4_r[6]; delay_stage5[0][5][1] <= s4_i[6];
            
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage5[d][i][0] <= delay_stage5[d-1][i][0];
                    delay_stage5[d][i][1] <= delay_stage5[d-1][i][1];
                end
            end
        end
    end
    
    // Stage 5 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s5_r[i] <= 0;
                s5_i[i] <= 0;
            end
        end else begin
            s5_r[0] <= delay_stage5[10][0][0]; s5_i[0] <= delay_stage5[10][0][1];
            s5_r[1] <= delay_stage5[10][1][0]; s5_i[1] <= delay_stage5[10][1][1];
            s5_r[2] <= delay_stage5[10][2][0]; s5_i[2] <= delay_stage5[10][2][1];
            s5_r[3] <= crot10_out_r[0]; s5_i[3] <= crot10_out_i[0];
            s5_r[4] <= delay_stage5[10][3][0]; s5_i[4] <= delay_stage5[10][3][1];
            s5_r[5] <= delay_stage5[10][4][0]; s5_i[5] <= delay_stage5[10][4][1];
            s5_r[6] <= delay_stage5[10][5][0]; s5_i[6] <= delay_stage5[10][5][1];
            s5_r[7] <= crot10_out_r[1]; s5_i[7] <= crot10_out_i[1];
        end
    end

    // --- STAGE 6: H on q0 (bit 0) ---
    h_gate h_q0_p0 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s5_r[0]), .alpha_i(s5_i[0]), .beta_r(s5_r[1]), .beta_i(s5_i[1]), 
        .new_alpha_r(h_q0_out_r[0]), .new_alpha_i(h_q0_out_i[0]), .new_beta_r(h_q0_out_r[1]), .new_beta_i(h_q0_out_i[1])
    );
    h_gate h_q0_p1 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s5_r[2]), .alpha_i(s5_i[2]), .beta_r(s5_r[3]), .beta_i(s5_i[3]), 
        .new_alpha_r(h_q0_out_r[2]), .new_alpha_i(h_q0_out_i[2]), .new_beta_r(h_q0_out_r[3]), .new_beta_i(h_q0_out_i[3])
    );
    h_gate h_q0_p2 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s5_r[4]), .alpha_i(s5_i[4]), .beta_r(s5_r[5]), .beta_i(s5_i[5]), 
        .new_alpha_r(h_q0_out_r[4]), .new_alpha_i(h_q0_out_i[4]), .new_beta_r(h_q0_out_r[5]), .new_beta_i(h_q0_out_i[5])
    );
    h_gate h_q0_p3 (
        .clk(clk), .rst_n(rst_n),
        .alpha_r(s5_r[6]), .alpha_i(s5_i[6]), .beta_r(s5_r[7]), .beta_i(s5_i[7]), 
        .new_alpha_r(h_q0_out_r[6]), .new_alpha_i(h_q0_out_i[6]), .new_beta_r(h_q0_out_r[7]), .new_beta_i(h_q0_out_i[7])
    );

    // Stage 6 output assignment
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s6_r[i] <= 0;
                s6_i[i] <= 0;
            end
        end else begin
            s6_r[0] <= h_q0_out_r[0]; s6_i[0] <= h_q0_out_i[0];
            s6_r[1] <= h_q0_out_r[1]; s6_i[1] <= h_q0_out_i[1];
            s6_r[2] <= h_q0_out_r[2]; s6_i[2] <= h_q0_out_i[2];
            s6_r[3] <= h_q0_out_r[3]; s6_i[3] <= h_q0_out_i[3];
            s6_r[4] <= h_q0_out_r[4]; s6_i[4] <= h_q0_out_i[4];
            s6_r[5] <= h_q0_out_r[5]; s6_i[5] <= h_q0_out_i[5];
            s6_r[6] <= h_q0_out_r[6]; s6_i[6] <= h_q0_out_i[6];
            s6_r[7] <= h_q0_out_r[7]; s6_i[7] <= h_q0_out_i[7];
        end
    end
    
    // --- STAGE 7: SWAP q0 and q2 ---
    swap_gate final_swap (
        .clk(clk), .rst_n(rst_n),
        .in_001_r(s6_r[1]), .in_001_i(s6_i[1]), .in_100_r(s6_r[4]), .in_100_i(s6_i[4]),
        .in_011_r(s6_r[3]), .in_011_i(s6_i[3]), .in_110_r(s6_r[6]), .in_110_i(s6_i[6]),
        .out_001_r(swap_out_r[0]), .out_001_i(swap_out_i[0]),
        .out_100_r(swap_out_r[1]), .out_100_i(swap_out_i[1]),
        .out_011_r(swap_out_r[2]), .out_011_i(swap_out_i[2]),
        .out_110_r(swap_out_r[3]), .out_110_i(swap_out_i[3])
    );
    
    // Stage 7 output assignment (SWAP + delay non-swapped signals by 1 cycle)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 8; i = i + 1) begin
                s7_r[i] <= 0;
                s7_i[i] <= 0;
            end
        end else begin
            // Non-swapped signals (delayed by 1 cycle)
            s7_r[0] <= s6_r[0]; s7_i[0] <= s6_i[0];
            s7_r[2] <= s6_r[2]; s7_i[2] <= s6_i[2];
            s7_r[5] <= s6_r[5]; s7_i[5] <= s6_i[5];
            s7_r[7] <= s6_r[7]; s7_i[7] <= s6_i[7];
            
            // Swapped signals from swap_gate output
            s7_r[1] <= swap_out_r[0]; s7_i[1] <= swap_out_i[0]; // 001
            s7_r[4] <= swap_out_r[1]; s7_i[4] <= swap_out_i[1]; // 100
            s7_r[3] <= swap_out_r[2]; s7_i[3] <= swap_out_i[2]; // 011
            s7_r[6] <= swap_out_r[3]; s7_i[6] <= swap_out_i[3]; // 110
        end
    end
    
    // --- Final Output Assignment ---
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f000_r <= 0; f000_i <= 0; f001_r <= 0; f001_i <= 0;
            f010_r <= 0; f010_i <= 0; f011_r <= 0; f011_i <= 0;
            f100_r <= 0; f100_i <= 0; f101_r <= 0; f101_i <= 0;
            f110_r <= 0; f110_i <= 0; f111_r <= 0; f111_i <= 0;
        end else begin
            f000_r <= s7_r[0]; f000_i <= s7_i[0];
            f001_r <= s7_r[1]; f001_i <= s7_i[1];
            f010_r <= s7_r[2]; f010_i <= s7_i[2];
            f011_r <= s7_r[3]; f011_i <= s7_i[3];
            f100_r <= s7_r[4]; f100_i <= s7_i[4];
            f101_r <= s7_r[5]; f101_i <= s7_i[5];
            f110_r <= s7_r[6]; f110_i <= s7_i[6];
            f111_r <= s7_r[7]; f111_i <= s7_i[7];
        end
    end

endmodule