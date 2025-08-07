// Immediate Generator
module imm_gen(
    input wire[31:0] instruction,
    output wire[31:0] imm
);

    wire [6:0] opcode = instruction[6:0];
    wire [31:0] imm_i, imm_s, imm_b, imm_u, imm_j;

    // I-type
    assign imm_i = {{20{instruction[31]}}, instruction[31:20]};
    // S-type
    assign imm_s = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
    // B-type
    assign imm_b = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
    // U-type
    assign imm_u = {instruction[31:12], 12'b0};
    // J-type
    assign imm_j = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};

    // Opcodes
    localparam OPCODE_I_TYPE = 7'b0010011;
    localparam OPCODE_LOAD = 7'b0000011;
    localparam OPCODE_STORE = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL = 7'b1101111;
    localparam OPCODE_JALR = 7'b1100111;
    localparam OPCODE_AUIPC = 7'b0010111;
    localparam OPCODE_LUI = 7'b0110111;

    assign imm = (opcode == OPCODE_I_TYPE || opcode == OPCODE_LOAD || opcode == OPCODE_JALR) ? imm_i :
                 (opcode == OPCODE_STORE) ? imm_s :
                 (opcode == OPCODE_BRANCH) ? imm_b :
                 (opcode == OPCODE_LUI || opcode == OPCODE_AUIPC) ? imm_u :
                 (opcode == OPCODE_JAL) ? imm_j :
                 32'hdeadbeef; // Default case

endmodule