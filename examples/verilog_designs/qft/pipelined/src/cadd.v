`timescale 1ns / 1ps
`include "fixed_point_params.vh"

module cadd(
    input  wire clk,
    input  wire rst_n,
    input  signed [`TOTAL_WIDTH-1:0] ar, ai, // Input A
    input  signed [`TOTAL_WIDTH-1:0] br, bi, // Input B
    output reg signed [`ADD_WIDTH-1:0]   pr, pi  // Output P (wider to prevent overflow)
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pr <= 0;
            pi <= 0;
        end else begin
            pr <= ar + br;
            pi <= ai + bi;
        end
    end

endmodule