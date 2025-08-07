// ALU Control
module alu_control(
    input wire[1:0] alu_op_type,
    input wire[2:0] funct3,
    input wire[6:0] funct7,
    output reg[3:0] alu_control
);

    // ALU Operations
    localparam ALU_ADD = 4'b0000;
    localparam ALU_SUB = 4'b0001;
    localparam ALU_SLL = 4'b0010;
    localparam ALU_SLT = 4'b0011;
    localparam ALU_SLTU = 4'b0100;
    localparam ALU_XOR = 4'b0101;
    localparam ALU_SRL = 4'b0110;
    localparam ALU_SRA = 4'b0111;
    localparam ALU_OR = 4'b1000;
    localparam ALU_AND = 4'b1001;

    always @(*) begin
        case (alu_op_type)
            2'b00: // LW, SW, ADDI
                alu_control = ALU_ADD;
            2'b01: // Branch
                case (funct3)
                    3'b000: alu_control = ALU_SUB; // BEQ
                    3'b001: alu_control = ALU_SUB; // BNE
                    default: alu_control = 4'bxxxx; // Should not happen
                endcase
            2'b10: // R-type
                case (funct3)
                    3'b000: alu_control = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_control = ALU_SLL;
                    3'b010: alu_control = ALU_SLT;
                    3'b011: alu_control = ALU_SLTU;
                    3'b100: alu_control = ALU_XOR;
                    3'b101: alu_control = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_control = ALU_OR;
                    3'b111: alu_control = ALU_AND;
                    default: alu_control = 4'bxxxx;
                endcase
            default: alu_control = 4'bxxxx;
        endcase
    end

endmodule