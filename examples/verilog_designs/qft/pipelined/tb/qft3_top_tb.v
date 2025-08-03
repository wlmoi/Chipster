`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module qft3_top_tb;

    // Testbench signals
    reg clk;
    reg rst_n;
    reg valid_in;
    
    // Input state vector (|110> state)
    reg signed [`TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i;
    reg signed [`TOTAL_WIDTH-1:0] i010_r, i010_i, i011_r, i011_i;
    reg signed [`TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i;
    reg signed [`TOTAL_WIDTH-1:0] i110_r, i110_i, i111_r, i111_i;
    
    // Output state vector
    wire signed [`TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i;
    wire signed [`TOTAL_WIDTH-1:0] f010_r, f010_i, f011_r, f011_i;
    wire signed [`TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i;
    wire signed [`TOTAL_WIDTH-1:0] f110_r, f110_i, f111_r, f111_i;
    wire valid_out;
    
    // Expected results for |110> input
    // QFT(|110>) = (1/√8) * [1, -i, -1, i, 1, -i, -1, i]
    // In S3.4 fixed-point: (1/√8) ≈ 0.3536 ≈ 6/16
    localparam signed [`TOTAL_WIDTH-1:0] EXPECTED_REAL_POS = 6;   // +6 for positive real
    localparam signed [`TOTAL_WIDTH-1:0] EXPECTED_REAL_NEG = -6;  // -6 for negative real
    localparam signed [`TOTAL_WIDTH-1:0] EXPECTED_IMAG_POS = 6;   // +6 for positive imaginary
    localparam signed [`TOTAL_WIDTH-1:0] EXPECTED_IMAG_NEG = -6;  // -6 for negative imaginary
    localparam signed [`TOTAL_WIDTH-1:0] EXPECTED_ZERO = 0;       // 0 for zero components
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk; // 10ns period = 100MHz
    end
    
    // DUT instantiation
    qft3_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .valid_in(valid_in),
        .i000_r(i000_r), .i000_i(i000_i), .i001_r(i001_r), .i001_i(i001_i),
        .i010_r(i010_r), .i010_i(i010_i), .i011_r(i011_r), .i011_i(i011_i),
        .i100_r(i100_r), .i100_i(i100_i), .i101_r(i101_r), .i101_i(i101_i),
        .i110_r(i110_r), .i110_i(i110_i), .i111_r(i111_r), .i111_i(i111_i),
        .f000_r(f000_r), .f000_i(f000_i), .f001_r(f001_r), .f001_i(f001_i),
        .f010_r(f010_r), .f010_i(f010_i), .f011_r(f011_r), .f011_i(f011_i),
        .f100_r(f100_r), .f100_i(f100_i), .f101_r(f101_r), .f101_i(f101_i),
        .f110_r(f110_r), .f110_i(f110_i), .f111_r(f111_r), .f111_i(f111_i),
        .valid_out(valid_out)
    );
    
    // Test stimulus
    initial begin
        // Initialize all signals
        rst_n = 0;
        valid_in = 0;
        
        // Initialize input state vector to all zeros
        i000_r = 0; i000_i = 0; i001_r = 0; i001_i = 0;
        i010_r = 0; i010_i = 0; i011_r = 0; i011_i = 0;
        i100_r = 0; i100_i = 0; i101_r = 0; i101_i = 0;
        i110_r = 0; i110_i = 0; i111_r = 0; i111_i = 0;
        
        // Wait for a few clock cycles
        repeat(10) @(posedge clk);
        
        // Release reset
        rst_n = 1;
        @(posedge clk);
        
        $display("========================================");
        $display("QFT3 Pipelined Testbench Starting");
        $display("Testing with input state |110>");
        $display("========================================");
        
        // Set up |110> state (amplitude = 1.0 in S3.4 format = 16)
        i000_r = 0;  i000_i = 0;   // |000> amplitude = 0
        i001_r = 0;  i001_i = 0;   // |001> amplitude = 0
        i010_r = 0;  i010_i = 0;   // |010> amplitude = 0
        i011_r = 0;  i011_i = 0;   // |011> amplitude = 0
        i100_r = 0;  i100_i = 0;   // |100> amplitude = 0
        i101_r = 0;  i101_i = 0;   // |101> amplitude = 0
        i110_r = 16; i110_i = 0;   // |110> amplitude = 1.0 (S3.4: 16/16 = 1.0)
        i111_r = 0;  i111_i = 0;   // |111> amplitude = 0
        
        // Assert valid input
        valid_in = 1;
        @(posedge clk);
        valid_in = 0; // Single cycle input
        
        $display("Time: %0t - Input applied:", $time);
        $display("  |110> = (%.3f, %.3f)", $itor(i110_r)/16.0, $itor(i110_i)/16.0);
        
        // Wait for pipeline to complete (check for valid_out assertion)
        $display("Waiting for pipeline completion...");
        wait(valid_out == 1);
        @(posedge clk); // Sample outputs on next clock edge
        
        $display("\n========================================");
        $display("Pipeline completed at time: %0t", $time);
        $display("QFT3 Output Results:");
        $display("========================================");
        
        // Display results in both fixed-point and decimal
        $display("State |000>: (%3d, %3d) = (%.3f, %.3f)", 
                 f000_r, f000_i, $itor(f000_r)/16.0, $itor(f000_i)/16.0);
        $display("State |001>: (%3d, %3d) = (%.3f, %.3f)", 
                 f001_r, f001_i, $itor(f001_r)/16.0, $itor(f001_i)/16.0);
        $display("State |010>: (%3d, %3d) = (%.3f, %.3f)", 
                 f010_r, f010_i, $itor(f010_r)/16.0, $itor(f010_i)/16.0);
        $display("State |011>: (%3d, %3d) = (%.3f, %.3f)", 
                 f011_r, f011_i, $itor(f011_r)/16.0, $itor(f011_i)/16.0);
        $display("State |100>: (%3d, %3d) = (%.3f, %.3f)", 
                 f100_r, f100_i, $itor(f100_r)/16.0, $itor(f100_i)/16.0);
        $display("State |101>: (%3d, %3d) = (%.3f, %.3f)", 
                 f101_r, f101_i, $itor(f101_r)/16.0, $itor(f101_i)/16.0);
        $display("State |110>: (%3d, %3d) = (%.3f, %.3f)", 
                 f110_r, f110_i, $itor(f110_r)/16.0, $itor(f110_i)/16.0);
        $display("State |111>: (%3d, %3d) = (%.3f, %.3f)", 
                 f111_r, f111_i, $itor(f111_r)/16.0, $itor(f111_i)/16.0);
        
        $display("\n========================================");
        $display("Expected Results:");
        $display("========================================");
        $display("State |000>: ( %2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_REAL_POS, EXPECTED_ZERO, $itor(EXPECTED_REAL_POS)/16.0, $itor(EXPECTED_ZERO)/16.0);
        $display("State |001>: ( %2d, %2d) = (%.3f, %.3f)", 
                 EXPECTED_ZERO, EXPECTED_IMAG_NEG, $itor(EXPECTED_ZERO)/16.0, $itor(EXPECTED_IMAG_NEG)/16.0);
        $display("State |010>: (%2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_REAL_NEG, EXPECTED_ZERO, $itor(EXPECTED_REAL_NEG)/16.0, $itor(EXPECTED_ZERO)/16.0);
        $display("State |011>: ( %2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_ZERO, EXPECTED_IMAG_POS, $itor(EXPECTED_ZERO)/16.0, $itor(EXPECTED_IMAG_POS)/16.0);
        $display("State |100>: ( %2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_REAL_POS, EXPECTED_ZERO, $itor(EXPECTED_REAL_POS)/16.0, $itor(EXPECTED_ZERO)/16.0);
        $display("State |101>: ( %2d, %2d) = (%.3f, %.3f)", 
                 EXPECTED_ZERO, EXPECTED_IMAG_NEG, $itor(EXPECTED_ZERO)/16.0, $itor(EXPECTED_IMAG_NEG)/16.0);
        $display("State |110>: (%2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_REAL_NEG, EXPECTED_ZERO, $itor(EXPECTED_REAL_NEG)/16.0, $itor(EXPECTED_ZERO)/16.0);
        $display("State |111>: ( %2d,  %2d) = (%.3f, %.3f)", 
                 EXPECTED_ZERO, EXPECTED_IMAG_POS, $itor(EXPECTED_ZERO)/16.0, $itor(EXPECTED_IMAG_POS)/16.0);
        
        // Verification
        $display("\n========================================");
        $display("Verification Results:");
        $display("========================================");
        
        // Check each output with tolerance of ±1 due to fixed-point quantization
        check_result("|000>", f000_r, f000_i, EXPECTED_REAL_POS, EXPECTED_ZERO);
        check_result("|001>", f001_r, f001_i, EXPECTED_ZERO, EXPECTED_IMAG_NEG);
        check_result("|010>", f010_r, f010_i, EXPECTED_REAL_NEG, EXPECTED_ZERO);
        check_result("|011>", f011_r, f011_i, EXPECTED_ZERO, EXPECTED_IMAG_POS);
        check_result("|100>", f100_r, f100_i, EXPECTED_REAL_POS, EXPECTED_ZERO);
        check_result("|101>", f101_r, f101_i, EXPECTED_ZERO, EXPECTED_IMAG_NEG);
        check_result("|110>", f110_r, f110_i, EXPECTED_REAL_NEG, EXPECTED_ZERO);
        check_result("|111>", f111_r, f111_i, EXPECTED_ZERO, EXPECTED_IMAG_POS);
        
        // Test additional input: |000> state
        $display("\n========================================");
        $display("Testing with input state |000>");
        $display("========================================");
        
        @(posedge clk);
        
        // Set up |000> state
        i000_r = 16; i000_i = 0;   // |000> amplitude = 1.0
        i001_r = 0;  i001_i = 0;   // All others = 0
        i010_r = 0;  i010_i = 0;
        i011_r = 0;  i011_i = 0;
        i100_r = 0;  i100_i = 0;
        i101_r = 0;  i101_i = 0;
        i110_r = 0;  i110_i = 0;
        i111_r = 0;  i111_i = 0;
        
        valid_in = 1;
        @(posedge clk);
        valid_in = 0;
        
        // Wait for completion
        wait(valid_out == 1);
        @(posedge clk);
        
        $display("QFT3(|000>) Results:");
        $display("All amplitudes should be equal to 1/√8 ≈ 0.354 ≈ 6/16");
        $display("State |000>: (%3d, %3d) = (%.3f, %.3f)", 
                 f000_r, f000_i, $itor(f000_r)/16.0, $itor(f000_i)/16.0);
        $display("State |001>: (%3d, %3d) = (%.3f, %.3f)", 
                 f001_r, f001_i, $itor(f001_r)/16.0, $itor(f001_i)/16.0);
        $display("State |010>: (%3d, %3d) = (%.3f, %.3f)", 
                 f010_r, f010_i, $itor(f010_r)/16.0, $itor(f010_i)/16.0);
        $display("State |011>: (%3d, %3d) = (%.3f, %.3f)", 
                 f011_r, f011_i, $itor(f011_r)/16.0, $itor(f011_i)/16.0);
        $display("State |100>: (%3d, %3d) = (%.3f, %.3f)", 
                 f100_r, f100_i, $itor(f100_r)/16.0, $itor(f100_i)/16.0);
        $display("State |101>: (%3d, %3d) = (%.3f, %.3f)", 
                 f101_r, f101_i, $itor(f101_r)/16.0, $itor(f101_i)/16.0);
        $display("State |110>: (%3d, %3d) = (%.3f, %.3f)", 
                 f110_r, f110_i, $itor(f110_r)/16.0, $itor(f110_i)/16.0);
        $display("State |111>: (%3d, %3d) = (%.3f, %.3f)", 
                 f111_r, f111_i, $itor(f111_r)/16.0, $itor(f111_i)/16.0);
        
        // Wait a few more cycles
        repeat(10) @(posedge clk);
        
        $display("\n========================================");
        $display("Testbench completed successfully!");
        $display("========================================");
        
        $finish;
    end
    
    // Task to check results with tolerance
    task check_result;
        input [31:0] state_name;
        input signed [`TOTAL_WIDTH-1:0] actual_r, actual_i;
        input signed [`TOTAL_WIDTH-1:0] expected_r, expected_i;
        
        reg pass_r, pass_i;
        begin
            // Allow ±1 tolerance for fixed-point quantization errors
            pass_r = (actual_r >= (expected_r - 1)) && (actual_r <= (expected_r + 1));
            pass_i = (actual_i >= (expected_i - 1)) && (actual_i <= (expected_i + 1));
            
            if (pass_r && pass_i) begin
                $display("  %s: PASS ✓", state_name);
            end else begin
                $display("  %s: FAIL ✗ - Expected: (%2d,%2d), Got: (%2d,%2d)", 
                         state_name, expected_r, expected_i, actual_r, actual_i);
            end
        end
    endtask
    
    // Monitor for debugging (optional - can be commented out for cleaner output)
    /*
    initial begin
        $monitor("Time=%0t | rst_n=%b | valid_in=%b | valid_out=%b | Pipeline Status", 
                 $time, rst_n, valid_in, valid_out);
    end
    */
    
    // Generate VCD file for waveform viewing
    initial begin
        $dumpfile("qft3_tb.vcd");
        $dumpvars(0, qft3_top_tb);
    end

endmodule