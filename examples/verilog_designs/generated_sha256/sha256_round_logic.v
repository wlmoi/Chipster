/*
 * Copyright (c) 2024 Your Name
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns / 1ps

/*
 * SHA-256 Round Combinational Logic
 *
 * This module implements the core combinational logic for a single
 * SHA-256 compression round.
 *
 * T1 = h + Sigma1(e) + Ch(e,f,g) + k[t] + w[t]
 * T2 = Sigma0(a) + Maj(a,b,c)
 * a' = T1 + T2
 * e' = d + T1
 */
module sha256_round_logic (
    // Inputs from working variable registers
    input  wire [31:0] a_in,
    input  wire [31:0] b_in,
    input  wire [31:0] c_in,
    input  wire [31:0] d_in,
    input  wire [31:0] e_in,
    input  wire [31:0] f_in,
    input  wire [31:0] g_in,
    input  wire [31:0] h_in,
    // Round constant and message schedule word
    input  wire [31:0] k_t,
    input  wire [31:0] w_t,

    // Outputs for next state of working variables
    output wire [31:0] a_out,
    output wire [31:0] b_out,
    output wire [31:0] c_out,
    output wire [31:0] d_out,
    output wire [31:0] e_out,
    output wire [31:0] f_out,
    output wire [31:0] g_out,
    output wire [31:0] h_out
);

    // Sigma0 = (a rotr 2) xor (a rotr 13) xor (a rotr 22)
    wire [31:0] sigma0 = ({a_in[1:0], a_in[31:2]}) ^ ({a_in[12:0], a_in[31:13]}) ^ ({a_in[21:0], a_in[31:22]});

    // Sigma1 = (e rotr 6) xor (e rotr 11) xor (e rotr 25)
    wire [31:0] sigma1 = ({e_in[5:0], e_in[31:6]}) ^ ({e_in[10:0], e_in[31:11]}) ^ ({e_in[24:0], e_in[31:25]});

    // Ch = (e and f) xor ((not e) and g)
    wire [31:0] ch = (e_in & f_in) ^ (~e_in & g_in);

    // Maj = (a and b) xor (a and c) xor (b and c)
    wire [31:0] maj = (a_in & b_in) ^ (a_in & c_in) ^ (b_in & c_in);

    // T1 = h + Sigma1 + Ch + k[t] + w[t]
    wire [31:0] t1 = h_in + sigma1 + ch + k_t + w_t;

    // T2 = Sigma0 + Maj
    wire [31:0] t2 = sigma0 + maj;

    // Next working variables
    assign a_out = t1 + t2;
    assign b_out = a_in;
    assign c_out = b_in;
    assign d_out = c_in;
    assign e_out = d_in + t1;
    assign f_out = e_in;
    assign g_out = f_in;
    assign h_out = g_in;

endmodule
