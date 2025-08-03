`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// Corrected Top-level module for a 3-Qubit Quantum Fourier Transform
module qft3_top(
    // Initial 3-qubit state vector [α000, ..., α111]
    input  signed [`TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i,
    input  signed [`TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i,

    // Final state vector after the QFT
    output signed [`TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i, f010_r, f010_i, f011_r, f011_i,
    output signed [`TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i, f110_r, f110_i, f111_r, f111_i
);
    // --- Define Rotation Angles ---
    localparam THETA_PI_2 = 25;  // π/2 in S3.4 format
    localparam THETA_PI_4 = 13;  // π/4 in S3.4 format

    // --- Wires for data flow between stages ---
    wire signed [`TOTAL_WIDTH-1:0] s1_r[0:7], s1_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s2_r[0:7], s2_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s3_r[0:7], s3_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s4_r[0:7], s4_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s5_r[0:7], s5_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s6_r[0:7], s6_i[0:7];

    // --- STAGE 1: H on q2 (bit 2) ---
    // H gate acts on pairs where bit 2 differs: (000,100), (001,101), (010,110), (011,111)
    h_gate h_q2_p0 (.alpha_r(i000_r), .alpha_i(i000_i), .beta_r(i100_r), .beta_i(i100_i), 
                    .new_alpha_r(s1_r[0]), .new_alpha_i(s1_i[0]), .new_beta_r(s1_r[4]), .new_beta_i(s1_i[4]));
    h_gate h_q2_p1 (.alpha_r(i001_r), .alpha_i(i001_i), .beta_r(i101_r), .beta_i(i101_i), 
                    .new_alpha_r(s1_r[1]), .new_alpha_i(s1_i[1]), .new_beta_r(s1_r[5]), .new_beta_i(s1_i[5]));
    h_gate h_q2_p2 (.alpha_r(i010_r), .alpha_i(i010_i), .beta_r(i110_r), .beta_i(i110_i), 
                    .new_alpha_r(s1_r[2]), .new_alpha_i(s1_i[2]), .new_beta_r(s1_r[6]), .new_beta_i(s1_i[6]));
    h_gate h_q2_p3 (.alpha_r(i011_r), .alpha_i(i011_i), .beta_r(i111_r), .beta_i(i111_i), 
                    .new_alpha_r(s1_r[3]), .new_alpha_i(s1_i[3]), .new_beta_r(s1_r[7]), .new_beta_i(s1_i[7]));

    // --- STAGE 2: CROT(π/2) from q1 to q2 ---
    // Apply rotation only to states where q1=1 (bit 1 = 1): 010, 011, 110, 111 (indices 2,3,6,7)
    // But only those where q2=1 (bit 2 = 1): 110, 111 (indices 6,7)
    crot_gate c21_p0 (.in_r(s1_r[6]), .in_i(s1_i[6]), .theta(THETA_PI_2), .out_r(s2_r[6]), .out_i(s2_i[6]));
    crot_gate c21_p1 (.in_r(s1_r[7]), .in_i(s1_i[7]), .theta(THETA_PI_2), .out_r(s2_r[7]), .out_i(s2_i[7]));
    // Pass through unchanged amplitudes
    assign {s2_r[0],s2_i[0], s2_r[1],s2_i[1], s2_r[2],s2_i[2], s2_r[3],s2_i[3], s2_r[4],s2_i[4], s2_r[5],s2_i[5]} = 
           {s1_r[0],s1_i[0], s1_r[1],s1_i[1], s1_r[2],s1_i[2], s1_r[3],s1_i[3], s1_r[4],s1_i[4], s1_r[5],s1_i[5]};

    // --- STAGE 3: CROT(π/4) from q0 to q2 ---  
    // Apply rotation only to states where q0=1 (bit 0 = 1): 001, 011, 101, 111 (indices 1,3,5,7)
    // But only those where q2=1 (bit 2 = 1): 101, 111 (indices 5,7)
    crot_gate c20_p0 (.in_r(s2_r[5]), .in_i(s2_i[5]), .theta(THETA_PI_4), .out_r(s3_r[5]), .out_i(s3_i[5]));
    crot_gate c20_p1 (.in_r(s2_r[7]), .in_i(s2_i[7]), .theta(THETA_PI_4), .out_r(s3_r[7]), .out_i(s3_i[7]));
    // Pass through unchanged amplitudes
    assign {s3_r[0],s3_i[0], s3_r[1],s3_i[1], s3_r[2],s3_i[2], s3_r[3],s3_i[3], s3_r[4],s3_i[4], s3_r[6],s3_i[6]} = 
           {s2_r[0],s2_i[0], s2_r[1],s2_i[1], s2_r[2],s2_i[2], s2_r[3],s2_i[3], s2_r[4],s2_i[4], s2_r[6],s2_i[6]};

    // --- STAGE 4: H on q1 (bit 1) ---
    // H gate acts on pairs where bit 1 differs: (000,010), (001,011), (100,110), (101,111)
    h_gate h_q1_p0 (.alpha_r(s3_r[0]), .alpha_i(s3_i[0]), .beta_r(s3_r[2]), .beta_i(s3_i[2]), 
                    .new_alpha_r(s4_r[0]), .new_alpha_i(s4_i[0]), .new_beta_r(s4_r[2]), .new_beta_i(s4_i[2]));
    h_gate h_q1_p1 (.alpha_r(s3_r[1]), .alpha_i(s3_i[1]), .beta_r(s3_r[3]), .beta_i(s3_i[3]), 
                    .new_alpha_r(s4_r[1]), .new_alpha_i(s4_i[1]), .new_beta_r(s4_r[3]), .new_beta_i(s4_i[3]));
    h_gate h_q1_p2 (.alpha_r(s3_r[4]), .alpha_i(s3_i[4]), .beta_r(s3_r[6]), .beta_i(s3_i[6]), 
                    .new_alpha_r(s4_r[4]), .new_alpha_i(s4_i[4]), .new_beta_r(s4_r[6]), .new_beta_i(s4_i[6]));
    h_gate h_q1_p3 (.alpha_r(s3_r[5]), .alpha_i(s3_i[5]), .beta_r(s3_r[7]), .beta_i(s3_i[7]), 
                    .new_alpha_r(s4_r[5]), .new_alpha_i(s4_i[5]), .new_beta_r(s4_r[7]), .new_beta_i(s4_i[7]));

    // --- STAGE 5: CROT(π/2) from q0 to q1 ---
    // Apply rotation only to states where q0=1 (bit 0 = 1): 001, 011, 101, 111 (indices 1,3,5,7)
    // But only those where q1=1 (bit 1 = 1): 011, 111 (indices 3,7)
    crot_gate c10_p0 (.in_r(s4_r[3]), .in_i(s4_i[3]), .theta(THETA_PI_2), .out_r(s5_r[3]), .out_i(s5_i[3]));
    crot_gate c10_p1 (.in_r(s4_r[7]), .in_i(s4_i[7]), .theta(THETA_PI_2), .out_r(s5_r[7]), .out_i(s5_i[7]));
    // Pass through unchanged amplitudes  
    assign {s5_r[0],s5_i[0], s5_r[1],s5_i[1], s5_r[2],s5_i[2], s5_r[4],s5_i[4], s5_r[5],s5_i[5], s5_r[6],s5_i[6]} = 
           {s4_r[0],s4_i[0], s4_r[1],s4_i[1], s4_r[2],s4_i[2], s4_r[4],s4_i[4], s4_r[5],s4_i[5], s4_r[6],s4_i[6]};

    // --- STAGE 6: H on q0 (bit 0) ---
    // H gate acts on pairs where bit 0 differs: (000,001), (010,011), (100,101), (110,111)
    h_gate h_q0_p0 (.alpha_r(s5_r[0]), .alpha_i(s5_i[0]), .beta_r(s5_r[1]), .beta_i(s5_i[1]), 
                    .new_alpha_r(s6_r[0]), .new_alpha_i(s6_i[0]), .new_beta_r(s6_r[1]), .new_beta_i(s6_i[1]));
    h_gate h_q0_p1 (.alpha_r(s5_r[2]), .alpha_i(s5_i[2]), .beta_r(s5_r[3]), .beta_i(s5_i[3]), 
                    .new_alpha_r(s6_r[2]), .new_alpha_i(s6_i[2]), .new_beta_r(s6_r[3]), .new_beta_i(s6_i[3]));
    h_gate h_q0_p2 (.alpha_r(s5_r[4]), .alpha_i(s5_i[4]), .beta_r(s5_r[5]), .beta_i(s5_i[5]), 
                    .new_alpha_r(s6_r[4]), .new_alpha_i(s6_i[4]), .new_beta_r(s6_r[5]), .new_beta_i(s6_i[5]));
    h_gate h_q0_p3 (.alpha_r(s5_r[6]), .alpha_i(s5_i[6]), .beta_r(s5_r[7]), .beta_i(s5_i[7]), 
                    .new_alpha_r(s6_r[6]), .new_alpha_i(s6_i[6]), .new_beta_r(s6_r[7]), .new_beta_i(s6_i[7]));
    
    // --- STAGE 7: SWAP q0 and q2 ---
    // The bit reversal step swaps positions: 001↔100, 011↔110
    swap_gate final_swap (
        .in_001_r(s6_r[1]), .in_001_i(s6_i[1]), .in_100_r(s6_r[4]), .in_100_i(s6_i[4]),
        .in_011_r(s6_r[3]), .in_011_i(s6_i[3]), .in_110_r(s6_r[6]), .in_110_i(s6_i[6]),
        .out_001_r(f001_r), .out_001_i(f001_i),
        .out_100_r(f100_r), .out_100_i(f100_i),
        .out_011_r(f011_r), .out_011_i(f011_i),
        .out_110_r(f110_r), .out_110_i(f110_i)
    );
    
    // Pass through the amplitudes that are not affected by the swap
    assign {f000_r, f000_i} = {s6_r[0], s6_i[0]};
    assign {f010_r, f010_i} = {s6_r[2], s6_i[2]};
    assign {f101_r, f101_i} = {s6_r[5], s6_i[5]};
    assign {f111_r, f111_i} = {s6_r[7], s6_i[7]};

endmodule