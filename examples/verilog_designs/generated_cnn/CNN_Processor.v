// A generic CNN (Convolutional Neural Network) processor module.
// This module implements a single CNN layer consisting of:
// 1. 2D Convolution with a single kernel and bias.
// 2. ReLU (Rectified Linear Unit) activation.
// 3. 2D Max Pooling.
//
// The module is designed to be a hardware accelerator. Input image and kernel
// weights are first loaded into internal RAMs. A 'start' signal initiates the
// computation. When finished, a 'done' signal is asserted, and the resulting
// feature map can be read from the output RAM.

`include "shared_header.vh"

module CNN_Processor (
    input wire clk,
    input wire rst_n,

    // Control signals
    input wire start,
    output logic done,

    // Memory write interface for loading image, weights, and bias
    input wire [`IMG_ADDR_WIDTH-1:0] wr_addr,
    input wire [`DATA_WIDTH-1:0]     data_in,
    input wire                       wr_en,
    input wire                       mem_select, // 0 for image, 1 for kernel/bias

    // Memory read interface for reading results
    input wire [`POOL_OUT_ADDR_WIDTH-1:0] rd_addr,
    output logic [`DATA_WIDTH-1:0]        data_out
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE,
        CONV_ACCUM,
        CONV_STORE,
        POOL_FETCH,
        POOL_STORE,
        FINISH
    } state_t;

    state_t current_state, next_state;

    // Internal Memories
    logic [`DATA_WIDTH-1:0]   input_image[`IMG_SIZE-1:0];
    logic [`WEIGHT_WIDTH-1:0] kernel_weights[`KERNEL_AREA-1:0];
    logic signed [`BIAS_WIDTH-1:0] kernel_bias;
    logic [`DATA_WIDTH-1:0]   conv_feature_map[`CONV_OUT_AREA-1:0];
    logic [`DATA_WIDTH-1:0]   pooled_feature_map[`POOL_OUT_AREA-1:0];

    // Convolution process counters and registers
    logic [$clog2(`CONV_OUT_HEIGHT)-1:0] conv_y;
    logic [$clog2(`CONV_OUT_WIDTH)-1:0]  conv_x;
    logic [$clog2(`KERNEL_SIZE)-1:0]     ker_y;
    logic [$clog2(`KERNEL_SIZE)-1:0]     ker_x;
    logic signed [`ACCUM_WIDTH-1:0]      accumulator;

    // Pooling process counters and registers
    logic [$clog2(`POOL_OUT_HEIGHT)-1:0] pool_y;
    logic [$clog2(`POOL_OUT_WIDTH)-1:0]  pool_x;
    logic [$clog2(`POOL_SIZE)-1:0]       pool_win_y;
    logic [$clog2(`POOL_SIZE)-1:0]       pool_win_x;
    logic [`DATA_WIDTH-1:0]              max_val;

    //--------------------------------------------------------------------------
    // Memory Interfaces
    //--------------------------------------------------------------------------

    // Memory write logic for pre-loading data
    always_ff @(posedge clk) begin
        if (wr_en) begin
            if (mem_select == 1'b0) begin // Write to Image RAM
                if (wr_addr < `IMG_SIZE) begin
                    input_image[wr_addr] <= data_in;
                end
            end else begin // Write to Kernel/Bias RAM
                if (wr_addr < `KERNEL_AREA) begin
                    kernel_weights[wr_addr] <= data_in;
                end else if (wr_addr == `KERNEL_AREA) begin
                    // A specific address is used to load the bias
                    kernel_bias <= signed'(data_in);
                end
            end
        end
    end

    // Memory read logic for final output
    assign data_out = pooled_feature_map[rd_addr];

    //--------------------------------------------------------------------------
    // Control FSM
    //--------------------------------------------------------------------------

    // FSM state transitions
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // FSM combinational logic
    always_comb begin
        next_state = current_state;
        done = 1'b0;

        case (current_state)
            IDLE:
                if (start) next_state = CONV_ACCUM;

            CONV_ACCUM:
                if (ker_y == `KERNEL_SIZE-1 && ker_x == `KERNEL_SIZE-1)
                    next_state = CONV_STORE;

            CONV_STORE:
                if (conv_y == `CONV_OUT_HEIGHT-1 && conv_x == `CONV_OUT_WIDTH-1)
                    next_state = POOL_FETCH;
                else
                    next_state = CONV_ACCUM;

            POOL_FETCH:
                if (pool_win_y == `POOL_SIZE-1 && pool_win_x == `POOL_SIZE-1)
                    next_state = POOL_STORE;

            POOL_STORE:
                if (pool_y == `POOL_OUT_HEIGHT-1 && pool_x == `POOL_OUT_WIDTH-1)
                    next_state = FINISH;
                else
                    next_state = POOL_FETCH;

            FINISH: begin
                done = 1'b1;
                if (!start) // Wait for start to be de-asserted to go back to IDLE
                    next_state = IDLE;
            end

            default:
                next_state = IDLE;
        endcase
    end

    //--------------------------------------------------------------------------
    // Datapath and Computation Logic
    //--------------------------------------------------------------------------

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset counters and registers
            conv_y <= '0; conv_x <= '0; ker_y <= '0; ker_x <= '0;
            pool_y <= '0; pool_x <= '0; pool_win_y <= '0; pool_win_x <= '0;
            accumulator <= '0;
            max_val <= '0;

            // Optional: Clear memories on reset
            for (int i = 0; i < `CONV_OUT_AREA; i++) conv_feature_map[i] <= '0;
            for (int i = 0; i < `POOL_OUT_AREA; i++) pooled_feature_map[i] <= '0;
        end else begin
            case (current_state)
                IDLE: begin
                    if (start) begin
                        // Reset counters for a new run
                        conv_y <= '0; conv_x <= '0; ker_y <= '0; ker_x <= '0;
                        pool_y <= '0; pool_x <= '0; pool_win_y <= '0; pool_win_x <= '0;
                        accumulator <= '0;
                        max_val <= '0;
                    end
                end

                CONV_ACCUM: begin
                    // Calculate addresses for current MAC operation
                    automatic int input_y = conv_y + ker_y;
                    automatic int input_x = conv_x + ker_x;
                    automatic int input_addr = input_y * `IMG_WIDTH + input_x;
                    automatic int kernel_addr = ker_y * `KERNEL_SIZE + ker_x;

                    // Fetch data
                    automatic logic [`DATA_WIDTH-1:0] pixel_val = input_image[input_addr];
                    automatic logic [`WEIGHT_WIDTH-1:0] weight_val = kernel_weights[kernel_addr];
                    
                    // Multiply
                    automatic logic signed [`ACCUM_WIDTH-1:0] product = pixel_val * weight_val;

                    // Accumulate
                    if (ker_y == 0 && ker_x == 0) begin
                        // First element of the window, load accumulator with first product
                        accumulator <= product;
                    end else begin
                        accumulator <= accumulator + product;
                    end

                    // Update kernel window counters to scan the kernel
                    if (ker_x == `KERNEL_SIZE-1) begin
                        ker_x <= 0;
                        ker_y <= ker_y + 1;
                    end else begin
                        ker_x <= ker_x + 1;
                    end
                end

                CONV_STORE: begin
                    // Apply bias and ReLU activation
                    automatic logic signed [`ACCUM_WIDTH-1:0] conv_result = accumulator + kernel_bias;
                    automatic logic [`DATA_WIDTH-1:0] relu_result;
                    
                    if (conv_result < 0) begin
                        relu_result = 0;
                    end else if (conv_result > (2**`DATA_WIDTH - 1)) begin // Saturate to DATA_WIDTH
                        relu_result = {`DATA_WIDTH{1'b1}};
                    end else begin
                        relu_result = conv_result[`DATA_WIDTH-1:0];
                    end
                    
                    // Store result into the convolution feature map
                    automatic int conv_out_addr = conv_y * `CONV_OUT_WIDTH + conv_x;
                    conv_feature_map[conv_out_addr] <= relu_result;

                    // Reset kernel counters for the next output pixel
                    ker_y <= 0;
                    ker_x <= 0;

                    // Update output feature map counters
                    if (conv_x == `CONV_OUT_WIDTH-1) begin
                        conv_x <= 0;
                        conv_y <= conv_y + 1;
                    end else begin
                        conv_x <= conv_x + 1;
                    end
                end

                POOL_FETCH: begin
                    // Calculate address in conv_feature_map for the pooling window
                    automatic int conv_map_y = (pool_y * `POOL_SIZE) + pool_win_y;
                    automatic int conv_map_x = (pool_x * `POOL_SIZE) + pool_win_x;
                    automatic int conv_map_addr = conv_map_y * `CONV_OUT_WIDTH + conv_map_x;

                    // Fetch data
                    automatic logic [`DATA_WIDTH-1:0] pixel_val = conv_feature_map[conv_map_addr];

                    // On the first cycle of a new window, load max_val
                    if (pool_win_y == 0 && pool_win_x == 0) begin
                        max_val <= pixel_val;
                    end else begin
                        // Update max_val if current pixel is larger
                        if (pixel_val > max_val) begin
                            max_val <= pixel_val;
                        end
                    end

                    // Update pooling window counters
                    if (pool_win_x == `POOL_SIZE-1) begin
                        pool_win_x <= 0;
                        pool_win_y <= pool_win_y + 1;
                    end else begin
                        pool_win_x <= pool_win_x + 1;
                    end
                end

                POOL_STORE: begin
                    // Store the maximum value found in the window
                    automatic int pool_out_addr = pool_y * `POOL_OUT_WIDTH + pool_x;
                    pooled_feature_map[pool_out_addr] <= max_val;

                    // Reset pooling window counters for the next output pixel
                    pool_win_y <= 0;
                    pool_win_x <= 0;

                    // Update pooled map counters
                    if (pool_x == `POOL_OUT_WIDTH-1) begin
                        pool_x <= 0;
                        pool_y <= pool_y + 1;
                    end else begin
                        pool_x <= pool_x + 1;
                    end
                end

                FINISH: begin
                    // Computation is done. Hold state until 'start' is de-asserted.
                end
            endcase
        end
    end

endmodule
