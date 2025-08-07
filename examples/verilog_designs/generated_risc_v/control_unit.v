// Control Unit
module control_unit(
    input wire[6:0] opcode,
    output reg is_jal,
    output reg is_jalr,
    output reg is_branch,
    output reg[1:0] alu_op_type,
    output reg alu_src_b,
    output reg mem_to_reg,
    output reg reg_write_en,
    output reg mem_write_en
);

    // Opcodes
    localparam OPCODE_R_TYPE = 7'b0110011;
    localparam OPCODE_I_TYPE = 7'b0010011;
    localparam OPCODE_LOAD = 7'b0000011;
    localparam OPCODE_STORE = 7'b0100011;
    localparam OPCODE_BRANCH = 7'b1100011;
    localparam OPCODE_JAL = 7'b1101111;
    localparam OPCODE_JALR = 7'b1100111;
    localparam OPCODE_AUIPC = 7'b0010111;
    localparam OPCODE_LUI = 7'b0110111;

    always @(*) begin
        // Default values
        is_jal = 1'b0;
        is_jalr = 1'b0;
        is_branch = 1'b0;
        alu_op_type = 2'b00;
        alu_src_b = 1'b0;
        mem_to_reg = 1'b0;
        reg_write_en = 1'b0;
        mem_write_en = 1'b0;

        case (opcode)
            OPCODE_R_TYPE: begin
                reg_write_en = 1'b1;
                alu_op_type = 2'b10;
            end
            OPCODE_I_TYPE: begin
                reg_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_LOAD: begin
                reg_write_en = 1'b1;
                mem_to_reg = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_STORE: begin
                mem_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_BRANCH: begin
                is_branch = 1'b1;
                alu_op_type = 2'b01;
            end
            OPCODE_JAL: begin
                is_jal = 1'b1;
                reg_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_JALR: begin
                is_jalr = 1'b1;
                reg_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_LUI: begin
                reg_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
            OPCODE_AUIPC: begin
                reg_write_en = 1'b1;
                alu_src_b = 1'b1;
            end
        endcase
    end

endmodule