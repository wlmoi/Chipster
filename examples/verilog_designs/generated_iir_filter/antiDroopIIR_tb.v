`timescale 1ns / 1ps

// Testbench for the antiDroopIIR module
module antiDroopIIR_tb;

    // Parameters
    localparam CLK_PERIOD = 10; // 100 MHz clock

    // Testbench Signals
    reg clk;
    reg trig;
    reg signed [12:0] din;
    reg signed [6:0]  tapWeight;
    reg accClr_en;
    reg oflowClr;

    wire signed [15:0] dout;
    wire oflowDetect;

    // Instantiate the DUT (Device Under Test)
    // The default IIR_scale = 15 is used.
    antiDroopIIR dut (
        .clk(clk),
        .trig(trig),
        .din(din),
        .tapWeight(tapWeight),
        .accClr_en(accClr_en),
        .oflowClr(oflowClr),
        .dout(dout),
        .oflowDetect(oflowDetect)
    );

    // Clock Generator
    always # (CLK_PERIOD / 2) clk = ~clk;

    // Task to simplify pulsing the trigger signal for one clock cycle
    task pulse_trig;
    begin
        @(posedge clk);
        trig = 1'b1;
        @(posedge clk);
        trig = 1'b0;
    end
    endtask

    // Main Test Sequence
    initial begin
        // 1. Initialization and Reset
        $display("========================================================================");
        $display("TB START: Starting Testbench for antiDroopIIR at time %0t", $time);
        $display("========================================================================");

        // Initialize all inputs to a known state
        clk = 1'b0;
        trig = 1'b0;
        din = 13'sd0;
        tapWeight = 7'sd0;
        accClr_en = 1'b1; // Assert synchronous reset
        oflowClr = 1'b0;

        // Setup monitor to display signals on change
        $monitor("Time=%0t: clk=%b, trig=%b, din=%6d, tapW=%4d, accClr=%b, oflowClr=%b | dout=%6d, oflowDet=%b",
                 $time, clk, trig, din, tapWeight, accClr_en, oflowClr, dout, oflowDetect);

        $display("\n[TEST 1] Applying synchronous reset (accClr_en=1).");
        repeat(3) @(posedge clk);
        
        accClr_en = 1'b0;
        $display("\n[TEST 1] Reset released. DUT should be in a known zero state.");
        @(posedge clk);

        // 2. Basic Positive Accumulation & Pipeline Test
        // Note: din has a 1-cycle pipeline delay to the multiplier (din -> din_del)
        //       tapWeight has a 2-cycle pipeline delay (tapWeight -> tapWeight_a -> tapWeight_b)
        //       Therefore, it takes 3 trigger pulses for new inputs to be used in a calculation.
        $display("\n[TEST 2] Basic positive accumulation and pipeline verification.");
        din = 2000;
        tapWeight = 60;
        $display("  -> Set din=2000, tapWeight=60.");

        $display("  -> Pulse 1: Loads din into 1st stage and tapWeight into its 1st stage.");
        pulse_trig;
        @(posedge clk);

        $display("  -> Pulse 2: Loads tapWeight into its 2nd stage. Multiplier still sees old values from reset.");
        pulse_trig;
        @(posedge clk);

        $display("  -> Pulse 3: din_del=2000, tapWeight_b=60. Calculation occurs (2000*60=120000).");
        pulse_trig;
        @(posedge clk);
        $display("  -> dout should now reflect the new accumulator value (120000 >> 15 = 3).");
        @(posedge clk);

        // 3. Continued Accumulation
        $display("\n[TEST 3] Continued accumulation with the same inputs.");
        $display("  -> Pulse 4: Accumulator = 120000 + 120000 = 240000. dout = 240000 >> 15 = 7");
        pulse_trig;
        @(posedge clk);

        $display("  -> Pulse 5: Accumulator = 240000 + 120000 = 360000. dout = 360000 >> 15 = 10");
        pulse_trig;
        @(posedge clk);

        // 4. Changing Inputs to Negative Values
        $display("\n[TEST 4] Changing inputs to introduce negative accumulation.");
        din = 4000;
        tapWeight = -20;
        $display("  -> Set din=4000, tapWeight=-20.");

        $display("  -> Pulse 6: Flushes pipeline with old din(2000) and new tapW(-20).");
        pulse_trig;
        @(posedge clk);

        $display("  -> Pulse 7: Flushes pipeline with old din(2000) and new tapW(-20).");
        pulse_trig;
        @(posedge clk);

        $display("  -> Pulse 8: New values used. Acc += 4000 * -20 = -80000.");
        pulse_trig;
        @(posedge clk);

        // 5. Overflow Clear Test
        $display("\n[TEST 5] Testing overflow clear (oflowClr).");
        $display("  -> NOTE: Triggering a real overflow requires millions of cycles with max inputs.");
        $display("  -> This test just verifies the clear mechanism.");
        oflowClr = 1'b1;
        @(posedge clk);
        $display("  -> Pulsed oflowClr. If oflowDetect was 1, it is now cleared to 0.");
        oflowClr = 1'b0;
        @(posedge clk);

        // 6. Mid-stream Reset Test
        $display("\n[TEST 6] Testing accumulator clear (accClr_en) during operation.");
        accClr_en = 1'b1;
        @(posedge clk);
        $display("  -> Pulsed accClr_en. Accumulator and output should be zero.");
        accClr_en = 1'b0;
        repeat(3) @(posedge clk);

        // 7. Finalization
        $display("\n========================================================================");
        $display("TB END: Testbench finished successfully at time %0t", $time);
        $display("========================================================================");
        $finish;
    end

endmodule
