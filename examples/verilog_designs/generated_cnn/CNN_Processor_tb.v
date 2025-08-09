//////////////////////////////////////////////////////////////////////////////////
//
// Company: 
// Engineer: 
// 
// Create Date: 2023-10-27
// Design Name: CNN_Processor
// Module Name: CNN_Processor_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: A comprehensive testbench for the CNN_Processor module.
//
// This testbench performs the following steps:
// 1. Resets the DUT.
// 2. Loads a sample input image into the image RAM.
// 3. Loads a sample kernel and bias value into the kernel/bias memory.
// 4. Issues a 'start' command to begin the CNN computation.
// 5. Waits for the 'done' signal from the DUT.
// 6. Reads the resulting feature map from the output RAM.
// 7. Displays the results and terminates the simulation.
//
// Dependencies: shared_header.vh
//
//////////////////////////////////////////////////////////////////////////////////

`include "shared_header.vh"

module CNN_Processor_tb;

    // Testbench Parameters
    parameter CLK_PERIOD = 10; // Clock period in ns

    // DUT Interface Signals (SystemVerilog style)
    logic                                   clk;
    logic                                   rst_n;
    logic                                   start;
    logic [`IMG_ADDR_WIDTH-1:0]             wr_addr;
    logic [`DATA_WIDTH-1:0]                 data_in;
    logic                                   wr_en;
    logic                                   mem_select; // 0 for image, 1 for kernel/bias
    logic [`POOL_OUT_ADDR_WIDTH-1:0]        rd_addr;
    logic                                   done;
    logic [`DATA_WIDTH-1:0]                 data_out;

    // Instantiate the Device Under Test (DUT)
    CNN_Processor dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .done(done),
        .wr_addr(wr_addr),
        .data_in(data_in),
        .wr_en(wr_en),
        .mem_select(mem_select),
        .rd_addr(rd_addr),
        .data_out(data_out)
    );

    // Clock Generator
    always #((CLK_PERIOD)/2) clk = ~clk;

    // Main test sequence
    initial begin
        // CRITICAL: These two lines are required for waveform generation.
        $dumpfile("design.vcd");
        $dumpvars(0, CNN_Processor_tb);

        $display("\n[INFO] Starting CNN Processor Testbench");

        // 1. Initialize and Reset the DUT
        initialize_and_reset();

        // Monitor key signals after reset
        $monitor("[%0t] start: %b, done: %b, wr_en: %b, mem_select: %b, wr_addr: %d, rd_addr: %d, data_out: %d",
                 $time, start, done, wr_en, mem_select, wr_addr, rd_addr, data_out);

        // 2. Load test data (image, kernel, bias)
        load_test_data();

        // 3. Start computation and wait for it to complete
        start_and_wait_for_done();

        // 4. Read and display results
        read_and_display_results();

        // 5. Finish simulation
        $display("\n[INFO] Testbench finished successfully.");
        #CLK_PERIOD;
        $finish;
    end

    // Task to initialize signals and apply reset
    task automatic initialize_and_reset;
        clk = 1'b0;
        rst_n = 1'b0; // Assert active-low reset
        start = 1'b0;
        wr_addr = '0;
        data_in = '0;
        wr_en = 1'b0;
        mem_select = 1'b0;
        rd_addr = '0;

        $display("[%0t] Asserting reset.", $time);
        #(2 * CLK_PERIOD);
        rst_n = 1'b1; // De-assert reset
        $display("[%0t] De-asserting reset. DUT is in IDLE state.", $time);
        @(posedge clk);
    endtask

    // Task to load data into DUT memories
    task automatic load_test_data;
        // Task-local variables (SystemVerilog style)
        logic [`DATA_WIDTH-1:0]   test_image[`IMG_SIZE];
        logic [`WEIGHT_WIDTH-1:0] test_kernel[`KERNEL_AREA];
        logic signed [`BIAS_WIDTH-1:0] test_bias;

        // --- Create sample data ---
        // A simple ramp image
        for (int i = 0; i < `IMG_SIZE; i++) begin
            test_image[i] = i % 32; // Keep values small
        end

        // A simple 1.0 identity kernel (center is 1, rest are 0)
        for (int i = 0; i < `KERNEL_AREA; i++) begin
            test_kernel[i] = '0;
        end
        test_kernel[(`KERNEL_AREA-1)/2] = 1; // Center weight is 1

        // A small negative bias
        test_bias = -5;

        // --- Load Image ---
        $display("\n[%0t] Loading input image into DUT memory...", $time);
        mem_select = 1'b0; // Select image RAM
        wr_en = 1'b1;
        for (int i = 0; i < `IMG_SIZE; i++) begin
            wr_addr = i;
            data_in = test_image[i];
            @(posedge clk);
        end
        $display("[%0t] Image loading complete.", $time);

        // --- Load Kernel and Bias ---
        $display("\n[%0t] Loading kernel and bias into DUT memory...", $time);
        mem_select = 1'b1; // Select kernel/bias memory
        for (int i = 0; i < `KERNEL_AREA; i++) begin
            wr_addr = i;
            data_in = test_kernel[i];
            @(posedge clk);
        end
        // Load bias at the special address
        wr_addr = `KERNEL_AREA;
        data_in = test_bias;
        @(posedge clk);
        $display("[%0t] Kernel and bias loading complete.", $time);

        // De-assert write enable
        wr_en = 1'b0;
        wr_addr = '0;
        data_in = '0;
        @(posedge clk);
    endtask

    // Task to trigger the computation and wait for the done signal
    task automatic start_and_wait_for_done;
        $display("\n[%0t] Asserting 'start' to begin computation.", $time);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        $display("[%0t] Waiting for 'done' signal...", $time);
        @(posedge done);
        $display("[%0t] Computation 'done' signal received.", $time);
        @(posedge clk);
    endtask

    // Task to read the final results from the output RAM
    task automatic read_and_display_results;
        $display("\n[%0t] Reading final pooled feature map from output RAM:", $time);
        for (int i = 0; i < `POOL_OUT_AREA; i++) begin
            rd_addr = i;
            // Wait one cycle for the combinational read to propagate to the output
            @(posedge clk);
            $display("  Result @ Address %0d = %0d (0x%h)", i, data_out, data_out);
        end
        rd_addr = '0;
    endtask

endmodule
