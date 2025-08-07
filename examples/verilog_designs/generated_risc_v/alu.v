// ALU
module alu(
    input wire[31:0] in_a,
    input wire[31:0] in_b,
    input wire[3:0] alu_control,
    output reg[31:0] result,
    output reg zero
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
        case (alu_control)
            ALU_ADD: result = in_a + in_b;
            ALU_SUB: result = in_a - in_b;
            ALU_SLL: result = in_a << in_b[4:0];
            ALU_SLT: result = ($signed(in_a) < $signed(in_b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (in_a < in_b) ? 32'd1 : 32'd0;
            ALU_XOR: result = in_a ^ in_b;
            ALU_SRL: result = in_a >> in_b[4:0];
            ALU_SRA: result = $signed(in_a) >>> in_b[4:0];
            ALU_OR: result = in_a | in_b;
            ALU_AND: result = in_a & in_b;
            default: result = 32'hdeadbeef;
        endcase
        zero = (result == 32'b0);
    end

endmodule