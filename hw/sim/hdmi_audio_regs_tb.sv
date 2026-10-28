`timescale 1ns/1ps
// hdmi_audio_regs_tb.sv - AXI-Lite writes/reads of hdmi_audio_regs and the
// receiver-status handshake (run by hw/sim/run_hdmi_tx_tb.sh).
module tb;
  reg clk = 0, rclk = 0, rstn = 0; always #5 clk = ~clk; always #3 rclk = ~rclk;
  reg [12:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, arvalid = 0, rready = 0; reg [31:0] wdata = 0;
  wire awready, wready, bvalid, arready, rvalid; wire [1:0] bresp, rresp; wire [31:0] rdata, txc, txf, rxc, i2c, i2i, t0c; wire [0:0] hpd; wire [23:0] iof; wire [5:0] ioo;
  reg pub = 0, vs = 0; wire j3, j5; wire [0:0] ledr; wire evirq;
  reg j3i = 1, j5i = 1; reg [5:0] ioin = 6'b101010; reg [31:0] ph = 0; always @(posedge clk) ph <= ph + 32'd1000; reg [31:0] smp = 0, hold = 0;
  hdmi_audio_regs dut (.s_axi_aclk(clk), .s_axi_aresetn(rstn), .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid),
    .s_axi_awready(awready), .s_axi_wdata(wdata), .s_axi_wstrb(4'hf), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(1'b1), .s_axi_araddr(araddr), .s_axi_arvalid(arvalid),
    .s_axi_arready(arready), .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .tx_ctrl(txc), .tx0_ctrl(t0c), .hpd2(hpd), .tx_fs_inc(txf), .rx_ctrl(rxc), .rx_pub(pub), .rx_status(2'b11), .rx_samples(hold),
    .rx_peak(32'h12345678), .rx_acr_n(20'd6144), .rx_acr_cts(20'd74250),
    .io_func(iof), .io_out(ioo), .io_in(ioin), .i2s_ctrl(i2c), .i2s_inc(i2i), .i2s_status(32'h0000_0A03),
    .vsync(vs), .j3p4(j3), .j5p4(j5), .led_red(ledr), .j3p3(j3i), .j5p3(j5i), .dds_phase(ph), .ev_irq(evirq));
  integer fails = 0;
  task wr(input [12:0] a, input [31:0] d); begin @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
    while (!awready) @(posedge clk); @(posedge clk); awvalid <= 0; wvalid <= 0; while (bvalid) @(posedge clk); end endtask
  task rd(input [12:0] a, input [31:0] want); begin @(posedge clk); araddr <= a; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; rready <= 1; @(posedge clk); rready <= 0;
    if (rdata !== want) begin fails++; $display("FAIL rd %02x = %08x want %08x", a, rdata, want); end
    @(posedge clk); end endtask
  always @(posedge rclk) begin smp <= smp + 1; if (smp[7:0] == 0) begin hold <= smp; pub <= ~pub; end end
  initial begin
    repeat (3) @(posedge clk); rstn = 1;
    wr(6'h00, 32'h0000_0107); wr(6'h04, 32'd2776544); wr(6'h08, 32'h1);
    rd(6'h00, 32'h0000_0107); rd(6'h04, 32'd2776544); rd(6'h08, 32'h1);
    if (txc !== 32'h107 || txf !== 32'd2776544 || rxc !== 1) begin fails++; $display("FAIL outputs"); end
    rd(6'h3C, 32'h48415544);
    rd(7'h50, 32'd263882791);                      // I2S_INC reset value
    wr(7'h40, 32'hFF_DC_BA98); wr(7'h44, 32'hFF); wr(7'h4C, 32'h7); wr(7'h50, 32'd1234);
    rd(7'h40, 32'h00_DC_BA98); rd(7'h44, 32'h3F); rd(7'h48, 32'h2A); rd(7'h4C, 32'h7);
    rd(7'h50, 32'd1234); rd(7'h54, 32'h0000_0A03);
    if (iof !== 24'hDCBA98 || ioo !== 6'h3F || i2c !== 7 || i2i !== 1234) begin fails++; $display("FAIL I/O outputs"); end
    rd(7'h00, 32'h0000_0107);                      // old registers unchanged
    if (hpd !== 1'b0) begin end   // rx_ctrl = 1 here (loop): HPD still high
    if (hpd !== 1'b1) begin fails++; $display("FAIL HPD not high with RX_CTRL[2] = 0"); end
    wr(7'h08, 32'h5); if (hpd !== 1'b0) begin fails++; $display("FAIL HPD not low with RX_CTRL[2] = 1"); end
    wr(7'h08, 32'h1); if (hpd !== 1'b1) begin fails++; $display("FAIL HPD not back high"); end
    wr(7'h0C, 32'h0000_0205); rd(7'h0C, 32'h0000_0205);   // TX0_CTRL (HDMI_0)
    if (t0c !== 32'h205) begin fails++; $display("FAIL TX0_CTRL output"); end
    // fan pin 4 outputs: reset = optos off (FPGA pins high)
    if (j3 !== 1'b1 || j5 !== 1'b1) begin fails++; $display("FAIL fan outputs not off after reset"); end
    wr(7'h44, 32'h0000_013F); rd(7'h44, 32'h0000_013F);   // J3 on, J5 off
    if (j3 !== 1'b0 || j5 !== 1'b1) begin fails++; $display("FAIL fan J3 on"); end
    wr(7'h44, 32'h0000_0A3F);                              // J5 follows vsync, J3 off
    vs = 0; #1 if (j3 !== 1'b1 || j5 !== 1'b1) begin fails++; $display("FAIL fan vsync low"); end
    vs = 1; #1 if (j3 !== 1'b1 || j5 !== 1'b0) begin fails++; $display("FAIL fan vsync high"); end
    vs = 0;
    rd(7'h44, 32'h0000_0A3F);
    if (ledr !== 1'b0) begin fails++; $display("FAIL LED_RED not 0 after reset"); end
    wr(7'h44, 32'h0000_1000); rd(7'h44, 32'h0000_1000);
    if (ledr !== 1'b1 || j3 !== 1'b1) begin fails++; $display("FAIL LED_RED on"); end
    wr(7'h44, 32'h0);
    // ---- events (page 1) ----
    rd(13'h1000, 32'h45564E54);
    rd(13'h1018, {23'd0, 1'b0, 6'b101010, 2'b11});          // levels: vsync 0, lines, J5 J3 high
    wr(13'h1014, 32'h003);                                  // falling edges of J3, J5
    wr(13'h1010, 32'h104);                                  // rising: line 0, vsync
    wr(13'h100C, 32'h001);                                  // IRQ on J3 only
    j5i = 0; repeat (8) @(posedge clk);
    rd(13'h1008, 32'h002); if (evirq) begin fails++; $display("FAIL ev_irq on a masked event"); end
    begin
      reg [31:0] t0, t1, ts;
      @(posedge clk); araddr <= 13'h1004; arvalid <= 1;
      while (!rvalid) @(posedge clk); arvalid <= 0; t0 = rdata; rready <= 1; @(posedge clk); rready <= 0;
      j3i = 0; repeat (8) @(posedge clk);
      if (!evirq) begin fails++; $display("FAIL ev_irq not set by J3"); end
      @(posedge clk); araddr <= 13'h1020; arvalid <= 1;
      while (!rvalid) @(posedge clk); arvalid <= 0; ts = rdata; rready <= 1; @(posedge clk); rready <= 0;
      if (ts - t0 < 1 || ts - t0 > 20) begin fails++; $display("FAIL TS_J3 %0d clocks after the time read", ts - t0); end
      ioin[0] = 1'b1; repeat (8) @(posedge clk);               // line 0 rising
      ioin[1] = 1'b0; repeat (8) @(posedge clk);               // line 1 falling: not enabled
      rd(13'h1008, 32'h007);
      wr(13'h1008, 32'h001); rd(13'h1008, 32'h006);           // write 1 clears J3 only
      repeat (3) @(posedge clk); if (evirq) begin fails++; $display("FAIL ev_irq after clear"); end
      vs = 1; repeat (8) @(posedge clk); vs = 0;
      rd(13'h1008, 32'h106);
      @(posedge clk); araddr <= 13'h102C; arvalid <= 1;
      while (!rvalid) @(posedge clk); arvalid <= 0; t1 = rdata; rready <= 1; @(posedge clk); rready <= 0;
      @(posedge clk); araddr <= 13'h1030; arvalid <= 1;
      while (!rvalid) @(posedge clk); arvalid <= 0; ts = rdata; rready <= 1; @(posedge clk); rready <= 0;
      // the DDS model adds 1000 per clock and EV_TIME 1 per clock
      if (ts - 1000 * t1 > 3000 && 1000 * t1 - ts > 3000) begin fails++; $display("FAIL DDS phase at vsync %0d vs time %0d", ts, t1); end
    end
    rd(7'h44, 32'h0);                                       // page 0 unchanged
    // ---- J3 hardware PWM ----
    rd(8'h98, 32'h50574D31);
    if (j3 !== 1'b1) begin fails++; $display("FAIL J3 not off before the PWM"); end
    wr(8'h90, 32'd100); wr(8'h94, 32'd30); wr(7'h44, 32'h0000_2800);   // J3 = PWM, J5 = vsync
    begin
      integer lo = 0, i, t;
      repeat (205) @(posedge clk);
      for (i = 0; i < 1000; i++) begin @(posedge clk); if (!j3) lo++; end
      if (lo < 295 || lo > 305) begin fails++; $display("FAIL PWM 30/100: %0d of 1000 clocks opto on", lo); end
      wr(8'h90, 32'h4000_0064); lo = 0;                    // invert: 30 counts pin high
      repeat (205) @(posedge clk);
      for (i = 0; i < 1000; i++) begin @(posedge clk); if (!j3) lo++; end
      if (lo < 695 || lo > 705) begin fails++; $display("FAIL PWM inverted: %0d of 1000 clocks opto on", lo); end
      // vsync lock: period 1000, duty 100; the period restarts at the vsync start
      wr(8'h90, 32'h8000_03E8); wr(8'h94, 32'd100);
      repeat (2537) @(posedge clk);
      while (!j3) @(posedge clk);                          // inside the inactive part
      vs = 1; t = 0;
      #1 if (j5 !== 1'b0) begin fails++; $display("FAIL J5 does not follow vsync"); end
      while (j3 && t < 2000) begin @(posedge clk); t++; end
      if (t < 2 || t > 8) begin fails++; $display("FAIL vsync lock: active part %0d clocks after vsync", t); end
      repeat (20) @(posedge clk); vs = 0;
      rd(8'h90, 32'h8000_03E8); rd(8'h94, 32'd100); rd(7'h44, 32'h0000_2800);
      wr(7'h44, 32'h0); repeat (2) @(posedge clk);
      if (j3 !== 1'b1) begin fails++; $display("FAIL J3 not off after PWM select 0"); end
    end
    repeat (600) @(posedge clk);
    rd(6'h10, 32'h3); rd(6'h18, 32'h12345678); rd(6'h1C, 32'd6144); rd(6'h20, 32'd74250);
    @(posedge clk); araddr <= 6'h14; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; rready <= 1; @(posedge clk); rready <= 0;
    if (rdata[7:0] !== 8'h00) begin fails++; $display("FAIL samples snapshot %08x not taken at a publish", rdata); end
    if (fails) $display("FAILED"); else $display("ALL PASS"); $finish;
  end
endmodule
