/*
 * Comprehensive testbench for the sha256 module.
 *
 * This testbench verifies the functionality of the SHA-256/224 core by running
 * several test cases with known answers from the FIPS 180-4 standard.
 *
 * Test Cases:
 * 1. SHA-256 with a single-block message ("abc").
 * 2. SHA-256 with a two-block message to test the 'next_i' functionality.
 * 3. SHA-224 with a single-block message to test the mode selection.
 */

`timescale 1ns / 1ps

module sha256_tb;

    // Parameters
    localparam CLK_PERIOD = 10; // 10ns clock period -> 100MHz

    // Testbench Signals
    reg                 clk;
    reg                 rst_n;
    reg                 init_i;
    reg                 next_i;
    reg                 sha256_mode_i; // 0: SHA-256, 1: SHA-224
    reg [511:0]         block_i;

    wire                ready_o;
    wire [255:0]        digest_o;
    wire                digest_valid_o;

    // Test tracking
    integer             error_count;

    // Instantiate the DUT
    sha256 uut (
        .clk            (clk),
        .rst_n          (rst_n),
        .init_i         (init_i),
        .next_i         (next_i),
        .sha256_mode_i  (sha256_mode_i),
        .block_i        (block_i),
        .ready_o        (ready_o),
        .digest_o       (digest_o),
        .digest_valid_o (digest_valid_o)
    );

    // Clock Generator
    always #(CLK_PERIOD / 2) clk = ~clk;

    // Monitor for debugging
    // This will print the state of key signals whenever they change.
    initial begin
        $monitor("T=%0t | rst_n=%b init=%b next=%b ready=%b digest_valid=%b | state=%s round=%d",
                 $time, rst_n, init_i, next_i, ready_o, digest_valid_o,
                 get_state_name(uut.state_reg), uut.round_ctr_reg);
    end

    // Helper function to get state name for monitor
    function [23:0] get_state_name(input [1:0] state);
        case(state)
            2'b00: get_state_name = "IDLE";
            2'b01: get_state_name = "HASH";
            2'b10: get_state_name = "DONE";
            default: get_state_name = "XXXX";
        endcase
    endfunction

    // Main test sequence
    initial begin
        $display("========================================================");
        $display("== Starting SHA-256 Core Testbench                  ==");
        $display("========================================================");

        // Initialize signals
        clk = 0;
        rst_n = 1;
        init_i = 0;
        next_i = 0;
        sha256_mode_i = 0;
        block_i = 512'd0;
        error_count = 0;

        // 1. Apply reset
        reset_dut();

        // 2. Test Case 1: SHA-256, single block message ("abc")
        run_test_sha256_abc();

        // 3. Test Case 2: SHA-256, two block message
        run_test_sha256_two_blocks();

        // 4. Test Case 3: SHA-224, single block message ("abc")
        run_test_sha224_abc();

        // 5. Final summary
        $display("========================================================");
        if (error_count == 0) begin
            $display("== ALL TESTS PASSED!                                ==");
        end else begin
            $display("== TESTS FAILED! Total errors: %0d                    ==", error_count);
        end
        $display("========================================================");
        $finish;
    end

    // Task to reset the DUT
    task reset_dut;
        begin
            $display("\n[TASK] Resetting DUT...");
            rst_n <= 0;
            #(CLK_PERIOD * 2);
            rst_n <= 1;
            #(CLK_PERIOD);
            $display("[TASK] Reset complete.");
        end
    endtask

    // Task for Test Case 1: SHA-256, "abc"
    task run_test_sha256_abc;
        reg [511:0] block_1;
        reg [255:0] expected_digest;
        begin
            $display("\n[TEST 1] SHA-256, single block message ('abc')");

            // Message "abc" is 0x616263. Length is 24 bits.
            // Padded block: 61626380 0...0 0...0 0...018
            block_1 = {
                8'h61, 8'h62, 8'h63, 8'h80, 416'd0, 64'd24
            };

            // Expected digest for "abc"
            expected_digest = 256'hba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad;

            // Apply first and only block
            apply_first_block(0, block_1); // Mode 0 for SHA-256

            // Wait for result and check
            check_digest(expected_digest, "SHA-256 ('abc')", 256);
        end
    endtask

    // Task for Test Case 2: SHA-256, two blocks
    task run_test_sha256_two_blocks;
        reg [511:0] block_1, block_2;
        reg [255:0] expected_digest;
        begin
            $display("\n[TEST 2] SHA-256, two block message");

            // Message: "abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq" (56 bytes)
            // Length = 56 bytes = 448 bits.
            block_1 = {
                8'h61, 8'h62, 8'h63, 8'h64, 8'h62, 8'h63, 8'h64, 8'h65,
                8'h63, 8'h64, 8'h65, 8'h66, 8'h64, 8'h65, 8'h66, 8'h67,
                8'h65, 8'h66, 8'h67, 8'h68, 8'h66, 8'h67, 8'h68, 8'h69,
                8'h67, 8'h68, 8'h69, 8'h6a, 8'h68, 8'h69, 8'h6a, 8'h6b,
                8'h69, 8'h6a, 8'h6b, 8'h6c, 8'h6a, 8'h6b, 8'h6c, 8'h6d,
                8'h6b, 8'h6c, 8'h6d, 8'h6e, 8'h6c, 8'h6d, 8'h6e, 8'h6f,
                8'h6d, 8'h6e, 8'h6f, 8'h70, 8'h6e, 8'h6f, 8'h70, 8'h71
            };

            // Padding block: 80...00...01C0 (length 448 = 0x1C0)
            block_2 = {
                8'h80, 440'd0, 64'd448
            };

            // Expected digest
            expected_digest = 256'h248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1;

            // Apply first block
            apply_first_block(0, block_1);

            // Apply second block
            apply_next_block(block_2);

            // Wait for final result and check
            check_digest(expected_digest, "SHA-256 (2-block)", 256);
        end
    endtask

    // Task for Test Case 3: SHA-224, "abc"
    task run_test_sha224_abc;
        reg [511:0] block_1;
        reg [255:0] expected_digest;
        begin
            $display("\n[TEST 3] SHA-224, single block message ('abc')");

            // Reset is important to load new IVs for SHA-224
            reset_dut();

            // Padded block is the same as Test 1
            block_1 = {
                8'h61, 8'h62, 8'h63, 8'h80, 416'd0, 64'd24
            };

            // Expected digest for "abc" (SHA-224)
            // The result is 224 bits, so we mask the lower 32 bits of the expected value.
            expected_digest = 256'h23097d223405d8228642a477bda255b32aadbce4bda0b3f7e36c9da700000000;

            // Apply first and only block
            apply_first_block(1, block_1); // Mode 1 for SHA-224

            // Wait for result and check (only 224 bits)
            check_digest(expected_digest, "SHA-224 ('abc')", 224);
        end
    endtask

    // Task to apply the first block of a message
    task apply_first_block(input mode, input [511:0] block);
        begin
            $display("  Applying first block (mode=%d)...", mode);
            wait (ready_o === 1);
            sha256_mode_i <= mode;
            block_i <= block;
            init_i <= 1;
            #(CLK_PERIOD);
            init_i <= 0;
            block_i <= 512'dx; // Avoid holding the bus
        end
    endtask

    // Task to apply a subsequent block of a message
    task apply_next_block(input [511:0] block);
        begin
            $display("  Applying next block...");
            wait (ready_o === 1);
            block_i <= block;
            next_i <= 1;
            #(CLK_PERIOD);
            next_i <= 0;
            block_i <= 512'dx; // Avoid holding the bus
        end
    endtask

    // Task to wait for the digest and check its value
    task check_digest(input [255:0] expected, input [127:0] test_name, input integer bits_to_check);
        reg [255:0] received_digest;
        reg [255:0] masked_expected;
        reg [255:0] masked_received;
        reg [255:0] mask;
        begin
            $display("  Waiting for digest...");
            wait (digest_valid_o === 1);
            #(1); // Let signals settle
            received_digest = digest_o;

            $display("  Digest valid received for test: %s", test_name);
            $display("    Expected: %h", expected);
            $display("    Received: %h", received_digest);

            if (bits_to_check == 224) begin
                // Mask to compare only the upper 224 bits
                mask = {{224{1'b1}}, {32{1'b0}}};
            end else begin
                mask = {256{1'b1}};
            end

            masked_expected = expected & mask;
            masked_received = received_digest & mask;

            if (masked_received === masked_expected) begin
                $display("  [PASS] Digest matches expected value.");
            end else begin
                $display("  [FAIL] Digest MISMATCH!");
                error_count = error_count + 1;
            end
        end
    endtask

endmodule
