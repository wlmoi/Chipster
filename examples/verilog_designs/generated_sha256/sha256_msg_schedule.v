/*
 * Copyright (c) 2024 Your Name
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns / 1ps

/*
 * SHA-256 Message Schedule Generator
 *
 * This module manages the 16-word (512-bit) message schedule buffer (W).
 * For the first 16 rounds (t=0 to 15), it provides W[t] directly from the
 * input message block.
 * For subsequent rounds (t=16 to 63), it calculates W[t] based on previous
 * words in the schedule:
 * W[t] = sigma1(W[t-2]) + W[t-7] + sigma0(W[t-15]) + W[t-16]
 *
 * The implementation uses a 16-word shift register.
 */
module sha256_msg_schedule (
    input wire          clk,
    input wire          rst_n,
    input wire          load_block_i, // Control signal to load a new block
    input wire          update_w_i,   // Control signal to shift and calculate next W
    input wire [511:0]  block_i,
    output wire [31:0]  w_t_current_o // W[t] for the current round
);

    reg [31:0] w_reg[0:15];

    // Message Schedule Expansion Logic
    // s0 = (w[t-15] rotr 7) xor (w[t-15] rotr 18) xor (w[t-15] shr 3)
    // s1 = (w[t-2] rotr 17) xor (w[t-2] rotr 19) xor (w[t-2] shr 10)
    // w[t] = w[t-16] + s0 + w[t-7] + s1
    wire [31:0] s0;
    wire [31:0] s1;
    wire [31:0] w_t_m15 = w_reg[1];  // Corresponds to w[t-15] after one shift
    wire [31:0] w_t_m2  = w_reg[14]; // Corresponds to w[t-2] after one shift
    wire [31:0] w_t_m16 = w_reg[0];  // Corresponds to w[t-16] after one shift
    wire [31:0] w_t_m7  = w_reg[9];  // Corresponds to w[t-7] after one shift
    wire [31:0] w_t_next;

    assign s0 = ({w_t_m15[6:0], w_t_m15[31:7]}) ^ ({w_t_m15[17:0], w_t_m15[31:18]}) ^ (w_t_m15 >> 3);
    assign s1 = ({w_t_m2[16:0], w_t_m2[31:17]}) ^ ({w_t_m2[18:0], w_t_m2[31:19]}) ^ (w_t_m2 >> 10);
    assign w_t_next = w_t_m16 + s0 + w_t_m7 + s1;

    // W register bank
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i = 0; i < 16; i = i + 1) begin
                w_reg[i] <= 32'd0;
            end
        end else if (load_block_i) begin
            // Load first 16 words from input block
            w_reg[0]  <= block_i[511:480]; w_reg[1]  <= block_i[479:448];
            w_reg[2]  <= block_i[447:416]; w_reg[3]  <= block_i[415:384];
            w_reg[4]  <= block_i[383:352]; w_reg[5]  <= block_i[351:320];
            w_reg[6]  <= block_i[319:288]; w_reg[7]  <= block_i[287:256];
            w_reg[8]  <= block_i[255:224]; w_reg[9]  <= block_i[223:192];
            w_reg[10] <= block_i[191:160]; w_reg[11] <= block_i[159:128];
            w_reg[12] <= block_i[127:96];  w_reg[13] <= block_i[95:64];
            w_reg[14] <= block_i[63:32];   w_reg[15] <= block_i[31:0];
        end else if (update_w_i) begin
            // Shift and calculate next W value for rounds 16-63
            w_reg[0]  <= w_reg[1];  w_reg[1]  <= w_reg[2];
            w_reg[2]  <= w_reg[3];  w_reg[3]  <= w_reg[4];
            w_reg[4]  <= w_reg[5];  w_reg[5]  <= w_reg[6];
            w_reg[6]  <= w_reg[7];  w_reg[7]  <= w_reg[8];
            w_reg[8]  <= w_reg[9];  w_reg[9]  <= w_reg[10];
            w_reg[10] <= w_reg[11]; w_reg[11] <= w_reg[12];
            w_reg[12] <= w_reg[13]; w_reg[13] <= w_reg[14];
            w_reg[14] <= w_reg[15]; w_reg[15] <= w_t_next;
        end
    end

    // Current message schedule word for round computation (W[t])
    // For rounds 0-15, this is the value loaded from the block.
    // For rounds 16-63, this is the value shifted in from the previous stage.
    assign w_t_current_o = w_reg[0];

endmodule
