/*
 * Copyright 2021 Ashish Ojha
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// A simple 3-stage RISC-V Processor
module riscv_core(
    input wire clk,
    input wire rst,
    // Instruction Memory
    output wire[31:0] instr_mem_addr,
    input wire[31:0] instr_mem_rdata,
    // Data Memory
    output wire[31:0] data_mem_addr,
    output wire[31:0] data_mem_wdata,
    output wire data_mem_we,
    input wire[31:0] data_mem_rdata
);

    // PC and Fetch Stage
    reg [31:0] pc_reg;
    wire [31:0] pc_plus_4 = pc_reg + 32'd4;
    wire [31:0] pc_next;
    assign instr_mem_addr = pc_reg;

    // Decode Stage
    wire [6:0] opcode = instr_mem_rdata[6:0];
    wire [4:0] rd = instr_mem_rdata[11:7];
    wire [2:0] funct3 = instr_mem_rdata[14:12];
    wire [4:0] rs1 = instr_mem_rdata[19:15];
    wire [4:0] rs2 = instr_mem_rdata[24:20];
    wire [6:0] funct7 = instr_mem_rdata[31:25];

    // Control Unit
    wire is_jal, is_jalr, is_branch;
    wire [1:0] alu_op_type;
    wire alu_src_b;
    wire mem_to_reg;
    wire reg_write_en;
    wire mem_write_en;

    control_unit ctrl_unit (
        .opcode(opcode),
        .is_jal(is_jal),
        .is_jalr(is_jalr),
        .is_branch(is_branch),
        .alu_op_type(alu_op_type),
        .alu_src_b(alu_src_b),
        .mem_to_reg(mem_to_reg),
        .reg_write_en(reg_write_en),
        .mem_write_en(mem_write_en)
    );

    // Immediate Generator
    wire [31:0] imm_gen_out;
    imm_gen imm_gen_unit (
        .instruction(instr_mem_rdata),
        .imm(imm_gen_out)
    );

    // Register File
    wire [31:0] reg_file_rdata1;
    wire [31:0] reg_file_rdata2;
    wire [31:0] reg_write_data;

    reg_file reg_file_unit (
        .clk(clk),
        .rst(rst),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(reg_write_data),
        .write_en(reg_write_en),
        .rdata1(reg_file_rdata1),
        .rdata2(reg_file_rdata2)
    );

    // ALU
    wire [31:0] alu_in_a;
    wire [31:0] alu_in_b;
    wire [3:0] alu_control;
    wire [31:0] alu_result;
    wire alu_zero_flag;

    assign alu_in_a = reg_file_rdata1;
    assign alu_in_b = (alu_src_b) ? imm_gen_out : reg_file_rdata2;

    alu_control alu_control_unit (
        .alu_op_type(alu_op_type),
        .funct3(funct3),
        .funct7(funct7),
        .alu_control(alu_control)
    );

    alu alu_unit (
        .in_a(alu_in_a),
        .in_b(alu_in_b),
        .alu_control(alu_control),
        .result(alu_result),
        .zero(alu_zero_flag)
    );

    // Branch Logic
    wire branch_taken = is_branch & alu_zero_flag;
    wire [31:0] branch_target_addr = pc_reg + imm_gen_out;
    wire [31:0] jump_target_addr = reg_file_rdata1 + imm_gen_out;

    // PC Next Logic
    assign pc_next = (is_jal) ? (pc_reg + imm_gen_out) :
                     (is_jalr) ? jump_target_addr :
                     (branch_taken) ? branch_target_addr :
                     pc_plus_4;

    // Write Back Logic
    assign reg_write_data = (mem_to_reg) ? data_mem_rdata : alu_result;

    // Data Memory Interface
    assign data_mem_addr = alu_result;
    assign data_mem_wdata = reg_file_rdata2;
    assign data_mem_we = mem_write_en;

    // PC Update
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            pc_reg <= 32'h00000000;
        end else begin
            pc_reg <= pc_next;
        end
    end

endmodule