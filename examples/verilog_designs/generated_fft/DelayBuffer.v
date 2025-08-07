//------------------------------------------------------------------------------
// Module: DelayBuffer
// Description: A register-based delay buffer (shift register).
//------------------------------------------------------------------------------
module DelayBuffer #(
    parameter   WIDTH = 16,
    parameter   DELAY = 8,
    parameter   ADDR_WIDTH = 3
)(
    input                   clock,
    input                   reset,
    input                   in_en,
    input   [WIDTH-1:0]     in_data,
    output                  out_en,
    output  [WIDTH-1:0]     out_data
);

    reg     [WIDTH-1:0]     mem [DELAY-1:0];
    reg     [ADDR_WIDTH-1:0] w_addr;
    reg     [ADDR_WIDTH-1:0] r_addr;

    always @(posedge clock) begin
        if (in_en) begin
            mem[w_addr] <= in_data;
        end
    end

    assign out_data = mem[r_addr];

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            w_addr <= 0;
        end else if (in_en) begin
            w_addr <= w_addr + 1;
        end
    end

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            r_addr <= 1;
        end else if (in_en) begin
            r_addr <= r_addr + 1;
        end
    end

    //
    // output enable
    //
    reg     [DELAY-1:0]     en_pipe;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            en_pipe <= 0;
        end else begin
            en_pipe <= {en_pipe[DELAY-2:0], in_en};
        end
    end

    assign out_en = en_pipe[DELAY-1];

endmodule
