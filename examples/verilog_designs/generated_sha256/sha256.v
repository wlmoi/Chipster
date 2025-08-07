
/*
 * Copyright (c) 2024 Your Name
 *
 * SPDX-License-Identifier: Apache-2.0
 */

`timescale 1ns / 1ps

/*
 * Top-level SHA-256 / SHA-224 Core
 *
 * This module implements the SHA-256 and SHA-224 hash functions as defined
 * in FIPS PUB 180-4. It processes one 512-bit message block at a time.
 * The core takes 65 clock cycles to process one block (1 cycle for setup,
 * 64 cycles for the compression rounds).
 *
 * This top-level module contains the main FSM, control logic, and datapath
 * registers. It instantiates sub-modules for the message schedule and
 * round computation logic.
 *
 * Interface:
 * - clk, rst_n: System clock and active-low reset.
 * - init_i: Pulse to start a new hash computation. This loads the initial
 *   hash values (IVs) for SHA-256 or SHA-224. The first message block
 *   `block_i` must be valid when `init_i` is high.
 * - next_i: Pulse to process a subsequent message block. The core uses the
 *   current hash digest as the IV for the next round. The next message
 *   block `block_i` must be valid when `next_i` is high.
 * - sha256_mode_i: Selects the hash algorithm. 0 for SHA-256, 1 for SHA-224.
 *   This should be set with the `init_i` pulse.
 * - block_i: The 512-bit message block to be processed.
 * - ready_o: High when the core is idle and ready to accept `init_i` or `next_i`.
 * - digest_o: The 256-bit hash result. For SHA-224, the upper 224 bits are
 *   the valid digest.
 * - digest_valid_o: A single-cycle pulse indicating that `digest_o` is valid.
 */
module sha256 (
    // System Signals
    input wire          clk,
    input wire          rst_n,

    // Control Interface
    input wire          init_i,         // Initialize and start hashing first block
    input wire          next_i,         // Start hashing next block
    input wire          sha256_mode_i,  // 0 for SHA-256, 1 for SHA-224

    // Data Interface
    input wire [511:0]  block_i,        // 512-bit message block

    // Status Interface
    output wire         ready_o,        // Core is ready for init_i or next_i
    output wire [255:0] digest_o,       // 256-bit hash digest
    output wire         digest_valid_o  // digest_o is valid for one cycle
);

    // FSM states
    localparam [1:0] STATE_IDLE = 2'b00;
    localparam [1:0] STATE_HASH = 2'b01;
    localparam [1:0] STATE_DONE = 2'b10;

    // SHA-256 Constants (K) - Implemented as a synthesizable ROM
    reg [31:0] K [0:63];
    initial begin
        K[ 0] = 32'h428a2f98; K[ 1] = 32'h71374491; K[ 2] = 32'hb5c0fbcf; K[ 3] = 32'he9b5dba5;
        K[ 4] = 32'h3956c25b; K[ 5] = 32'h59f111f1; K[ 6] = 32'h923f82a4; K[ 7] = 32'hab1c5ed5;
        K[ 8] = 32'hd807aa98; K[ 9] = 32'h12835b01; K[10] = 32'h243185be; K[11] = 32'h550c7dc3;
        K[12] = 32'h72be5d74; K[13] = 32'h80deb1fe; K[14] = 32'h9bdc06a7; K[15] = 32'hc19bf174;
        K[16] = 32'he49b69c1; K[17] = 32'hefbe4786; K[18] = 32'h0fc19dc6; K[19] = 32'h240ca1cc;
        K[20] = 32'h2de92c6f; K[21] = 32'h4a7484aa; K[22] = 32'h5cb0a9dc; K[23] = 32'h76f988da;
        K[24] = 32'h983e5152; K[25] = 32'ha831c66d; K[26] = 32'hb00327c8; K[27] = 32'hbf597fc7;
        K[28] = 32'hc6e00bf3; K[29] = 32'hd5a79147; K[30] = 32'h06ca6351; K[31] = 32'h14292967;
        K[32] = 32'h27b70a85; K[33] = 32'h2e1b2138; K[34] = 32'h4d2c6dfc; K[35] = 32'h53380d13;
        K[36] = 32'h650a7354; K[37] = 32'h766a0abb; K[38] = 32'h81c2c92e; K[39] = 32'h92722c85;
        K[40] = 32'ha2bfe8a1; K[41] = 32'ha81a664b; K[42] = 32'hc24b8b70; K[43] = 32'hc76c51a3;
        K[44] = 32'hd192e819; K[45] = 32'hd6990624; K[46] = 32'hf40e3585; K[47] = 32'h106aa070;
        K[48] = 32'h19a4c116; K[49] = 32'h1e376c08; K[50] = 32'h2748774c; K[51] = 32'h34b0bcb5;
        K[52] = 32'h391c0cb3; K[53] = 32'h4ed8aa4a; K[54] = 32'h5b9cca4f; K[55] = 32'h682e6ff3;
        K[56] = 32'h748f82ee; K[57] = 32'h78a5636f; K[58] = 32'h84c87814; K[59] = 32'h8cc70208;
        K[60] = 32'h90befffa; K[61] = 32'ha4506ceb; K[62] = 32'hbef9a3f7; K[63] = 32'hc67178f2;
    end

    // SHA-256 Initial Hash Values (H)
    localparam [255:0] SHA256_H0 = {
        32'h6a09e667, 32'hbb67ae85, 32'h3c6ef372, 32'ha54ff53a,
        32'h510e527f, 32'h9b05688c, 32'h1f83d9ab, 32'h5be0cd19
    };

    // SHA-224 Initial Hash Values (H)
    localparam [255:0] SHA224_H0 = {
        32'hc1059ed8, 32'h367cd507, 32'h3070dd17, 32'hf70e5939,
        32'hffc00b31, 32'h68581511, 32'h64f98fa7, 32'hbefa4fa4
    };

    // FSM and Control Registers
    reg [1:0]   state_reg, state_next;
    reg [5:0]   round_ctr_reg, round_ctr_next;
    reg         digest_valid_reg, digest_valid_next;

    // Datapath Registers
    reg [31:0]  H_reg[0:7];
    reg [31:0]  a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg;
    reg [255:0] digest_reg;

    // Wires for submodule connections
    wire [31:0] w_t_current;
    wire [31:0] a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next;
    wire [31:0] k_t;
    wire [31:0] H_new[0:7];

    // Control signals for submodules
    wire load_block = (state_reg == STATE_IDLE) && (init_i || next_i);
    wire update_w   = (state_reg == STATE_HASH);
    wire update_working_vars = (state_reg == STATE_HASH);
    wire load_working_vars_from_H = (state_reg == STATE_IDLE) && (init_i || next_i);
    wire update_H = (state_reg == STATE_DONE);

    // Instantiate Message Schedule
    sha256_msg_schedule u_msg_schedule (
        .clk            (clk),
        .rst_n          (rst_n),
        .load_block_i   (load_block),
        .update_w_i     (update_w),
        .block_i        (block_i),
        .w_t_current_o  (w_t_current)
    );

    // Round constant for current round
    assign k_t = K[round_ctr_reg];

    // Instantiate Round Logic
    sha256_round_logic u_round_logic (
        .a_in   (a_reg),
        .b_in   (b_reg),
        .c_in   (c_reg),
        .d_in   (d_reg),
        .e_in   (e_reg),
        .f_in   (f_reg),
        .g_in   (g_reg),
        .h_in   (h_reg),
        .k_t    (k_t),
        .w_t    (w_t_current),
        .a_out  (a_next),
        .b_out  (b_next),
        .c_out  (c_next),
        .d_out  (d_next),
        .e_out  (e_next),
        .f_out  (f_next),
        .g_out  (g_next),
        .h_out  (h_next)
    );

    // FSM sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= STATE_IDLE;
        end else begin
            state_reg <= state_next;
        end
    end

    // Control signals sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            round_ctr_reg <= 6'd0;
            digest_valid_reg <= 1'b0;
        end else begin
            round_ctr_reg <= round_ctr_next;
            digest_valid_reg <= digest_valid_next;
        end
    end

    // Output digest register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            digest_reg <= 256'd0;
        end else begin
            if (state_reg == STATE_DONE) begin
                digest_reg <= {H_new[0], H_new[1], H_new[2], H_new[3], H_new[4], H_new[5], H_new[6], H_new[7]};
            end
        end
    end

    // Datapath sequential logic
    always @(posedge clk) begin
        // Working variables a-h
        if (load_working_vars_from_H) begin
            if (init_i) begin
                if (sha256_mode_i) begin // SHA-224
                    {a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg} <= SHA224_H0;
                end else begin // SHA-256
                    {a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg} <= SHA256_H0;
                end
            end else begin // next_i
                {a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg} <= {H_reg[0], H_reg[1], H_reg[2], H_reg[3], H_reg[4], H_reg[5], H_reg[6], H_reg[7]};
            end
        end else if (update_working_vars) begin
            {a_reg, b_reg, c_reg, d_reg, e_reg, f_reg, g_reg, h_reg} <= {a_next, b_next, c_next, d_next, e_next, f_next, g_next, h_next};
        end

        // H registers
        if (init_i) begin
            if (sha256_mode_i) begin // SHA-224
                {H_reg[0], H_reg[1], H_reg[2], H_reg[3], H_reg[4], H_reg[5], H_reg[6], H_reg[7]} <= SHA224_H0;
            end else begin // SHA-256
                {H_reg[0], H_reg[1], H_reg[2], H_reg[3], H_reg[4], H_reg[5], H_reg[6], H_reg[7]} <= SHA256_H0;
            end
        end else if (update_H) begin
            {H_reg[0], H_reg[1], H_reg[2], H_reg[3], H_reg[4], H_reg[5], H_reg[6], H_reg[7]} <= {H_new[0], H_new[1], H_new[2], H_new[3], H_new[4], H_new[5], H_new[6], H_new[7]};
        end
    end

    // FSM and control logic (combinational)
    always @(*) begin
        state_next = state_reg;
        round_ctr_next = round_ctr_reg;
        digest_valid_next = 1'b0;

        case (state_reg)
            STATE_IDLE: begin
                if (init_i || next_i) begin
                    state_next = STATE_HASH;
                    round_ctr_next = 6'd0;
                end
            end
            STATE_HASH: begin
                if (round_ctr_reg == 6'd63) begin
                    state_next = STATE_DONE;
                end else begin
                    round_ctr_next = round_ctr_reg + 1;
                end
            end
            STATE_DONE: begin
                state_next = STATE_IDLE;
                digest_valid_next = 1'b1;
            end
            default: begin
                state_next = STATE_IDLE;
            end
        endcase
    end

    // Final hash value calculation (H(i) = H(i-1) + {a..h}_final)
    assign H_new[0] = H_reg[0] + a_reg;
    assign H_new[1] = H_reg[1] + b_reg;
    assign H_new[2] = H_reg[2] + c_reg;
    assign H_new[3] = H_reg[3] + d_reg;
    assign H_new[4] = H_reg[4] + e_reg;
    assign H_new[5] = H_reg[5] + f_reg;
    assign H_new[6] = H_reg[6] + g_reg;
    assign H_new[7] = H_reg[7] + h_reg;

    // Outputs
    assign ready_o        = (state_reg == STATE_IDLE);
    assign digest_valid_o = digest_valid_reg;
    assign digest_o       = digest_reg;

endmodule