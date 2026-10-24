`timescale 1ns / 1ps
//
// div16_8_recip - unsigned 16-bit / 8-bit divide, 16-bit quotient.
//
// For a fast numerator and a slow denominator.  Instead of a subtract chain,
// it looks up ceil(2^24 / den) in a 256-entry ROM and multiplies.  That is
// one DSP48E1 (16 x 24 unsigned fits the 25 x 18 ports) plus one small ROM,
// and every stage is registered, so it holds up at pixel-clock rates.
//
// The result is BIT EXACT against num/den for all num 0..65535, den 1..255
// (verified by exhaustive simulation).  ceil() is what makes it exact: the
// product can only land ABOVE the true quotient, by at most 65535/2^24 =
// 0.003906, and the closest a non-integer num/den can sit below an integer
// is 1/255 = 0.003922.  The truncation therefore never crosses a boundary.
// A 16-bit reciprocal is NOT enough - it misses on 4.3 million of the
// 16.7 million input pairs.
//
// The quotient always fits: 16 bits over den >= 1 cannot exceed 16 bits,
// so no saturation is needed.  den = 0 alone is special and gives 0xFFFF.
// den = 1 bypasses the multiplier, because ceil(2^24/1) needs 25 bits.
//
// Latency: 3 clocks when ce is high.  Throughput: one result per clock.
//
module div16_8_recip (
	input  wire        clk,
	input  wire        ce,
	input  wire [15:0] num,
	input  wire [7:0]  den,
	output reg  [15:0] quot
);
	// ---------------------------------------------------------------
	// reciprocal ROM: recip[d] = ceil(2^24 / d), 24 bits for d >= 2
	// rom_style "block" keeps it out of the slices, which are the
	// scarce resource here.  Change to "distributed" if BRAM is tight.
	// ---------------------------------------------------------------
	(* rom_style = "block" *) reg [23:0] recip [0:255];

	integer d;
	initial begin
		recip[0] = 24'd0;		// unused: den == 0 gives 0xFFFF
		recip[1] = 24'd0;		// unused: den == 1 bypasses
		for (d = 2; d < 256; d = d + 1)
			recip[d] = (16777216 + d - 1) / d;
	end

	// ---------------------------------------------------------------
	// stage 1: ROM read, and flag the two special denominators
	// ---------------------------------------------------------------
	reg [23:0] recip_q;
	reg [15:0] num_q;
	reg        by1_q, by0_q;

	always @(posedge clk) begin
		if (ce) begin
			recip_q <= recip[den];
			num_q   <= num;
			by1_q   <= (den == 8'd1);
			by0_q   <= (den == 8'd0);
		end
	end

	// ---------------------------------------------------------------
	// stage 2: the multiply.  The 40-bit target matters: Verilog sizes
	// the expression from the assignment context, so the product is
	// not truncated.
	// ---------------------------------------------------------------
	(* use_dsp = "yes" *) reg [39:0] prod;
	reg [15:0] num_r;
	reg        by1_r, by0_r;

	always @(posedge clk) begin
		if (ce) begin
			prod  <= num_q * recip_q;
			num_r <= num_q;
			by1_r <= by1_q;
			by0_r <= by0_q;
		end
	end

	// ---------------------------------------------------------------
	// stage 3: pick the quotient.  No clamp: it always fits 16 bits.
	// ---------------------------------------------------------------
	always @(posedge clk) begin
		if (ce)
			quot <= by0_r ? 16'hFFFF :
				by1_r ? num_r    : prod[39:24];
	end
endmodule
