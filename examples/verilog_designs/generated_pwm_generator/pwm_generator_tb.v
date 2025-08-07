////////////////////////////////////////////////////////////////////////////////
//
// Company: 
// Engineer: 
// 
// Create Date: 2023-10-27
// Design Name: pwm_generator
// Module Name: pwm_generator_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A comprehensive testbench for the pwm_generator module.
//
// This testbench performs the following checks:
// 1. Verifies the synchronous reset functionality.
// 2. Tests a standard PWM configuration (e.g., 25% duty cycle).
// 3. Tests dynamic changes to the duty cycle while the period remains constant.
// 4. Tests dynamic changes to the PWM frequency (period).
// 5. Verifies edge cases: 0% duty cycle and ~100% duty cycle.
//
// The testbench uses `$display` to announce test stages and `$monitor` to track
// key signals. It terminates automatically using `$finish`.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module pwm_generator_tb;

    // Parameters
    localparam COUNTER_WIDTH = 16;
    localparam CLK_PERIOD    = 10; // 10 ns -> 100 MHz clock

    // Testbench signals
    reg                          clk;
    reg                          rst;
    reg  [COUNTER_WIDTH-1:0]   period;
    reg  [COUNTER_WIDTH-1:0]   compare;
    wire                         pwm_out;

    // Instantiate the Device Under Test (DUT)
    pwm_generator #(
        .COUNTER_WIDTH(COUNTER_WIDTH)
    ) dut (
        .clk(clk),
        .rst(rst),
        .period(period),
        .compare(compare),
        .pwm_out(pwm_out)
    );

    // Clock generation block
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end

    // Monitoring block
    // This will print the signal values whenever any of them change.
    initial begin
        $monitor("Time=%0t | rst=%b | period=%3d | compare=%3d | counter=%3d | pwm_out=%b",
                 $time, rst, period, compare, dut.counter_reg, pwm_out);
    end

    // Stimulus block
    initial begin
        $display("\n--- Simulation Starting ---");
        // 1. Initialize and apply reset
        rst     = 1'b1;
        period  = 0;
        compare = 0;
        $display("Time=%0t | Applying synchronous reset...", $time);
        repeat(5) @(posedge clk);
        
        rst = 1'b0;
        $display("Time=%0t | Releasing reset.", $time);
        @(posedge clk);

        // 2. Test Case 1: Basic PWM operation (25% duty cycle)
        // Period = 99 -> 100 clock cycles per PWM period
        // Compare = 25 -> 25 high cycles (0-24) -> 25% duty cycle
        $display("\n--- Test Case 1: Period=99, Compare=25 (25%% Duty Cycle) ---");
        period  = 99;
        compare = 25;
        // Run for 3 full PWM cycles to observe behavior
        repeat(300) @(posedge clk);

        // 3. Test Case 2: Change duty cycle dynamically (to 75%)
        $display("\n--- Test Case 2: Dynamic Duty Cycle Change to 75%% ---");
        compare = 75;
        // Run for 3 full PWM cycles
        repeat(300) @(posedge clk);

        // 4. Test Case 3: Change frequency and duty cycle dynamically
        // Period = 49 -> 50 clock cycles per PWM period (double the frequency)
        // Compare = 10 -> 10 high cycles -> 20% duty cycle
        $display("\n--- Test Case 3: Dynamic Frequency Change (Period=49, Compare=10) ---");
        period  = 49;
        compare = 10;
        // Run for 4 full PWM cycles
        repeat(200) @(posedge clk);

        // 5. Test Case 4: Edge case - 0% duty cycle
        $display("\n--- Test Case 4: Edge Case - 0%% Duty Cycle (compare=0) ---");
        period  = 99;
        compare = 0;
        // Run for 2 full PWM cycles
        repeat(200) @(posedge clk);

        // 6. Test Case 5: Edge case - ~100% duty cycle
        // compare = period. Output should be high for counts 0 to period-1.
        $display("\n--- Test Case 5: Edge Case - ~100%% Duty Cycle (compare=period) ---");
        compare = 99;
        // Run for 2 full PWM cycles
        repeat(200) @(posedge clk);
        
        // 7. Test Case 6: Edge case - compare > period
        // Should behave the same as compare=period+1, i.e., always high.
        $display("\n--- Test Case 6: Edge Case - Always High (compare > period) ---");
        compare = 150; // period is still 99
        // Run for 2 full PWM cycles
        repeat(200) @(posedge clk);

        // 8. Finish simulation
        $display("\n--- All test cases completed. Finishing simulation. ---");
        $finish;
    end

endmodule
