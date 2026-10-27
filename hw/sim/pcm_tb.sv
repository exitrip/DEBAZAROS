// pcm_tb.sv - test of the Linux PCM path: hdmi_audio_regs (AXI-Lite) +
// pl_io_core (pacer, BRAM FIFOs, routing). Run with hw/sim/run_pl_io_tb.sh.
// A driver model (like the ALSA driver will do, by polling) keeps three
// playback FIFOs topped up and empties the capture FIFO. Checks:
//  1. HDMI_0 / HDMI_1 audio words = PCM 0 / PCM 1 frames, in order, 48 kHz
//  2. I2S DOUT pins (independent decoder) = PCM 2 frames, in order
//  3. capture: HDMI_2 samples read back from CAP_DATA in order, none lost
//  4. level IRQ (threshold), underrun IRQ + latch + write-1-to-clear, silence
//     on underrun, flush
`timescale 1ns/1ps
module tb;
  reg clk = 0, rx_clk = 0, tx_clk = 0, rstn = 0;
  always #5 clk = ~clk;                 // FCLK0 100 MHz
  always #6.734 rx_clk = ~rx_clk;       // HDMI_2 74.25 MHz
  always #6.75 tx_clk = ~tx_clk;        // output pixel clock

  // ---- AXI-Lite manager -------------------------------------------------------
  reg [7:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, arvalid = 0, rready = 0;
  reg [31:0] wdata = 0;
  wire awready, wready, bvalid, arready, rvalid, irq; wire [1:0] bresp, rresp; wire [31:0] rdata;
  wire [31:0] i2s_ctrl, i2s_inc, i2s_status, cap_head, frames;
  wire [23:0] io_func; wire [5:0] io_out, io_in;
  wire [2:0] pcm_wr; wire [31:0] pcm_wdata; wire [3:0] pcm_run, pcm_flush, xrun; wire cap_pop;
  wire [9:0] lv0, lv1, lv2, lvc;
  hdmi_audio_regs regs (.s_axi_aclk(clk), .s_axi_aresetn(rstn), .s_axi_awaddr(awaddr),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_wdata(wdata), .s_axi_wstrb(4'hf),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid),
    .s_axi_bready(1'b1), .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .tx_ctrl(), .tx0_ctrl(), .tx_fs_inc(), .rx_ctrl(), .hpd2(),
    .io_func(io_func), .io_out(io_out), .io_in(io_in), .i2s_ctrl(i2s_ctrl), .i2s_inc(i2s_inc),
    .i2s_status(i2s_status), .pcm_wr(pcm_wr), .pcm_wdata(pcm_wdata), .pcm_run(pcm_run),
    .pcm_flush(pcm_flush), .cap_pop(cap_pop), .cap_head(cap_head), .pcm_level0(lv0),
    .pcm_level1(lv1), .pcm_level2(lv2), .cap_level(lvc), .pcm_xrun(xrun), .pcm_frames(frames),
    .irq(irq), .rx_pub(1'b0), .rx_status(2'b0), .rx_samples(32'd0), .rx_peak(32'd0),
    .rx_acr_n(20'd0), .rx_acr_cts(20'd0));

  wire [5:0] po, pt;
  wire [5:0] pin;
  genvar k;
  generate for (k = 0; k < 6; k = k + 1) begin : g_pin
    assign pin[k] = !pt[k] ? po[k] : 1'b1;          // 10k pull-ups
  end endgenerate

  reg [15:0] rl = 0, rr = 0; reg rv = 0;
  wire [15:0] al, ar, al0, ar0; wire av, av0;
  pl_io_core dut (
    .clk(clk), .rstn(rstn), .io_func(io_func), .io_out(io_out), .io_in(io_in),
    .i2s_ctrl(i2s_ctrl), .i2s_inc(i2s_inc), .i2s_status(i2s_status),
    .pin_o(po), .pin_t(pt), .pin_i(pin),
    .i2c0_scl_o(1'b0), .i2c0_scl_t(1'b1), .i2c0_sda_o(1'b0), .i2c0_sda_t(1'b1),
    .i2c0_scl_i(), .i2c0_sda_i(),
    .spi0_sclk_o(1'b0), .spi0_sclk_t(1'b1), .spi0_mosi_o(1'b0), .spi0_mosi_t(1'b1),
    .spi0_ss_o(1'b1), .spi0_ss_t(1'b1), .spi0_ss1_o(1'b1),
    .spi0_sclk_i(), .spi0_mosi_i(), .spi0_miso_i(), .spi0_ss_i(),
    .uart0_tx(1'b1), .uart0_rx(),
    .rx_clk(rx_clk), .rx_l(rl), .rx_r(rr), .rx_valid(rv),
    .tx_clk(tx_clk), .loop_l(16'h0), .loop_r(16'h0), .loop_valid(1'b0),
    .aud_l(al), .aud_r(ar), .aud_valid(av), .aud0_l(al0), .aud0_r(ar0), .aud0_valid(av0),
    .pcm_wr(pcm_wr), .pcm_wdata(pcm_wdata), .pcm_run(pcm_run), .pcm_flush(pcm_flush),
    .cap_pop(cap_pop), .cap_head(cap_head), .pcm_level0(lv0), .pcm_level1(lv1),
    .pcm_level2(lv2), .cap_level(lvc), .pcm_xrun(xrun), .pcm_frames(frames));

  integer fails = 0;
  task automatic chk(input bit c, input string m);
    if (!c) begin fails++; if (fails < 25) $display("FAIL %0s", m); end
  endtask
  task automatic wr(input [7:0] a, input [31:0] d);
    @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
    while (!awready) @(posedge clk);
    @(posedge clk); awvalid <= 0; wvalid <= 0;
    while (bvalid) @(posedge clk);
  endtask
  task automatic rd(input [7:0] a, output [31:0] d);
    @(posedge clk); araddr <= a; arvalid <= 1;
    while (!rvalid) @(posedge clk);
    arvalid <= 0; d = rdata; rready <= 1;
    @(posedge clk); rready <= 0;
  endtask

  // frame n of playback stream s (never zero, so silence is visible)
  function automatic [31:0] pat(input int s, input int n);
    return {8'(s + 1), 24'(n)};
  endfunction

  // ---- monitors -----------------------------------------------------------------
  // HDMI outputs: every valid word, with its time
  reg [31:0] q0 [$], q1 [$];
  realtime first0 = 0, first1 = 0;
  always @(posedge tx_clk) begin
    if (av0) q0.push_back({ar0, al0});
    if (av)  q1.push_back({ar, al});
  end
  // I2S pin decoder (pin 0 BCLK, pin 1 LRCLK, pin 2 DOUT; Philips, 16 in 32)
  reg [31:0] dec_q [$];
  reg prev_b = 0, prev_lr = 0;
  integer bitpos = 0;
  reg [15:0] sh = 0, dl = 0;
  always @(posedge clk) begin
    if (pin[0] && !prev_b && !pt[0]) begin
      if (pin[1] !== prev_lr) bitpos = 0; else bitpos = bitpos + 1;
      if (bitpos >= 1 && bitpos <= 16) sh = {sh[14:0], pin[2]};
      if (bitpos == 16) begin
        if (pin[1] == 0) dl = sh; else dec_q.push_back({sh, dl});
      end
      prev_lr = pin[1];
    end
    prev_b = pin[0];
  end
  // HDMI_2 source: 48 kHz samples, counting
  reg src_on = 0;
  reg [31:0] acc = 0;
  integer nsrc = 0;
  always @(posedge rx_clk) begin
    rv <= 0;
    {acc} <= acc + 32'd2776544;                       // 48 kHz at 74.25 MHz
    if (src_on && acc + 32'd2776544 < acc) begin
      {rr, rl} <= {8'hC0, 24'(nsrc)};
      rv <= 1;
      nsrc <= nsrc + 1;
    end
  end

  // ---- driver model ---------------------------------------------------------------
  integer nw [3] = '{0, 0, 0};          // frames written per playback stream
  integer ncap = 0, cap_bad = 0;
  bit [2:0] feed = 3'b111;               // which streams the driver tops up
  task automatic service();
    reg [31:0] d01, d2c, w;
    integer lv [4];
    rd(8'h74, d01); rd(8'h78, d2c);
    lv[0] = d01[9:0]; lv[1] = d01[25:16]; lv[2] = d2c[9:0]; lv[3] = d2c[25:16];
    for (int s = 0; s < 3; s++)
      if (feed[s]) for (int i = lv[s]; i < 480; i++) begin
        wr(s == 0 ? 8'h64 : s == 1 ? 8'h68 : 8'h70, pat(s, nw[s])); nw[s]++;
      end
    for (int i = 0; i < lv[3]; i++) begin
      rd(8'h6C, w);
      if (w !== {8'hC0, 24'(ncap)}) begin
        cap_bad++;
        if (cap_bad < 5) $display("FAIL capture word %0d = %08x", ncap, w);
      end
      ncap++;
    end
  endtask
  task automatic run_for(input realtime t);
    realtime t_end = $realtime + t;
    while ($realtime < t_end) service();
  endtask

  // a queue must hold one stream's frames in order: zeros (silence) only
  // before the first frame; returns the number of frames
  function automatic int in_order(ref reg [31:0] q [$], input int s, input string m);
    int n = 0, i = 0;
    while (i < q.size() && q[i] == 0) i++;
    for (; i < q.size(); i++) begin
      if (q[i] !== pat(s, n)) begin
        chk(0, $sformatf("%0s word %0d = %08x want %08x", m, n, q[i], pat(s, n)));
        return n;
      end
      n++;
    end
    return n;
  endfunction

  reg [31:0] d;
  integer f0, f1, n0, n1, n2;
  initial begin
    repeat (5) @(posedge clk); rstn = 1;
    // I2S on pins 0-2, all three PCM routes on (I2S_CTRL [0] on, [5] [6] [7])
    wr(8'h40, 32'h000_CBA);
    wr(8'h4C, 32'hE1);
    // pre-fill (as ALSA does before start), then run all four streams
    service();
    rd(8'h74, d); chk(d[9:0] == 480 && d[25:16] == 480, $sformatf("pre-fill levels %08x", d));
    rd(8'h84, f0);
    wr(8'h60, 32'hF); src_on = 1;
    q0.delete(); q1.delete(); dec_q.delete();
    run_for(50ms);
    rd(8'h84, f1);
    $display("50 ms: %0d pacer frames, HDMI_0 %0d / HDMI_1 %0d words, I2S %0d words, capture %0d of %0d",
             f1 - f0, q0.size(), q1.size(), dec_q.size(), ncap, nsrc);
    chk(f1 - f0 > 2390 && f1 - f0 < 2410, "pacer 48 kHz");
    n0 = in_order(q0, 0, "HDMI_0"); n1 = in_order(q1, 1, "HDMI_1"); n2 = in_order(dec_q, 2, "I2S");
    chk(n0 > 2380 && n1 > 2380, $sformatf("HDMI frames in order: %0d / %0d", n0, n1));
    chk(n2 > 2380, $sformatf("I2S frames in order: %0d", n2));
    chk(cap_bad == 0 && ncap > nsrc - 20, $sformatf("capture %0d of %0d in order", ncap, nsrc));
    rd(8'h7C, d); chk(d[7:4] == 0, $sformatf("no xrun while fed (IRQ_STATUS %02x)", d[7:0]));
    chk(!irq, "IRQ low with IRQ_EN = 0");

    // level IRQ: PCM 1 threshold 100, the driver stops feeding PCM 1
    wr(8'h88, 32'd100 << 16); wr(8'h80, 32'h02);
    feed = 3'b101;
    begin
      realtime t0 = $realtime;
      while (!irq && $realtime - t0 < 15ms) service();
      rd(8'h74, d);
      chk(irq && d[25:16] <= 100 && d[25:16] > 90, $sformatf("level IRQ (PCM 1 level %0d after %.1f ms)",
          d[25:16], ($realtime - t0) / 1e6));
    end
    feed = 3'b111; service();
    repeat (20) @(posedge clk); chk(!irq, "level IRQ clears after the refill");

    // underrun: the driver stops feeding PCM 0; xrun IRQ enabled
    wr(8'h80, 32'h10); feed = 3'b110; q0.delete();
    run_for(15ms);
    rd(8'h7C, d);
    chk(irq && d[4], $sformatf("underrun IRQ (IRQ_STATUS %02x)", d[7:0]));
    chk(q0.size() > 0 && q0[q0.size() - 1] == 0, "silence on HDMI_0 after the underrun");
    wr(8'h60, 32'hE);                      // stop PCM 0, then clear its latch
    repeat (3000) @(posedge clk);
    wr(8'h7C, 32'h10); rd(8'h7C, d);
    chk(!d[4] && !irq, $sformatf("write-1-to-clear (IRQ_STATUS %02x)", d[7:0]));
    rd(8'h7C, d); chk(d[5:4] == 0, "PCM 1 fed: no underrun");

    // flush: PCM 0 is stopped; fill a little, flush, level 0
    for (int i = 0; i < 10; i++) wr(8'h64, 32'h1234);
    repeat (10) @(posedge clk);
    rd(8'h74, d); chk(d[9:0] == 10, $sformatf("PCM 0 level %0d before flush", d[9:0]));
    wr(8'h60, 32'h10E); repeat (10) @(posedge clk);
    rd(8'h74, d); chk(d[9:0] == 0, $sformatf("PCM 0 level %0d after flush", d[9:0]));
    rd(8'h60, d); chk(d == 32'hE, "flush bits read 0");

    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule
