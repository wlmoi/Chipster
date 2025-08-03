`timescale 1ns / 1ps
`include "fixed_point_params.vh"

// A general SWAP gate for a 3-qubit system that swaps q0 and q2.
// It swaps the amplitudes for the state pairs (|001>,|100>) and (|011>,|110>).
module swap_gate(
    // Inputs for the first pair to be swapped
    input  signed [`TOTAL_WIDTH-1:0] in_001_r, in_001_i, // Amp for |001>
    input  signed [`TOTAL_WIDTH-1:0] in_100_r, in_100_i, // Amp for |100>

    // Inputs for the second pair to be swapped
    input  signed [`TOTAL_WIDTH-1:0] in_011_r, in_011_i, // Amp for |011>
    input  signed [`TOTAL_WIDTH-1:0] in_110_r, in_110_i, // Amp for |110>

    // Swapped outputs
    output signed [`TOTAL_WIDTH-1:0] out_001_r, out_001_i,
    output signed [`TOTAL_WIDTH-1:0] out_100_r, out_100_i,
    output signed [`TOTAL_WIDTH-1:0] out_011_r, out_011_i,
    output signed [`TOTAL_WIDTH-1:0] out_110_r, out_110_i
);

    // Perform the first swap: new |001> gets old |100>
    assign {out_001_r, out_001_i} = {in_100_r, in_100_i};
    assign {out_100_r, out_100_i} = {in_001_r, in_001_i};

    // Perform the second swap: new |011> gets old |110>
    assign {out_011_r, out_011_i} = {in_110_r, in_110_i};
    assign {out_110_r, out_110_i} = {in_011_r, in_011_i};

endmodule