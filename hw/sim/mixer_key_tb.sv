// mixer_key_tb.sv - mixer IP test (run with hw/sim/run_mixer_tb.sh):
//  1. equivalence: the mixer of commit 4e2d1820 (renamed mixer_ref_*) and the
//     new mixer get the same random register writes (all modes, gains,
//     thresholds, stream bits; the new KEY/SRC bits 0) and the same random
//     pixels. All 9 douts must match on every pixel clock, and pix_out must be
//     bg_in one pixel clock later.
//     Mode 1 is pipelined since coreRevision 25: its douts are compared with
//     the reference 7 pixel clocks earlier (coreRevision 26: systolic).
//  4. MATRIX_INT = 1 (a second mixer, dut2, on the same bus and inputs):
//     pix_out = the BD colour matrix model of vid_in and its douts (the
//     douts before the edge, as the old combinational path), 4 clocks
//     later than with bg_in; the key fill 4 clocks later as well.
//  2. colour key: CTRL_1 [1] KEY, [2] SRC per channel; channel 0 CTRL_0 [8]
//     invert, [9] fill from stream B.
//  3. signed mode 1 (coreRevision 25): negative gains, CTRL_1 [3] DIFF,
//     [4] CENTRE, [5] DSIGN, the latency; mode 5 (signed constant).
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


  mixer_v1_0 #(.IN_WIDTH(16), .OUT_WIDTH(24), .MATRIX_INT(0)) dut (
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

  // the mixer with the internal colour matrix (coreRevision 26)
  wire [23:0] o2 [0:8];
  wire [23:0] pout2;
  wire m_awready, m_wready, m_bvalid;
  wire [1:0] m_bresp;
  mixer_v1_0 #(.IN_WIDTH(16), .OUT_WIDTH(24), .MATRIX_INT(1)) dut2 (
    .pix_clk(pclk), .dout0(o2[0]), .dout1(o2[1]), .dout2(o2[2]), .dout3(o2[3]), .dout4(o2[4]),
    .dout5(o2[5]), .dout6(o2[6]), .dout7(o2[7]), .dout8(o2[8]),
    .din0(d0), .din1(d1), .din2(d2), .din3(d3), .din4(d4), .din5(d5), .din6(d6), .din7(d7),
    .bg_in(bg), .vid_in(vid), .pix_out(pout2),
    .s00_axi_aclk(clk), .s00_axi_aresetn(rstn), .s00_axi_awaddr(awaddr), .s00_axi_awprot(3'd0),
    .s00_axi_awvalid(awvalid), .s00_axi_awready(m_awready), .s00_axi_wdata(wdata),
    .s00_axi_wstrb(4'hf), .s00_axi_wvalid(wvalid), .s00_axi_wready(m_wready),
    .s00_axi_bresp(m_bresp), .s00_axi_bvalid(m_bvalid), .s00_axi_bready(1'b1),
    .s00_axi_araddr(10'd0), .s00_axi_arprot(3'd0), .s00_axi_arvalid(1'b0),
    .s00_axi_arready(), .s00_axi_rdata(), .s00_axi_rresp(), .s00_axi_rvalid(),
    .s00_axi_rready(1'b1));

  // the BD colorGainMatrix as a model: lane = (sum of 3 products) [23:16]
  function [23:0] matrix(input [23:0] v, input [23:0] g0, g1, g2, g3, g4, g5, g6, g7, g8);
    reg [23:0] a, b, c;
    begin
      a = v[23:16] * g0 + v[7:0] * g2 + v[15:8] * g1;
      b = v[23:16] * g3 + v[7:0] * g4 + v[15:8] * g5;
      c = v[23:16] * g6 + v[7:0] * g7 + v[15:8] * g8;
      matrix = {a[23:16], b[23:16], c[23:16]};
    end
  endfunction
  // dut2: pix_out at this edge = the model of the inputs taken 4 edges ago
  reg [23:0] mhist [0:4];
  reg [23:0] fhist [0:4];
  reg [23:0] op [0:8];		// dut2 douts before this edge
  reg mcheck = 0, fcheck = 0;
  integer mchecks = 0, q2;
  always @(posedge pclk) begin
    #1;
    if (mcheck && pout2 !== mhist[3]) begin
      fail("internal matrix differs from the model");
      $display("     got %06x want %06x", pout2, mhist[3]);
    end
    if (fcheck && pout2 !== fhist[3]) begin
      fail("internal matrix: key fill not aligned");
      $display("     got %06x want %06x", pout2, fhist[3]);
    end
    if (mcheck || fcheck) mchecks = mchecks + 1;
    for (q2 = 4; q2 > 0; q2 = q2 - 1) begin mhist[q2] = mhist[q2-1]; fhist[q2] = fhist[q2-1]; end
    mhist[0] = matrix(vid, op[0], op[1], op[2], op[3], op[4], op[5], op[6], op[7], op[8]);
    fhist[0] = {d0[7:0], d1[7:0], d2[7:0]};
    for (q2 = 0; q2 < 9; q2 = q2 + 1) op[q2] = o2[q2];
  end

  // register index = chan*10 + n, byte address = index*4
  function [9:0] ra(input integer c, input integer n); ra = (c * 10 + n) * 4; endfunction

  task wr(input [9:0] a, input [31:0] d);
    begin
      @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
      while (!(awready && wready && r_awready && r_wready && m_awready && m_wready)) @(posedge clk);
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

  // equivalence check on every pixel clock while 'cmp' is set; mode 1
  // channels against the reference of 7 pixel clocks before
  reg cmp = 0;
  integer k, q;
  reg [7:0] mode_of [0:8];
  reg [23:0] hist [0:8][0:6];	// hist[k][d] = r[k] d + 1 pixel clocks ago
  reg [23:0] want_k;
  always @(posedge pclk) begin
    #1;
    if (cmp) begin
      for (k = 0; k < 9; k = k + 1) begin
        want_k = mode_of[k] == 8'h01 ? hist[k][6] : r[k];
        if (o[k] !== want_k) begin
          fail("dout differs from the reference");
          $display("     chan %0d mode %02x new %06x ref %06x", k, mode_of[k], o[k], want_k);
        end
      end
      // bg changes on the falling edge: pix_out holds the bg_in of this edge
      if (pout !== bg) fail("pix_out != registered bg_in (key off)");
      checks = checks + 1;
    end
    for (k = 0; k < 9; k = k + 1) begin
      for (q = 6; q > 0; q = q - 1) hist[k][q] = hist[k][q-1];
      hist[k][0] = r[k];
    end
  end

  function [7:0] rmode(input integer x);
    case (x % 14)
      0: rmode = 8'h00; 1: rmode = 8'h01; 2: rmode = 8'h03; 3: rmode = 8'h04;
      4: rmode = 8'h10; 5: rmode = 8'h11; 6: rmode = 8'h12; 7: rmode = 8'h13;
      8: rmode = 8'h20; 9: rmode = 8'h21; 10: rmode = 8'h22; 11: rmode = 8'h23;
      12: rmode = 8'h02; default: rmode = $random;	// unused modes -> default
    endcase
    if (rmode == 8'h05) rmode = 8'h06;	// mode 5 is new (the reference: default)
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

  // mode 1 on channel 0: stream A R, B lanes, din3, din4, stream B R, gain 0,
  // CTRL_1; the other gains as written. Checks dout0 once the pipeline is full.
  task sig(input [15:0] r_a, input [15:0] b_a, input [15:0] i3, input [15:0] i4, input [15:0] r_b,
           input [31:0] g0, input [31:0] c1, input integer u1, input integer u2,
           input [23:0] want, input [255:0] name);
    begin
      wr(ra(0, 0), g0); wr(ra(0, 9), c1);
      @(negedge pclk);
      d0 = r_a; d1 = b_a; d2 = 0; d3 = i3; d4 = i4; d5 = r_b; d6 = 0; d7 = 0;
      repeat (12) @(posedge pclk); #1;
      if (o[0] !== want) begin fail(name); $display("     got %06x want %06x", o[0], want); end
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
        mode_of[c] = rmode(round * 9 + c);
        wr(ra(c, 8), {16'($random), 8'($random), mode_of[c]});
        // CTRL_1: random thresholds and stream; KEY, SRC, DIFF, CENTRE, DSIGN 0
        v = $random; wr(ra(c, 9), v & 32'hFFFF_FFC1);
      end
      repeat (12) @(posedge pclk);	// the mode 1 pipeline fills
      cmp = 1; mcheck = 1;
      repeat (300) @(posedge pclk);
    end
    cmp = 0; mcheck = 0; run = 0;
    $display("%s equivalence: %0d pixel clocks x 9 channels, %0d fails",
             fails ? "FAIL" : "ok  ", checks, fails);
    $display("%s internal matrix = the BD matrix model on %0d pixel clocks",
             fails ? "FAIL" : "ok  ", mchecks);

    // readback of the AXI registers (outputs are now the registers)
    wr(ra(4, 2), 32'hDEAD_BEEF); rd(ra(4, 2), v);
    if (v !== 32'h00AD_BEEF) fail("readback"); else $display("ok   readback (GAIN [31:24] reads 0)");
    wr(ra(4, 9), 32'hDEAD_BEEF); rd(ra(4, 9), v);
    if (v !== 32'hDEAD_BEEF) fail("CTRL readback"); else $display("ok   CTRL readback: all 32 bits");

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

    // ---- 3. signed mode 1, mode 5 ------------------------------------------
    for (n = 0; n < 5; n = n + 1) wr(ra(0, n), 32'h0);
    wr(ra(0, 9), 32'h0); wr(ra(0, 8), 32'h0000_0001);
    sig(16'h40, 16'h00, 16'h0, 16'h0, 16'h00, 32'h00FF_0000, 0, 0, 0, 24'hC00000, "mode 1: gain -1.0 x 0x40");
    sig(16'h40, 16'h00, 16'h0, 16'h0, 16'h00, 32'hFFFF_0000, 0, 0, 0, 24'hC00000, "mode 1: gain [31:24] ignored");
    wr(ra(0, 1), 32'h00FF_0000);	// tap 1 (B lane) -1.0
    sig(16'h80, 16'h30, 16'h0, 16'h0, 16'h00, 32'h0001_0000, 0, 0, 0, 24'h500000, "mode 1: R - B");
    wr(ra(0, 1), 32'h0);
    sig(16'h30, 16'h00, 16'h0, 16'h0, 16'h50, 32'h0001_0000, 32'h8, 0, 0, 24'hE00000, "DIFF: A - B = -0x20");
    sig(16'h40, 16'h00, 16'h0, 16'h0, 16'h00, 32'h0001_0000, 32'h10, 0, 0, 24'hC00000, "CENTRE: 0x40 - 128");
    sig(16'h40, 16'h00, 16'h0, 16'h0, 16'hC0, 32'h0001_0000, 32'h11, 0, 0, 24'h400000, "CENTRE stream B: 0xC0 - 128");
    wr(ra(0, 0), 32'h0); wr(ra(0, 3), 32'h1);
    sig(16'h00, 16'h00, 16'hFFFF, 16'h0, 16'h00, 32'h0, 32'h0, 0, 0, 24'h00FFFF, "din3 unsigned 0xFFFF");
    sig(16'h00, 16'h00, 16'hFFFF, 16'h0, 16'h00, 32'h0, 32'h20, 0, 0, 24'hFFFFFF, "DSIGN: din3 = -1");
    wr(ra(0, 3), 32'h0);
    // latency: a step on din0 reaches dout0 8 pixel clocks after the edge that takes it
    wr(ra(0, 9), 32'h0); wr(ra(0, 0), 32'h0001_0000);
    @(negedge pclk); d0 = 16'h00; repeat (12) @(posedge pclk);
    @(negedge pclk); d0 = 16'h7F;
    // n = the edge (1 = the edge that takes the input) on which dout0 changes
    n = 0;
    while (n < 12 && o[0] !== 24'h7F0000) begin @(posedge pclk); #1; n = n + 1; end
    if (n !== 8) begin fail("mode 1 latency"); $display("     on edge %0d, want 8", n); end
    else $display("ok   mode 1 latency: 8 pixel clocks (the other modes: 1)");
    // mode 5: GAIN_0 [23:0] as a constant
    wr(ra(0, 0), 32'h12FF_8000); wr(ra(0, 8), 32'h0000_0005);
    @(posedge pclk); @(posedge pclk); #1;
    if (o[0] !== 24'hFF8000) begin fail("mode 5"); $display("     got %06x", o[0]); end
    else $display("ok   mode 5: signed constant -0.5");

    // dut2: the key fill (all-pass box on R, B, G) comes 4 clocks later than with bg_in
    for (c = 0; c < 9; c = c + 1) begin wr(ra(c, 8), 32'h0000_0004); wr(ra(c, 9), 32'h0); end
    wr(ra(0, 9), 32'hFF00_0002); wr(ra(3, 9), 32'hFF00_0002); wr(ra(6, 9), 32'hFF00_0002);
    run = 1; repeat (8) @(posedge pclk); fcheck = 1; mchecks = 0;
    repeat (200) @(posedge pclk); fcheck = 0; run = 0;
    $display("%s internal matrix: key fill aligned (%0d pixel clocks)", fails ? "FAIL" : "ok  ", mchecks);
    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule
