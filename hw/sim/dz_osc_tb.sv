`timescale 1ns/1ps
// dz_osc_tb.sv - DDS pattern engine (hw/rtl/dz_osc/dz_osc2.v + dz_osc_ch.v):
// registers of both channels, the old PINC rule, sequencer shapes tick by
// tick, raster sync, commit at vsync, all output shapes (own sine table)
// against a model, chaining between the channels, external trigger, AWG
// (run by hw/sim/run_dz_osc_tb.sh).
module tb;
  reg clk = 0, rstn = 0; always #5 clk = ~clk;            // FCLK0 100 MHz
  reg pclk = 0; always #6.734 pclk = ~pclk;               // pixel clock, asynchronous
  reg [14:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, arvalid = 0, rready = 0; reg [31:0] wdata = 0;
  wire awready, wready, bvalid, arready, rvalid; wire [1:0] bresp, rresp; wire [31:0] rdata;
  reg ext = 0;
  wire [15:0] wave0, phase0, wave1, phase1; wire [31:0] full0, full1; wire [1:0] sp, wp;
  // small raster: 40 px x 12 lines, hsync px 0-3, vsync lines 0-1, DE px 8-35 on lines 2-11
  reg [5:0] px = 0; reg [3:0] ln = 0; reg hs = 0, vs = 0, de = 0;
  always @(posedge pclk) begin
    px <= (px == 39) ? 0 : px + 1;
    if (px == 39) ln <= (ln == 11) ? 0 : ln + 1;
    hs <= (px < 4); vs <= (ln < 2); de <= (ln >= 2 && px >= 8 && px < 36);
  end
  dz_osc2 dut (.clk(clk), .aresetn(rstn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_wdata(wdata), .s_axi_wstrb(strb),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(1'b1),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .vsync(vs), .hsync(hs), .line_de(de), .ext_trig(ext),
    .wave0(wave0), .phase0(phase0), .phase0_full(full0), .wave1(wave1), .phase1(phase1), .phase1_full(full1),
    .step_pulse(sp), .wrap_pulse(wp));
  // phase history of channel 0: wave0 / phase0 describe hist[2] (3 clocks)
  reg [31:0] hist [0:3];
  always @(posedge clk) begin hist[0] <= dut.ch0.ph; hist[1] <= hist[0]; hist[2] <= hist[1]; hist[3] <= hist[2]; end

  integer fails = 0;
  reg [3:0] strb = 4'hF;
  task wr(input [14:0] a, input [31:0] d); begin @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
    while (!awready) @(posedge clk); @(posedge clk); awvalid <= 0; wvalid <= 0; while (bvalid) @(posedge clk); end endtask
  task rdv(input [14:0] a, output [31:0] v); begin @(posedge clk); araddr <= a; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; v = rdata; rready <= 1; @(posedge clk); rready <= 0; @(posedge clk); end endtask
  task rd(input [14:0] a, input [31:0] want); reg [31:0] v; begin rdv(a, v);
    if (v !== want) begin fails++; $display("FAIL rd %04x = %08x want %08x", a, v, want); end end endtask
  task step(input [14:0] base, input integer i, input [31:0] st, input [31:0] dl, input [31:0] ctl, input [31:0] ph); begin
    wr(base + 15'h100 + 16 * i, st); wr(base + 15'h104 + 16 * i, dl); wr(base + 15'h108 + 16 * i, ctl); wr(base + 15'h10C + 16 * i, ph); end endtask
  // channel 0: the increment after each of n ticks
  task ticks(input integer n, input integer want [0:15], input string name); integer t; begin
    for (t = 0; t < n; t = t + 1) begin
      @(posedge clk); while (!(dut.ch0.tick && (dut.ch0.running || dut.ch0.done))) @(posedge clk);
      @(posedge clk); #1;
      if (dut.ch0.inc !== want[t]) begin fails++; $display("FAIL %s tick %0d: inc %0d want %0d", name, t + 1, dut.ch0.inc, want[t]); end
    end end endtask
  // the model of the sine table (the formula of gen_sine.py) and of all shapes
  reg [15:0] qsin [0:1023];
  integer qi; initial for (qi = 0; qi < 1024; qi = qi + 1)
    qsin[qi] = $rtoi(32767.0 * $sin(2.0 * 3.14159265358979 * (qi + 0.5) / 4096.0) + 0.5);
  function [15:0] sine_of(input [31:0] p); reg [15:0] v; begin
    v = qsin[p[30] ? ~p[29:20] : p[29:20]]; sine_of = p[31] ? -v : v; end endfunction
  function [15:0] shape_of(input [2:0] s, input [31:0] p, input [31:0] pw, input [15:0] awgv);
    case (s)
      3'd0: shape_of = sine_of(p);
      3'd1: shape_of = p[31:16];
      3'd2: shape_of = ~p[31:16];
      3'd3: shape_of = p[31] ? ~p[30:15] : p[30:15];
      3'd4: shape_of = {16{p[31]}};
      3'd5: shape_of = (p < pw) ? 16'hFFFF : 16'h0;
      3'd6: shape_of = awgv;
      default: shape_of = 0;
    endcase
  endfunction
  reg [15:0] awg_m [0:2047];
  integer i, errs;
  reg [31:0] a0, a1, v;
  integer w_sq [0:15], w_rt [0:15], w_os [0:15];
  // a step with RST: the accumulator is 0 at the edge after the step_rst pulse
  reg rst_q = 0; reg [31:0] acc_rst = 32'hFFFF_FFFF; integer n_rst = 0, n_rst0;
  always @(posedge clk) begin rst_q <= dut.ch0.step_rst; if (dut.ch0.step_rst) n_rst <= n_rst + 1; end
  always @(posedge clk) if (rst_q) acc_rst <= dut.ch0.acc;

  initial begin
    repeat (3) @(posedge clk); rstn = 1; repeat (2) @(posedge clk);
    // ---- 1. ID, reset, the old PINC rule, increment; channel 1 at +0x4000 ----
    rd(15'h0028, 32'h444F5343); rd(15'h0000, 32'h8000_0001); rd(15'h0004, 32'h1);
    rd(15'h4028, 32'h444F5343); rd(15'h4000, 32'h8000_0001);
    wr(15'h0000, 32'h0000_1234); rd(15'h0000, 32'h8000_0001);          // no valid bit: ignored
    wr(15'h0000, 32'h8000_1000); repeat (3) @(posedge clk); #1 a0 = dut.ch0.acc; @(posedge clk); #1 a1 = dut.ch0.acc;
    if (a1 - a0 !== 32'h1000) begin fails++; $display("FAIL increment %08x", a1 - a0); end
    rd(15'h0020, 32'h1000); rd(15'h4020, 32'h1);                         // channel 1 untouched
    wr(15'h4000, 32'h8000_0777); rd(15'h4000, 32'h8000_0777); rd(15'h0000, 32'h8000_1000);
    // ---- 2. square A/B on the prescaler ----
    step(0, 0, 100, 0, 3, 0); step(0, 1, 200, 0, 2, 0); wr(15'h000C, 9);
    w_sq = '{100,100,200,200,100,100,100,200,200,100,0,0,0,0,0,0};
    wr(15'h0008, 32'h0000_0101); ticks(10, w_sq, "square");
    // ---- ramp up + triangle: {1000,+10,5} {KEEP,-10,5} ----
    wr(15'h0008, 0); step(0, 0, 1000, 10, 5, 0); step(0, 1, 0, -10, 32'h0100_0005, 0);
    w_rt = '{1010,1020,1030,1040,1040,1030,1020,1010,1000,1000,1010,0,0,0,0,0};
    wr(15'h0008, 32'h0000_0101); ticks(11, w_rt, "triangle");
    // ---- one shot: {500,0,2} {600,0,2}, stop after step 1 ----
    wr(15'h0008, 0); step(0, 0, 500, 0, 2, 0); step(0, 1, 600, 0, 2, 0);
    w_os = '{500,600,600,600,600,0,0,0,0,0,0,0,0,0,0,0};
    wr(15'h0008, 32'h0000_1101); ticks(5, w_os, "one shot");
    rdv(15'h0004, v); if (v[16] !== 0 || v[11:8] !== 1) begin fails++; $display("FAIL one shot status %08x", v); end
    // ---- 3. phase reset at hsync ----
    wr(15'h0008, 32'h0000_0010);
    for (i = 0; i < 3; i = i + 1) begin
      @(posedge clk); while (!dut.hs_e) @(posedge clk); #1;      // hs_e seen at the edge that reset acc
      if (dut.ch0.acc !== 0) begin fails++; $display("FAIL phase reset at hsync: acc %08x", dut.ch0.acc); end
    end
    // ---- line step (cleared at vsync) and frame step ----
    wr(15'h0014, 32'h0100_0000); wr(15'h0018, 32'h0000_0100); wr(15'h0008, 0);
    @(posedge clk); while (!dut.vs_e) @(posedge clk); @(posedge clk); #1 a0 = dut.ch0.frame_off;
    if (dut.ch0.line_off !== 0) begin fails++; $display("FAIL line offset not 0 after vsync"); end
    for (i = 0; i < 3; i = i + 1) begin @(posedge clk); while (!dut.hs_e) @(posedge clk); end
    @(posedge clk); #1 if (dut.ch0.line_off !== 32'h0300_0000) begin fails++; $display("FAIL line offset %08x", dut.ch0.line_off); end
    for (i = 0; i < 2; i = i + 1) begin @(posedge clk); while (!dut.vs_e) @(posedge clk); end
    @(posedge clk); #1 if (dut.ch0.frame_off - a0 !== 32'h200) begin fails++; $display("FAIL frame step %08x", dut.ch0.frame_off - a0); end
    wr(15'h0014, 0); wr(15'h0018, 0);
    // ---- commit at vsync ----
    wr(15'h0008, 32'h0000_4000); @(posedge clk); while (!dut.vs_e) @(posedge clk); repeat (2) @(posedge clk);
    wr(15'h0010, 32'h1234_5678); repeat (5) @(posedge clk);
    if (dut.ch0.a_poff === 32'h1234_5678) begin fails++; $display("FAIL commit: POFF took effect before vsync"); end
    @(posedge clk); while (!dut.vs_e) @(posedge clk); @(posedge clk); #1;
    if (dut.ch0.a_poff !== 32'h1234_5678) begin fails++; $display("FAIL commit: POFF not taken at vsync"); end
    wr(15'h0008, 0); wr(15'h0010, 0); repeat (3) @(posedge clk);
    // ---- 4. shapes, own sine table (free-running phase) ----
    for (i = 0; i < 2048; i = i + 1) awg_m[i] = (i * 31) ^ 16'h5A5A;
    for (i = 0; i < 2048; i = i + 1) wr(15'h2000 + 4 * i, {16'hDEAD, awg_m[i]});
    rd(15'h2000 + 4 * 5, 0);                                         // write-only: reads 0
    wr(15'h001C, 32'h4000_0000); wr(15'h0000, 32'h8123_4567);
    for (i = 0; i < 16; i = i + 1) begin : shapes
      reg [2:0] s; reg flip; integer c;
      s = i[2:0] == 7 ? 0 : i[2:0]; flip = i >= 8;
      wr(15'h0008, {12'd0, flip, s, 16'd0}); repeat (8) @(posedge clk);
      errs = 0;
      for (c = 0; c < 2000; c = c + 1) begin
        @(posedge clk); #1;
        if (wave0 !== (shape_of(s, hist[2], 32'h4000_0000, awg_m[hist[2][31:21]]) ^ {flip, 15'd0})) errs++;
        if (phase0 !== hist[2][31:16]) errs++;
      end
      if (errs) begin fails++; $display("FAIL shape %0d flip %0d: %0d of 2000 clocks wrong", s, flip, errs); end
    end
    if (full0 !== dut.ch0.ph) begin fails++; $display("FAIL phase0_full"); end
    // ---- the sine model against its symmetry: 4096 points over all quadrants ----
    errs = 0;
    for (i = 0; i < 4096; i = i + 1) begin : symmetry
      reg [31:0] p; p = i << 20;
      if (sine_of(p) !== -sine_of(p ^ 32'h8000_0000)) errs++;               // s(x + 180) = -s(x)
      if (sine_of(p) !== sine_of(32'h8000_0000 - p - 32'h0010_0000)) errs++;  // s(180 - x) = s(x)
    end
    if (errs) begin fails++; $display("FAIL sine model symmetry: %0d", errs); end
    // ---- 5. chaining: channel 1 steps on channel 0's step pulses ----
    wr(15'h0008, 0); step(0, 0, 11, 0, 4, 0); step(0, 1, 12, 0, 4, 0); wr(15'h000C, 3);
    step(15'h4000, 0, 7, 0, 1, 0); step(15'h4000, 1, 8, 0, 1, 0);
    wr(15'h4008, 32'h0000_0109);                                       // ch1: tick 4 = other channel step
    wr(15'h0008, 32'h0000_0101);                                       // ch0: prescaler
    for (i = 0; i < 6; i = i + 1) begin
      @(posedge clk); while (!sp[0]) @(posedge clk); repeat (2) @(posedge clk); #1;
      if (dut.ch1.inc !== ((i % 2) ? 7 : 8)) begin fails++; $display("FAIL chain %0d: ch1 inc %0d", i, dut.ch1.inc); end
    end
    // ---- external trigger (channel 1) ----
    wr(15'h0008, 0); wr(15'h4008, 0); wr(15'h4008, 32'h0000_010D); repeat (3) @(posedge clk);
    for (i = 0; i < 4; i = i + 1) begin
      ext = 1; repeat (6) @(posedge clk); ext = 0; repeat (6) @(posedge clk); #1;
      if (dut.ch1.inc !== ((i % 2) ? 7 : 8)) begin fails++; $display("FAIL external tick %0d: inc %0d", i, dut.ch1.inc); end
    end
    // ---- step flag RST + PHASE (channel 0 ticks on channel 1's steps) ----
    wr(15'h4008, 0); wr(15'h0008, 0);
    step(0, 0, 32'h100, 0, 1, 0); step(0, 1, 32'h100, 0, 32'h0200_0001, 32'h8000_0000);
    step(15'h4000, 0, 5, 0, 2, 0); wr(15'h400C, 0);
    n_rst0 = n_rst;
    wr(15'h0008, 32'h0000_0109); wr(15'h4008, 32'h0000_0001);
    repeat (40) @(posedge clk);
    if (n_rst <= n_rst0 || acc_rst !== 0) begin fails++;
      $display("FAIL step RST: pulses %0d acc %08x", n_rst - n_rst0, acc_rst); end
    rd(15'h0110, 0); rd(15'h000C, 3);                                  // step table write-only
    // ---- 6. byte strobes: only the written bytes change ----
    wr(15'h0010, 32'h1111_1111); strb = 4'b0100; wr(15'h0010, 32'hAABB_CCDD); strb = 4'hF;
    rd(15'h0010, 32'h11BB_1111);
    strb = 4'b0111; wr(15'h0000, 32'h8000_0555); strb = 4'hF;          // PINC without byte 3: ignored
    rd(15'h0000, 32'h8123_4567);                                       // unchanged (set in section 4)
    wr(15'h0010, 0);
    // ---- 7. a full table: 16 steps, LEN 0 = 1 tick each, increments 1..16 ----
    wr(15'h0008, 0); wr(15'h4008, 0); wr(15'h000C, 2);
    for (i = 0; i < 16; i = i + 1) step(0, i, i + 1, 0, 0, 0);
    wr(15'h0008, 32'h0000_0F01);
    begin : full
      // each tick: the step advances by 1 (mod 16, LEN 0 = 1 tick) and the
      // increment is that step's START (= step + 1); 40 ticks = 2.5 loops
      integer t; reg [3:0] prev; errs = 0;
      @(posedge clk); while (!(dut.ch0.running)) @(posedge clk);
      @(posedge clk); #1 prev = dut.ch0.step;
      for (t = 0; t < 40; t = t + 1) begin
        @(posedge clk); while (!(dut.ch0.tick)) @(posedge clk); @(posedge clk); #1;
        if (dut.ch0.step !== prev + 4'd1 || dut.ch0.inc !== dut.ch0.step + 1) begin
          errs++; if (errs < 6) $display("  16-step t=%0d step %0d after %0d, inc %0d", t, dut.ch0.step, prev, dut.ch0.inc); end
        prev = dut.ch0.step;
      end
      if (errs) begin fails++; $display("FAIL 16-step table: %0d of 40 ticks wrong", errs); end
    end
    // ---- 8. writes while the sequencer runs (steps change live), then a reset ----
    step(0, 3, 32'h77, 0, 0, 0); repeat (200) @(posedge clk);
    begin : live
      integer t; reg seen; seen = 0;
      for (t = 0; t < 80; t = t + 1) begin @(posedge clk); #1 if (dut.ch0.inc === 32'h77) seen = 1; end
      if (!seen) begin fails++; $display("FAIL live step change not seen"); end
    end
    rstn = 0; repeat (3) @(posedge clk); rstn = 1; repeat (3) @(posedge clk);
    rd(15'h0000, 32'h8000_0001); rd(15'h0008, 0); rd(15'h4000, 32'h8000_0001); rd(15'h001C, 32'h8000_0000);
    @(posedge clk); #1 if (dut.ch0.running !== 0 || dut.ch0.inc !== 1) begin fails++;
      $display("FAIL reset: running %0d inc %0d", dut.ch0.running, dut.ch0.inc); end
    if (fails == 0) $display("dz_osc: ALL PASS"); else $display("dz_osc: %0d FAILURE(S)", fails);
    $finish;
  end
  initial begin #20ms $display("dz_osc: TIMEOUT"); $finish; end
endmodule
