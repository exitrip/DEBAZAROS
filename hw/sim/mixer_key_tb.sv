// mixer_key_tb.sv - mixer IP test (run with hw/sim/run_mixer_tb.sh):
//  1. equivalence: the mixer of commit 4e2d1820 (renamed mixer_ref_*) and the
//     new mixer get the same random register writes (all modes, gains,
//     thresholds, stream bits; the new KEY/SRC bits 0) and the same random
//     pixels. All 9 douts must match on every pixel clock, and pix_out must be
//     bg_in one pixel clock later.
//  2. colour key: CTRL_1 [1] KEY, [2] SRC per channel; channel 0 CTRL_0 [8]
//     invert, [9] fill from stream B.
// Pixels are in pixel-bus lane order: R [23:16], B [15:8], G [7:0].
`timescale 1ns/1ps
module tb;
  reg clk = 0, pclk = 0, rstn = 0;
  always #5 clk = ~clk;
  always #7 pclk = ~pclk;

  // one AXI-Lite manager drives both mixers
  reg [9:0] awaddr = 0, araddr = 0;
  reg awvalid = 0, wvalid = 0, arvalid = 0;
  reg [31:0] wdata = 0;
  wire awready, wready, bvalid, arready, rvalid, r_awready, r_wready, r_bvalid;
  wire [1:0] bresp, rresp, r_bresp;
  wire [31:0] rdata;
  reg [15:0] d0, d1, d2, d3, d4, d5, d6, d7;
  reg [23:0] bg, vid;
  wire [23:0] pout;
  wire [23:0] o [0:8];
  wire [23:0] r [0:8];

  mixer_v1_0 #(.IN_WIDTH(16), .OUT_WIDTH(24)) dut (
    .pix_clk(pclk), .dout0(o[0]), .dout1(o[1]), .dout2(o[2]), .dout3(o[3]), .dout4(o[4]),
    .dout5(o[5]), .dout6(o[6]), .dout7(o[7]), .dout8(o[8]),
    .din0(d0), .din1(d1), .din2(d2), .din3(d3), .din4(d4), .din5(d5), .din6(d6), .din7(d7),
    .bg_in(bg), .vid_in(vid), .pix_out(pout),
    .s00_axi_aclk(clk), .s00_axi_aresetn(rstn), .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'd0),
    .s00_axi_awvalid(awvalid), .s00_axi_awready(awready), .s00_axi_wdata(wdata),
    .s00_axi_wstrb(4'hf), .s00_axi_wvalid(wvalid), .s00_axi_wready(wready),
    .s00_axi_bresp(bresp), .s00_axi_bvalid(bvalid), .s00_axi_bready(1'b1),
    .s00_axi_araddr(araddr), .s00_axi_arprot(3'd0), .s00_axi_arvalid(arvalid),
    .s00_axi_arready(arready), .s00_axi_rdata(rdata), .s00_axi_rresp(rresp),
    .s00_axi_rvalid(rvalid), .s00_axi_rready(1'b1));

  mixer_ref_v1_0 #(.IN_WIDTH(16), .OUT_WIDTH(24)) ref_mixer (
    .pix_clk(pclk), .dout0(r[0]), .dout1(r[1]), .dout2(r[2]), .dout3(r[3]), .dout4(r[4]),
    .dout5(r[5]), .dout6(r[6]), .dout7(r[7]), .dout8(r[8]),
    .din0(d0), .din1(d1), .din2(d2), .din3(d3), .din4(d4), .din5(d5), .din6(d6), .din7(d7),
    .s00_axi_aclk(clk), .s00_axi_aresetn(rstn), .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'd0),
    .s00_axi_awvalid(awvalid), .s00_axi_awready(r_awready), .s00_axi_wdata(wdata),
    .s00_axi_wstrb(4'hf), .s00_axi_wvalid(wvalid), .s00_axi_wready(r_wready),
    .s00_axi_bresp(r_bresp), .s00_axi_bvalid(r_bvalid), .s00_axi_bready(1'b1),
    .s00_axi_araddr(10'd0), .s00_axi_arprot(3'd0), .s00_axi_arvalid(1'b0),
    .s00_axi_arready(), .s00_axi_rdata(), .s00_axi_rresp(), .s00_axi_rvalid(),
    .s00_axi_rready(1'b1));

  // register index = chan*10 + n, byte address = index*4
  function [9:0] ra(input integer c, input integer n); ra = (c * 10 + n) * 4; endfunction

  task wr(input [9:0] a, input [31:0] d);
    begin
      @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
      while (!(awready && wready && r_awready && r_wready)) @(posedge clk);
      @(posedge clk); awvalid <= 0; wvalid <= 0;
      repeat (2) @(posedge clk);
    end
  endtask
  task rd(input [9:0] a, output [31:0] d);
    begin
      @(posedge clk); araddr <= a; arvalid <= 1;
      while (!arready) @(posedge clk);
      @(posedge clk); arvalid <= 0;
      while (!rvalid) @(posedge clk);
      d = rdata; @(posedge clk);
    end
  endtask

  integer fails = 0, checks = 0;
  task fail(input [255:0] what); begin fails = fails + 1; if (fails < 20) $display("FAIL %0s", what); end endtask

  // random pixels on every pixel clock while 'run' is set
  reg run = 0;
  always @(negedge pclk) if (run) begin
    d0 = $random & 16'hff; d1 = $random & 16'hff; d2 = $random & 16'hff;
    d3 = $random; d4 = $random;
    d5 = $random & 16'hff; d6 = $random & 16'hff; d7 = $random & 16'hff;
    bg = $random; vid = $random;
  end

  // equivalence check on every pixel clock while 'cmp' is set
  reg cmp = 0;
  integer k;
  always @(posedge pclk) begin
    #1;
    if (cmp) begin
      for (k = 0; k < 9; k = k + 1)
        if (o[k] !== r[k]) begin
          fail("dout differs from the reference");
          $display("     chan %0d new %06x ref %06x", k, o[k], r[k]);
        end
      // bg changes on the falling edge: pix_out holds the bg_in of this edge
      if (pout !== bg) fail("pix_out != registered bg_in (key off)");
      checks = checks + 1;
    end
  end

  function [7:0] rmode(input integer x);
    case (x % 14)
      0: rmode = 8'h00; 1: rmode = 8'h01; 2: rmode = 8'h03; 3: rmode = 8'h04;
      4: rmode = 8'h10; 5: rmode = 8'h11; 6: rmode = 8'h12; 7: rmode = 8'h13;
      8: rmode = 8'h20; 9: rmode = 8'h21; 10: rmode = 8'h22; 11: rmode = 8'h23;
      12: rmode = 8'h02; default: rmode = $random;	// unused modes -> default
    endcase
  endfunction

  // set the HDMI_1 pixel (stream A) and HDMI_0's video, then check pix_out
  task px(input [23:0] h1, input [23:0] v0, input [23:0] want, input [255:0] name);
    begin
      @(negedge pclk);
      d0 = h1[23:16]; d1 = h1[15:8]; d2 = h1[7:0]; vid = v0;
      @(posedge pclk); @(posedge pclk); #1;
      if (pout !== want) begin fail(name); $display("     got %06x want %06x", pout, want); end
      else $display("ok   %0s", name);
    end
  endtask

  integer round, c, n;
  reg [31:0] v;
  initial begin
    d0 = 0; d1 = 0; d2 = 0; d3 = 0; d4 = 0; d5 = 0; d6 = 0; d7 = 0; bg = 0; vid = 0;
    repeat (4) @(posedge clk); rstn = 1;
    repeat (4) @(posedge pclk);

    // ---- 1. equivalence with the old mixer --------------------------------
    run = 1;
    for (round = 0; round < 40; round = round + 1) begin
      cmp = 0;
      for (c = 0; c < 9; c = c + 1) begin
        for (n = 0; n < 5; n = n + 1)
          wr(ra(c, n), (round % 3 == 0) ? ($random & 32'h1ff) : $random);
        // CTRL_0: mode, random [15:8] (new global bits in chan 0 only
        // matter for the key, which stays off), random K
        wr(ra(c, 8), {16'($random), 8'($random), rmode(round * 9 + c)});
        // CTRL_1: random thresholds and stream, KEY = SRC = 0
        v = $random; wr(ra(c, 9), v & 32'hFFFF_FFF9);
      end
      repeat (4) @(posedge pclk);
      cmp = 1;
      repeat (300) @(posedge pclk);
    end
    cmp = 0; run = 0;
    $display("%s equivalence: %0d pixel clocks x 9 channels, %0d fails",
             fails ? "FAIL" : "ok  ", checks, fails);

    // readback of the AXI registers (outputs are now the registers)
    wr(ra(4, 2), 32'hDEAD_BEEF); rd(ra(4, 2), v);
    if (v !== 32'hDEAD_BEEF) fail("readback"); else $display("ok   readback");

    // ---- 2. colour key -----------------------------------------------------
    for (c = 0; c < 9; c = c + 1) begin
      wr(ra(c, 8), 32'h0000_0004); wr(ra(c, 9), 32'h0);	// mode 4, K 0, no key
    end
    bg = 24'h111111; d5 = 16'h01; d6 = 16'h02; d7 = 16'h03;
    px(24'hAABBCC, 24'h0000FF, 24'h111111, "key off: matrix result");
    // box on HDMI_1: R (chan 0) a0..af, B (chan 3) b0..bf, G (chan 6) c0..cf
    wr(ra(0, 9), 32'hAFA0_0002); wr(ra(3, 9), 32'hBFB0_0002); wr(ra(6, 9), 32'hCFC0_0002);
    px(24'hAABBCC, 24'h0, 24'hAABBCC, "HDMI_1 in box: HDMI_1 pixel");
    px(24'hAABBD0, 24'h0, 24'h111111, "G lane outside: matrix result");
    px(24'h9FBBCC, 24'h0, 24'h111111, "R lane outside: matrix result");
    // only R joins: B and G do not matter
    wr(ra(3, 9), 32'hBFB0_0000); wr(ra(6, 9), 32'hCFC0_0000);
    px(24'hAA0000, 24'h0, 24'hAA0000, "only R joins");
    // invert (chan 0 CTRL_0 [8])
    wr(ra(0, 8), 32'h0000_0104);
    px(24'hAA0000, 24'h0, 24'h111111, "invert, in box: matrix");
    px(24'h500000, 24'h0, 24'h500000, "invert, outside: HDMI_1");
    // fill from stream B (chan 0 CTRL_0 [9])
    wr(ra(0, 8), 32'h0000_0204);
    px(24'hAA0000, 24'h0, 24'h010203, "fill stream B");
    wr(ra(0, 8), 32'h0000_0004);
    // SRC: chan 0 tests HDMI_0's R lane; lo > hi = outside 0x11..0xEF
    wr(ra(0, 9), 32'h10F0_0006);
    px(24'hAA0000, 24'hF80000, 24'hAA0000, "SRC HDMI_0, wrap, R=F8: HDMI_1");
    px(24'hAA0000, 24'h800000, 24'h111111, "SRC HDMI_0, wrap, R=80: matrix");
    // SRC also feeds mode 3 (passthrough): dout0 = {HDMI_0 R, ff}
    wr(ra(0, 8), 32'h0000_0003);
    @(negedge pclk); vid = 24'h5A0000; @(posedge pclk); @(posedge pclk); #1;
    if (o[0] !== 24'h005AFF) begin fail("SRC mode 3"); $display("     got %06x", o[0]); end
    else $display("ok   SRC mode 3 uses HDMI_0");
    // the key keeps the mode of the joined channel: mode 4 K still drives dout0
    wr(ra(0, 8), 32'h1234_0004);
    @(posedge pclk); @(posedge pclk); #1;
    if (o[0] !== 24'h001234) fail("KEY changes the channel's gain"); else $display("ok   KEY leaves the gain");

    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule
