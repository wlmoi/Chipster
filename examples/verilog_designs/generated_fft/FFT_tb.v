////////////////////////////////////////////////////////////////////////////////
//
// Module: FFT_tb
// Description: Testbench for a 64-point Radix-2^2 SDF FFT module.
//
// Test Strategy:
// 1.  Instantiate the FFT DUT.
// 2.  Generate a 100MHz clock signal.
// 3.  Apply a reset pulse at the beginning of the simulation.
// 4.  Generate a 64-point test signal. A real-valued cosine wave is used,
//     which should produce two impulses in the frequency domain.
//     - Signal: x[n] = A * cos(2*pi*k*n/N) for k=8, N=64.
//     - Amplitude A is chosen to be ~0.5 of the max signed value to avoid overflow.
// 5.  Feed the 64 input samples into the DUT, one per clock cycle.
// 6.  Monitor the DUT's output signals (`do_en`, `do_re`, `do_im`).
// 7.  When `do_en` is asserted, display the output sample number and its complex value.
// 8.  Count the number of valid output samples received.
// 9.  After all 64 output samples are received, print a success message and
//     terminate the simulation using `$finish`.
// 10. A timeout is included to prevent the simulation from running indefinitely.
//
////////////////////////////////////////////////////////////////////////////////

`timescale 1ns / 1ps

module FFT_tb;

    // Testbench Parameters
    localparam WIDTH      = 16;
    localparam N_LOG2     = 6;
    localparam N_POINTS   = 1 << N_LOG2; // 64
    localparam CLK_PERIOD = 10; // 100 MHz clock

    // Testbench Signals
    reg                       clock;
    reg                       reset;
    reg                       di_en;
    reg signed [WIDTH-1:0]    di_re;
    reg signed [WIDTH-1:0]    di_im;

    wire                      do_en;
    wire signed [WIDTH-1:0]   do_re;
    wire signed [WIDTH-1:0]   do_im;

    // Input data storage
    reg signed [WIDTH-1:0]    input_re[0:N_POINTS-1];
    reg signed [WIDTH-1:0]    input_im[0:N_POINTS-1];

    // Counters and stimulus variables
    integer i;
    integer output_count;
    integer k;
    real    A;
    real    PI;

    // Instantiate the Device Under Test (DUT)
    FFT #(
        .WIDTH(WIDTH),
        .N_LOG2(N_LOG2)
    ) dut (
        .clock(clock),
        .reset(reset),
        .di_en(di_en),
        .di_re(di_re),
        .di_im(di_im),
        .do_en(do_en),
        .do_re(do_re),
        .do_im(do_im)
    );

    // 1. Clock Generator
    initial begin
        clock = 0;
        forever #(CLK_PERIOD/2) clock = ~clock;
    end

    // 2. Stimulus Generation and Test Sequence
    initial begin
        // --- Test Start ---
        $display("========================================================");
        $display("== Testbench for 64-point FFT Started at T=%0t", $time);
        $display("== Stimulus: Real Cosine Wave at frequency bin 8");
        $display("========================================================");

        // Pre-calculate input stimulus
        // x[n] = A * cos(2*pi*k*n/N) for k=8, N=64
        // Amplitude is ~0.5 * (2^15-1) to prevent overflow after internal scaling.
        A = 16383.0;
        PI = 3.1415926535;
        k = 8; // Frequency bin
        for (i = 0; i < N_POINTS; i = i + 1) begin
            input_re[i] = $rtoi(A * $cos(2.0 * PI * k * i / N_POINTS));
            input_im[i] = 0;
        end

        // --- Reset Sequence ---
        reset = 1;
        di_en = 0;
        di_re = 0;
        di_im = 0;
        #(CLK_PERIOD * 5);
        reset = 0;
        @(posedge clock);
        $display("T=%0t: Reset de-asserted. Starting data input.", $time);

        // --- Send Input Data Frame ---
        for (i = 0; i < N_POINTS; i = i + 1) begin
            @(posedge clock);
            di_en = 1;
            di_re = input_re[i];
            di_im = input_im[i];
        end

        // --- Stop Sending Data ---
        @(posedge clock);
        di_en = 0;
        di_re = 0;
        di_im = 0;
        $display("T=%0t: Finished sending all %0d input samples.", $time, N_POINTS);
    end

    // 3. Output Monitoring and Test Termination
    initial begin
        output_count = 0;

        // Wait for reset to be done
        wait (reset == 0);

        $display("\n-------------------------------------------------------------------------");
        $display("Time(ns)\tOutput Index\tOutput Re\tOutput Im");
        $display("-------------------------------------------------------------------------");

        forever begin
            @(posedge clock);
            if (do_en) begin
                $display("%0t\t%0d\t\t%d\t\t%d", $time, output_count, do_re, do_im);
                output_count = output_count + 1;

                if (output_count == N_POINTS) begin
                    #(CLK_PERIOD * 2);
                    $display("\n========================================================");
                    $display("== Received all %0d output samples.", N_POINTS);
                    $display("== TEST PASSED (structurally). ");
                    $display("== For a real cosine at bin 8, expect large magnitude");
                    $display("== at bit-reversed output indices 4 (for bin 8) and");
                    $display("== 7 (for bin 56 = 64-8).");
                    $display("========================================================");
                    #(CLK_PERIOD * 10); // Wait a bit before finishing
                    $finish;
                end
            end
        end
    end

    // 4. Timeout to prevent simulation from running forever
    initial begin
        #(CLK_PERIOD * 5000); // Generous timeout
        $display("\n!!! TESTBENCH TIMEOUT !!!");
        $display("Did not receive all %d output samples in time.", N_POINTS);
        $display("Test FAILED.");
        $finish;
    end

endmodule
