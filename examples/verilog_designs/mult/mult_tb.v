`timescale 1ns/100ps

module mult_tb;

    localparam WIDTH = 32;

    reg  clk;
    reg [WIDTH-1:0] A;
    reg [WIDTH-1:0] B;
    wire [WIDTH*2-1:0] Y;

    mult #(
        .WIDTH(WIDTH)
    ) uut (
        .clk(clk),
        .A(A),
        .B(B),
        .Y(Y)
    );

    initial begin
        clk = 0; // Initialize clock
    end

    always #5 clk = ~clk; // Toggle clock every 5ns

    initial begin
      $dumpfile("mult.vcd");
      $dumpvars(0, mult_tb);
    end

    initial begin
        // Initialize inputs
        A = 0;
        B = 0;

        // Wait for a couple of cycles
        @(posedge clk);
        @(posedge clk);

        // Test Case 1: Small positive numbers
        A <= 32'd10;
        B <= 32'd20;
        @(posedge clk);
        @(posedge clk);

        // Test Case 2: One operand is zero
        A <= 32'd12345;
        B <= 32'd0;
        @(posedge clk);
        @(posedge clk);

        // Test Case 3: One operand is one
        A <= 32'd1;
        B <= 32'd9876;
        @(posedge clk);
        @(posedge clk);

        // Test Case 4: Larger numbers
        A <= 32'd100000;
        B <= 32'd50000;
        @(posedge clk);
        @(posedge clk);

        // Test Case 5: Maximum value for one input
        A <= 32'hFFFF_FFFF;
        B <= 32'd2;
        @(posedge clk);
        @(posedge clk);

        // Test Case 6: Random values
        A <= $random;
        B <= $random;
        @(posedge clk);
        @(posedge clk);

        #20; // Wait a bit longer
        $finish;
    end

endmodule