// Register File
module reg_file(
    input wire clk,
    input wire rst,
    input wire[4:0] rs1,
    input wire[4:0] rs2,
    input wire[4:0] rd,
    input wire[31:0] write_data,
    input wire write_en,
    output wire[31:0] rdata1,
    output wire[31:0] rdata2
);

    reg [31:0] registers[31:0];
    integer i;

    // Asynchronous read
    assign rdata1 = (rs1 == 5'b0) ? 32'b0 : registers[rs1];
    assign rdata2 = (rs2 == 5'b0) ? 32'b0 : registers[rs2];

    // Synchronous write
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'b0;
            end
        end else if (write_en && (rd != 5'b0)) begin
            registers[rd] <= write_data;
        end
    end

endmodule