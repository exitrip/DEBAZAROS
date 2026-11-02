// hdmi_tx_cdc_tb.sv - test of hw/rtl/hdmi_tx/hdmi_tx_cdc.v (run with
// hw/sim/run_hdmi_tx_tb.sh). wclk and rclk have the same period; rclk starts
// at a phase of k/5 of a period (k = 0..4, the 5 possible BUFR phases). The
// write side sends a counter; after the start the read side must give every
// value in order (one step per clock). Then: (1) rclk stops for 6 periods
// (the FIFO runs full, an overrun): at most two breaks of the counter (the
// jump back is computed from the writer pointer 2 clocks late, so one word
// can come twice), then steps of 1 again;
// (2) a relock as the board does it: both resets (aRst_n = dynclk LOCKED),
// rclk stops for 20 periods inside the reset, then the stream starts again
// with steps of 1.
`timescale 1ns/1ps
module tb;
  localparam real P = 13.468;          // 74.25 MHz
  reg wclk = 0, rclk = 0, rstn = 0, rstop = 0;
  integer k, fails = 0;
  reg [29:0] cnt = 0;
  wire [29:0] q;
  reg wrst = 1, rrst = 1;

  hdmi_tx_cdc #(.W(30)) dut (.wclk(wclk), .wrst(wrst), .wdata(cnt),
      .rclk(rclk), .rrst(rrst), .rdata(q));

  always #(P / 2) wclk = ~wclk;
  initial begin
    if (!$value$plusargs("k=%d", k)) k = 0;
    #(P * k / 5.0);
    forever begin
      #(P / 2);
      if (!rstop) rclk = ~rclk;
    end
  end
  always @(posedge wclk) begin
    wrst <= !rstn;
    cnt <= cnt + 1;
  end
  always @(posedge rclk) rrst <= !rstn;

  // check: once q moves, every next value = previous + 1
  reg [29:0] last = 0;
  reg started = 0, check = 1;
  integer steps = 0, jumps = 0, maxj = 1;
  always @(posedge rclk) begin
    #1;
    if (!rrst && q != 0) begin
      if (started && check && q != last + 1) begin
        jumps = jumps + 1;
        if (jumps > maxj) begin fails = fails + 1; if (fails < 5) $display("FAIL k=%0d: %0d after %0d", k, q, last); end
      end
      if (started) steps = steps + 1;
      started = 1;
      last = q;
    end
  end

  initial begin
    repeat (5) @(posedge wclk);
    rstn = 1;
    repeat (400) @(posedge wclk);
    if (steps < 380) begin fails = fails + 1; $display("FAIL k=%0d: only %0d steps", k, steps); end
    if (jumps) begin fails = fails + 1; $display("FAIL k=%0d: %0d jumps in steady state", k, jumps); end
    // (1) rclk stops for 6 periods: allow one jump, then steps of 1 again
    maxj = 2;
    rstop = 1; repeat (6) @(posedge wclk); rstop = 0;
    jumps = 0; steps = 0;
    repeat (400) @(posedge wclk);
    if (steps < 370) begin fails = fails + 1; $display("FAIL k=%0d: only %0d steps after the stop", k, steps); end
    // (2) relock: reset, rclk stops for 20 periods, reset released
    maxj = 1;
    rstn = 0; repeat (2) @(posedge wclk);
    rstop = 1; repeat (20) @(posedge wclk); rstop = 0;
    repeat (3) @(posedge wclk); rstn = 1;
    started = 0; jumps = 0; steps = 0;
    repeat (400) @(posedge wclk);
    if (steps < 370) begin fails = fails + 1; $display("FAIL k=%0d: only %0d steps after the relock", k, steps); end
    if (jumps) begin fails = fails + 1; $display("FAIL k=%0d: %0d jumps after the relock", k, jumps); end
    if (fails) $display("FAILED %0d (k=%0d)", fails, k);
    else $display("ALL PASS cdc k=%0d", k);
    $finish;
  end
endmodule
