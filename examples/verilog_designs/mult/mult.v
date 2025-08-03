module mult #(
    parameter WIDTH = 32
)
(
    input   clk,
    input  [WIDTH-1:0] A,
    input  [WIDTH-1:0] B,
    output reg [WIDTH*2-1:0] Y
);

    always @(posedge clk) begin
        Y <= A * B;
    end

endmodule