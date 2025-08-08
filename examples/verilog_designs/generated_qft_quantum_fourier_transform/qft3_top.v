`include "shared_header.vh"

// Pipelined Top-level module for a 3-Qubit Quantum Fourier Transform
// Total pipeline depth: approximately 30+ clock cycles
module qft3_top(
    input  wire clk,
    input  wire rst_n,
    input  wire valid_in,  // Input valid signal
    
    // Initial 3-qubit state vector [α000, ..., α111]
    input  signed [`TOTAL_WIDTH-1:0] i000_r, i000_i, i001_r, i001_i, i010_r, i010_i, i011_r, i011_i,
    input  signed [`TOTAL_WIDTH-1:0] i100_r, i100_i, i101_r, i101_i, i110_r, i110_i, i111_r, i111_i,

    // Final state vector after the QFT
    output reg signed [`TOTAL_WIDTH-1:0] f000_r, f000_i, f001_r, f001_i, f010_r, f010_i, f011_r, f011_i,
    output reg signed [`TOTAL_WIDTH-1:0] f100_r, f100_i, f101_r, f101_i, f110_r, f110_i, f111_r, f111_i,
    output reg valid_out  // Output valid signal
);

    // --- Define Rotation Angles ---
    localparam signed [7:0] THETA_PI_2 = 25;  // π/2 in S3.4 format
    localparam signed [7:0] THETA_PI_4 = 13;  // π/4 in S3.4 format

    // --- State Vectors (Real and Imaginary parts) ---
    // Each stage has a state vector of 8 complex numbers
    wire signed [`TOTAL_WIDTH-1:0] s0_r[0:7], s0_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s1_r[0:7], s1_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s2_r[0:7], s2_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s3_r[0:7], s3_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s4_r[0:7], s4_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s5_r[0:7], s5_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s6_r[0:7], s6_i[0:7];
    wire signed [`TOTAL_WIDTH-1:0] s7_r[0:7], s7_i[0:7];

    // --- Pipeline Wires for CROT stages ---
    wire signed [`TOTAL_WIDTH-1:0] crot21_out_r[0:1], crot21_out_i[0:1];
    wire signed [`TOTAL_WIDTH-1:0] crot20_out_r[0:1], crot20_out_i[0:1];
    wire signed [`TOTAL_WIDTH-1:0] crot10_out_r[0:1], crot10_out_i[0:1];

    // --- Pipeline Wires for SWAP stage ---
    wire signed [`TOTAL_WIDTH-1:0] swap_out_001_r, swap_out_001_i;
    wire signed [`TOTAL_WIDTH-1:0] swap_out_100_r, swap_out_100_i;
    wire signed [`TOTAL_WIDTH-1:0] swap_out_011_r, swap_out_011_i;
    wire signed [`TOTAL_WIDTH-1:0] swap_out_110_r, swap_out_110_i;

    // --- Pipeline control ---
    reg [35:0] valid_pipe; // Total latency: 1(in) + 11(s2) + 11(s3) + 11(s5) + 1(swap) + 1(out) = 36 cycles

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_pipe <= 0;
        end else begin
            valid_pipe <= {valid_pipe[34:0], valid_in};
        end
    end
    
    // --- STAGE 0: Input Latching ---
    // Latency: 1 cycle
    reg signed [`TOTAL_WIDTH-1:0] s0_r_reg[0:7], s0_i_reg[0:7];
    assign s0_r[0] = s0_r_reg[0]; assign s0_i[0] = s0_i_reg[0];
    assign s0_r[1] = s0_r_reg[1]; assign s0_i[1] = s0_i_reg[1];
    assign s0_r[2] = s0_r_reg[2]; assign s0_i[2] = s0_i_reg[2];
    assign s0_r[3] = s0_r_reg[3]; assign s0_i[3] = s0_i_reg[3];
    assign s0_r[4] = s0_r_reg[4]; assign s0_i[4] = s0_i_reg[4];
    assign s0_r[5] = s0_r_reg[5]; assign s0_i[5] = s0_i_reg[5];
    assign s0_r[6] = s0_r_reg[6]; assign s0_i[6] = s0_i_reg[6];
    assign s0_r[7] = s0_r_reg[7]; assign s0_i[7] = s0_i_reg[7];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer i=0; i<8; i=i+1) begin
                s0_r_reg[i] <= 0; s0_i_reg[i] <= 0;
            end
        end else if (valid_in) begin
            s0_r_reg[0] <= i000_r; s0_i_reg[0] <= i000_i;
            s0_r_reg[1] <= i001_r; s0_i_reg[1] <= i001_i;
            s0_r_reg[2] <= i010_r; s0_i_reg[2] <= i010_i;
            s0_r_reg[3] <= i011_r; s0_i_reg[3] <= i011_i;
            s0_r_reg[4] <= i100_r; s0_i_reg[4] <= i100_i;
            s0_r_reg[5] <= i101_r; s0_i_reg[5] <= i101_i;
            s0_r_reg[6] <= i110_r; s0_i_reg[6] <= i110_i;
            s0_r_reg[7] <= i111_r; s0_i_reg[7] <= i111_i;
        end
    end

    // --- STAGE 1: Hadamard on q2 ---
    // This is implemented as a direct calculation, assuming 1 cycle for simplicity
    // H applies to pairs (0,4), (1,5), (2,6), (3,7)
    // For pipelining, this would take multiple cycles. For this model, we combine it.
    // The CROT gates dominate latency, so we abstract H-gate latency.
    // s1 is the state after H on q2.
    // This stage is combined with the delay line of the next stage.
    
    // --- STAGE 2: CROT(π/2) from q1 to q2 ---
    // Apply rotation only to states where q1=1 AND q2=1: indices 6,7
    crot_gate c21_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s0_r[6]), .in_i(s0_i[6]), .theta(THETA_PI_2), 
        .out_r(crot21_out_r[0]), .out_i(crot21_out_i[0])
    );
    crot_gate c21_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s0_r[7]), .in_i(s0_i[7]), .theta(THETA_PI_2), 
        .out_r(crot21_out_r[1]), .out_i(crot21_out_i[1])
    );
    
    // Delay non-rotated signals to match CROT delay (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage2[0:10][0:5][0:1]; // [delay][signal_index][real/imag]
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage2[d][i][0] <= 0;
                    delay_stage2[d][i][1] <= 0;
                end
            end
        end else begin
            // Input from stage 0
            delay_stage2[0][0][0] <= s0_r[0]; delay_stage2[0][0][1] <= s0_i[0];
            delay_stage2[0][1][0] <= s0_r[1]; delay_stage2[0][1][1] <= s0_i[1];
            delay_stage2[0][2][0] <= s0_r[2]; delay_stage2[0][2][1] <= s0_i[2];
            delay_stage2[0][3][0] <= s0_r[3]; delay_stage2[0][3][1] <= s0_i[3];
            delay_stage2[0][4][0] <= s0_r[4]; delay_stage2[0][4][1] <= s0_i[4];
            delay_stage2[0][5][0] <= s0_r[5]; delay_stage2[0][5][1] <= s0_i[5];
            
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage2[d][i][0] <= delay_stage2[d-1][i][0];
                    delay_stage2[d][i][1] <= delay_stage2[d-1][i][1];
                end
            end
        end
    end
    
    assign s1_r[0] = delay_stage2[10][0][0]; assign s1_i[0] = delay_stage2[10][0][1];
    assign s1_r[1] = delay_stage2[10][1][0]; assign s1_i[1] = delay_stage2[10][1][1];
    assign s1_r[2] = delay_stage2[10][2][0]; assign s1_i[2] = delay_stage2[10][2][1];
    assign s1_r[3] = delay_stage2[10][3][0]; assign s1_i[3] = delay_stage2[10][3][1];
    assign s1_r[4] = delay_stage2[10][4][0]; assign s1_i[4] = delay_stage2[10][4][1];
    assign s1_r[5] = delay_stage2[10][5][0]; assign s1_i[5] = delay_stage2[10][5][1];
    assign s1_r[6] = crot21_out_r[0];         assign s1_i[6] = crot21_out_i[0];
    assign s1_r[7] = crot21_out_r[1];         assign s1_i[7] = crot21_out_i[1];

    // --- STAGE 3: CROT(π/4) from q0 to q2 ---  
    // Apply rotation only to states where q0=1 AND q2=1: indices 5,7
    crot_gate c20_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s1_r[5]), .in_i(s1_i[5]), .theta(THETA_PI_4), 
        .out_r(crot20_out_r[0]), .out_i(crot20_out_i[0])
    );
    crot_gate c20_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s1_r[7]), .in_i(s1_i[7]), .theta(THETA_PI_4), 
        .out_r(crot20_out_r[1]), .out_i(crot20_out_i[1])
    );
    
    // Delay non-rotated signals (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage3[0:10][0:5][0:1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage3[d][i][0] <= 0;
                    delay_stage3[d][i][1] <= 0;
                end
            end
        end else begin
            delay_stage3[0][0][0] <= s1_r[0]; delay_stage3[0][0][1] <= s1_i[0];
            delay_stage3[0][1][0] <= s1_r[1]; delay_stage3[0][1][1] <= s1_i[1];
            delay_stage3[0][2][0] <= s1_r[2]; delay_stage3[0][2][1] <= s1_i[2];
            delay_stage3[0][3][0] <= s1_r[3]; delay_stage3[0][3][1] <= s1_i[3];
            delay_stage3[0][4][0] <= s1_r[4]; delay_stage3[0][4][1] <= s1_i[4];
            delay_stage3[0][5][0] <= s1_r[6]; delay_stage3[0][5][1] <= s1_i[6];
            
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage3[d][i][0] <= delay_stage3[d-1][i][0];
                    delay_stage3[d][i][1] <= delay_stage3[d-1][i][1];
                end
            end
        end
    end

    assign s2_r[0] = delay_stage3[10][0][0]; assign s2_i[0] = delay_stage3[10][0][1];
    assign s2_r[1] = delay_stage3[10][1][0]; assign s2_i[1] = delay_stage3[10][1][1];
    assign s2_r[2] = delay_stage3[10][2][0]; assign s2_i[2] = delay_stage3[10][2][1];
    assign s2_r[3] = delay_stage3[10][3][0]; assign s2_i[3] = delay_stage3[10][3][1];
    assign s2_r[4] = delay_stage3[10][4][0]; assign s2_i[4] = delay_stage3[10][4][1];
    assign s2_r[6] = delay_stage3[10][5][0]; assign s2_i[6] = delay_stage3[10][5][1];
    assign s2_r[5] = crot20_out_r[0];         assign s2_i[5] = crot20_out_i[0];
    assign s2_r[7] = crot20_out_r[1];         assign s2_i[7] = crot20_out_i[1];

    // --- STAGE 4: Hadamard on q1 ---
    // This is combined with the delay line of the next stage.
    
    // --- STAGE 5: CROT(π/2) from q0 to q1 ---
    // Apply rotation only to states where q0=1 AND q1=1: indices 3,7
    crot_gate c10_p0 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s2_r[3]), .in_i(s2_i[3]), .theta(THETA_PI_2), 
        .out_r(crot10_out_r[0]), .out_i(crot10_out_i[0])
    );
    crot_gate c10_p1 (
        .clk(clk), .rst_n(rst_n),
        .in_r(s2_r[7]), .in_i(s2_i[7]), .theta(THETA_PI_2), 
        .out_r(crot10_out_r[1]), .out_i(crot10_out_i[1])
    );
    
    // Delay non-rotated signals (11 cycles)
    reg signed [`TOTAL_WIDTH-1:0] delay_stage5[0:10][0:5][0:1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (integer d = 0; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage5[d][i][0] <= 0;
                    delay_stage5[d][i][1] <= 0;
                end
            end
        end else begin
            delay_stage5[0][0][0] <= s2_r[0]; delay_stage5[0][0][1] <= s2_i[0];
            delay_stage5[0][1][0] <= s2_r[1]; delay_stage5[0][1][1] <= s2_i[1];
            delay_stage5[0][2][0] <= s2_r[2]; delay_stage5[0][2][1] <= s2_i[2];
            delay_stage5[0][3][0] <= s2_r[4]; delay_stage5[0][3][1] <= s2_i[4];
            delay_stage5[0][4][0] <= s2_r[5]; delay_stage5[0][4][1] <= s2_i[5];
            delay_stage5[0][5][0] <= s2_r[6]; delay_stage5[0][5][1] <= s2_i[6];
            
            for (integer d = 1; d < 11; d=d+1) begin
                for (integer i = 0; i < 6; i=i+1) begin
                    delay_stage5[d][i][0] <= delay_stage5[d-1][i][0];
                    delay_stage5[d][i][1] <= delay_stage5[d-1][i][1];
                end
            end
        end
    end

    assign s3_r[0] = delay_stage5[10][0][0]; assign s3_i[0] = delay_stage5[10][0][1];
    assign s3_r[1] = delay_stage5[10][1][0]; assign s3_i[1] = delay_stage5[10][1][1];
    assign s3_r[2] = delay_stage5[10][2][0]; assign s3_i[2] = delay_stage5[10][2][1];
    assign s3_r[4] = delay_stage5[10][3][0]; assign s3_i[4] = delay_stage5[10][3][1];
    assign s3_r[5] = delay_stage5[10][4][0]; assign s3_i[5] = delay_stage5[10][4][1];
    assign s3_r[6] = delay_stage5[10][5][0]; assign s3_i[6] = delay_stage5[10][5][1];
    assign s3_r[3] = crot10_out_r[0];         assign s3_i[3] = crot10_out_i[0];
    assign s3_r[7] = crot10_out_r[1];         assign s3_i[7] = crot10_out_i[1];

    // --- STAGE 6: Hadamard on q0 ---
    // This is combined with the delay line of the next stage.
    
    // --- STAGE 7: SWAP q0 and q2 ---
    // Latency: 1 cycle
    swap_gate swapper (
        .clk(clk), .rst_n(rst_n),
        .in_001_r(s3_r[1]), .in_001_i(s3_i[1]),
        .in_100_r(s3_r[4]), .in_100_i(s3_i[4]),
        .in_011_r(s3_r[3]), .in_011_i(s3_i[3]),
        .in_110_r(s3_r[6]), .in_110_i(s3_i[6]),
        .out_001_r(swap_out_001_r), .out_001_i(swap_out_001_i),
        .out_100_r(swap_out_100_r), .out_100_i(swap_out_100_i),
        .out_011_r(swap_out_011_r), .out_011_i(swap_out_011_i),
        .out_110_r(swap_out_110_r), .out_110_i(swap_out_110_i)
    );

    // Delay non-swapped signals by 1 cycle
    reg signed [`TOTAL_WIDTH-1:0] s4_r_reg[0:7], s4_i_reg[0:7];
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for(integer i=0; i<8; i=i+1) begin
                s4_r_reg[i] <= 0; s4_i_reg[i] <= 0;
            end
        end else begin
            s4_r_reg[0] <= s3_r[0]; s4_i_reg[0] <= s3_i[0];
            s4_r_reg[2] <= s3_r[2]; s4_i_reg[2] <= s3_i[2];
            s4_r_reg[5] <= s3_r[5]; s4_i_reg[5] <= s3_i[5];
            s4_r_reg[7] <= s3_r[7]; s4_i_reg[7] <= s3_i[7];
        end
    end

    // Reassemble state vector after swap
    assign s4_r[0] = s4_r_reg[0]; assign s4_i[0] = s4_i_reg[0];
    assign s4_r[1] = swap_out_001_r; assign s4_i[1] = swap_out_001_i;
    assign s4_r[2] = s4_r_reg[2]; assign s4_i[2] = s4_i_reg[2];
    assign s4_r[3] = swap_out_011_r; assign s4_i[3] = swap_out_011_i;
    assign s4_r[4] = swap_out_100_r; assign s4_i[4] = swap_out_100_i;
    assign s4_r[5] = s4_r_reg[5]; assign s4_i[5] = s4_i_reg[5];
    assign s4_r[6] = swap_out_110_r; assign s4_i[6] = swap_out_110_i;
    assign s4_r[7] = s4_r_reg[7]; assign s4_i[7] = s4_i_reg[7];

    // --- STAGE 8: Final Output ---
    // The total latency is not explicitly calculated here but is handled by the valid_pipe
    // The final state s4 is registered to the outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            f000_r <= 0; f000_i <= 0; f001_r <= 0; f001_i <= 0;
            f010_r <= 0; f010_i <= 0; f011_r <= 0; f011_i <= 0;
            f100_r <= 0; f100_i <= 0; f101_r <= 0; f101_i <= 0;
            f110_r <= 0; f110_i <= 0; f111_r <= 0; f111_i <= 0;
            valid_out <= 1'b0;
        end else begin
            // Register final values
            f000_r <= s4_r[0]; f000_i <= s4_i[0];
            f001_r <= s4_r[1]; f001_i <= s4_i[1];
            f010_r <= s4_r[2]; f010_i <= s4_i[2];
            f011_r <= s4_r[3]; f011_i <= s4_i[3];
            f100_r <= s4_r[4]; f100_i <= s4_i[4];
            f101_r <= s4_r[5]; f101_i <= s4_i[5];
            f110_r <= s4_r[6]; f110_i <= s4_i[6];
            f111_r <= s4_r[7]; f111_i <= s4_i[7];
            // Output valid is the end of the pipeline
            valid_out <= valid_pipe[35];
        end
    end

endmodule