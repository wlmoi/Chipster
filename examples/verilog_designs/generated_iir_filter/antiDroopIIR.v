module antiDroopIIR (
	input clk,
	input trig,
	input signed [12:0] din,
	input signed [6:0] tapWeight,
	input accClr_en,
	input oflowClr,
	output reg oflowDetect = 1'd0,
	output reg signed [15:0] dout = 16'sd0
);

	parameter IIR_scale = 15; // define the scaling factor for the IIR multiplier, eg for 0.002 (din = 63, IIR_scale = 15).

	//`define ADDPIPEREG

	reg signed [12:0] din_del = 13'sd0;
	`ifdef ADDPIPEREG
	reg signed [12:0] din_del_b = 13'sd0;
	`endif
	reg signed [47:0] tap = 48'sd0;
	reg signed [19:0] multreg = 20'sd0;

	(* equivalent_register_removal = "no" *) reg trig_a = 1'b0, trig_b = 1'b0;
	wire trig_edge = trig_a & ~trig_b;

	(* shreg_extract = "no" *) reg signed [6:0] tapWeight_a = 7'sd0;
	(* shreg_extract = "no" *) reg signed [6:0] tapWeight_b = 7'sd0;

	// Overflow detection on the accumulator.
	// Checks if the upper bits (beyond the 31-bit result range) are not a valid sign extension.
	wire oflow = (~&tap[47:IIR_scale+15] && ~&(~tap[47:IIR_scale+15]));

	always @(posedge clk) begin
		// Pipeline trigger for edge detection
		trig_a <= trig;
		trig_b <= trig_a;

		// Pipeline tap weight coefficient
		tapWeight_a <= tapWeight;
		tapWeight_b <= tapWeight_a;

		// Handle accumulator clear (highest priority)
		if (accClr_en) begin
			tap <= 48'sd0;
			din_del <= 13'sd0;
			`ifdef ADDPIPEREG
			din_del_b <= 13'sd0;
			`endif
			multreg <= 20'sd0;
			oflowDetect <= 1'b0;
		end else begin
			// Handle overflow flag clear
			if (oflowClr) begin
				oflowDetect <= 1'b0;
			end else if (oflow) begin
				// Latch the overflow condition
				oflowDetect <= 1'b1;
			end

			// Main filter logic on trigger edge
			if (trig_edge) begin
				`ifdef ADDPIPEREG
				// 3-stage pipeline: din -> din_del -> din_del_b -> mult
				din_del <= din;
				din_del_b <= din_del;
				multreg <= din_del_b * tapWeight_b;
				tap <= tap + multreg;
				`else
				// 2-stage pipeline: din -> din_del -> mult
				din_del <= din;
				multreg <= din_del * tapWeight_b;
				tap <= tap + multreg;
				`endif
			end
		end

		// Assign scaled accumulator value to output register
		dout <= tap[IIR_scale+15:IIR_scale];
	end

endmodule
