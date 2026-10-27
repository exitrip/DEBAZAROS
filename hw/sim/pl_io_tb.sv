// pl_io_tb.sv - test of hw/rtl/pl_io (run with hw/sim/run_pl_io_tb.sh).
// Pins have 10k pull-ups (as on the board); pin 2 (I2S DOUT) is wired to
// pin 3 (I2S DIN) outside. Checks:
//  1. reset: all pins inputs, GPIO readback = pin levels
//  2. every function: the right PS / register signal on the pin, open-drain
//     I2C, input routing (AND / OR rules, idle values)
//  3. I2S: an independent pin decoder (Philips format, 16 in 32, 64 x fs)
//     reads the HDMI_2 samples in order; LRCLK = 48 kHz
//  4. loop HDMI_2 audio -> DOUT -> wire -> DIN -> HDMI_1 audio, sample for
//     sample, with the source 200 ppm fast (bit clock steering on): no
//     underrun after the start, no lost sample
`timescale 1ns/1ps
module tb;
  reg clk = 0, rx_clk = 0, tx_clk = 0, rstn = 0;
  always #5 clk = ~clk;                 // FCLK0 100 MHz
  always #6.734 rx_clk = ~rx_clk;       // HDMI_2 74.25 MHz
  always #6.75 tx_clk = ~tx_clk;        // HDMI_1 ~74.07 MHz (another clock)

  reg [23:0] io_func = 0;
  reg [5:0]  io_out = 0;
  reg [31:0] i2s_ctrl = 0, i2s_inc = 32'd263882791;
  wire [5:0] io_in, po, pt;
  wire [31:0] i2s_status;
  reg  [5:0] ext = 6'b111111;           // external drive, 1 = released
  // pin level: driven by the FPGA, else by the outside world, else pull-up
  wire [5:0] pin;
  genvar k;
  generate for (k = 0; k < 6; k = k + 1) begin : g_pin
    assign pin[k] = !pt[k] ? po[k] : (k == 3 && io_func[11:8] == 4'd13 && io_func[15:12] != 0) ? 1'bx : ext[k];
  end endgenerate
  // the DOUT -> DIN wire between pin 2 and pin 3 (test 3/4 only)
  reg loopwire = 0;
  wire [5:0] pin_i = loopwire ? {pin[5:4], pin[2], pin[2:0]} : pin;

  reg scl_o = 0, scl_t = 1, sda_o = 0, sda_t = 1, sclk_o = 0, sclk_t = 1;
  reg mosi_o = 0, mosi_t = 1, ss_o = 1, ss_t = 1, ss1_o = 1, utx = 1;
  wire scl_i, sda_i, sclk_i, mosi_i, miso_i, ss_i, urx;

  reg [15:0] rl = 0, rr = 0; reg rv = 0;
  wire [15:0] al, ar; wire av;
  reg [15:0] ll = 16'h1111, lr = 16'h2222; reg lv = 0;

  pl_io_core dut (
    .clk(clk), .rstn(rstn), .io_func(io_func), .io_out(io_out), .io_in(io_in),
    .i2s_ctrl(i2s_ctrl), .i2s_inc(i2s_inc), .i2s_status(i2s_status),
    .pin_o(po), .pin_t(pt), .pin_i(pin_i),
    .i2c0_scl_o(scl_o), .i2c0_scl_t(scl_t), .i2c0_sda_o(sda_o), .i2c0_sda_t(sda_t),
    .i2c0_scl_i(scl_i), .i2c0_sda_i(sda_i),
    .spi0_sclk_o(sclk_o), .spi0_sclk_t(sclk_t), .spi0_mosi_o(mosi_o), .spi0_mosi_t(mosi_t),
    .spi0_ss_o(ss_o), .spi0_ss_t(ss_t), .spi0_ss1_o(ss1_o),
    .spi0_sclk_i(sclk_i), .spi0_mosi_i(mosi_i), .spi0_miso_i(miso_i), .spi0_ss_i(ss_i),
    .uart0_tx(utx), .uart0_rx(urx),
    .rx_clk(rx_clk), .rx_l(rl), .rx_r(rr), .rx_valid(rv),
    .tx_clk(tx_clk), .loop_l(ll), .loop_r(lr), .loop_valid(lv),
    .aud_l(al), .aud_r(ar), .aud_valid(av));

  integer fails = 0;
  task automatic chk(input bit c, input string m);
    if (!c) begin fails++; if (fails < 25) $display("FAIL %0s", m); end
  endtask
  task automatic setf(input int p, input int f);
    io_func[4*p +: 4] = f[3:0];
  endtask

  // ---- I2S pin decoder (pin 0 BCLK, pin 1 LRCLK, pin 2 DOUT) ---------------
  reg [31:0] dec_q [$];
  reg prev_b = 0, prev_lr = 0;
  integer bitpos = 0, nfr = 0;
  reg [15:0] sh = 0, dl = 0;
  realtime t_lr = 0, per_lr = 0;
  integer nstart = 0;
  always @(posedge clk) begin
    if (pin[0] && !prev_b && !pt[0]) begin              // BCLK rising
      if (pin[1] !== prev_lr) begin
        bitpos = 0;
        if (pin[1] == 0) begin                           // a new frame
          if (t_lr != 0) per_lr = $realtime - t_lr;
          t_lr = $realtime;
          nstart++;
        end
      end else bitpos = bitpos + 1;
      // bitpos 0 = first rising edge after the LRCLK change = previous LSB
      // slot; MSB at bitpos 1 .. LSB at bitpos 16
      if (bitpos >= 1 && bitpos <= 16) sh = {sh[14:0], pin[2]};
      if (bitpos == 16) begin
        if (pin[1] == 0) dl = sh;
        else begin dec_q.push_back({sh, dl}); nfr++; end
      end
      prev_lr = pin[1];
    end
    prev_b = pin[0];
  end

  // ---- HDMI_2 audio source: 48 kHz + 200 ppm, counting samples ------------
  reg src_on = 0;
  reg [31:0] acc = 0;
  reg [31:0] sent [$];
  integer nsent = 0;
  localparam [31:0] SRC_INC = 32'd2776544 + 32'd555;   // 48 kHz * (1 + 200e-6) at 74.25 MHz
  always @(posedge rx_clk) begin
    rv <= 0;
    if (src_on) begin
      {rv, acc} <= {1'b0, acc} + {1'b0, SRC_INC};
      if ({1'b0, acc} + {1'b0, SRC_INC} > 33'hFFFFFFFF) begin
        rl <= 16'h1000 + nsent[15:0];
        rr <= 16'h8000 - nsent[15:0];
        sent.push_back({16'h8000 - nsent[15:0], 16'h1000 + nsent[15:0]});
        nsent++;
      end
    end
  end

  // ---- HDMI_1 side: samples coming out of the mux --------------------------
  reg [31:0] got [$];
  always @(posedge tx_clk) if (av) got.push_back({ar, al});

  integer i, j, base, ok_dec, ok_loop, und0, und1, n0, lvl, s0, l0;
  realtime t0, per;
  initial begin
    repeat (5) @(posedge clk); rstn = 1; repeat (5) @(posedge clk);

    // ---- 1. reset state ----
    chk(pt === 6'b111111, "reset: all pins are inputs");
    ext = 6'b101101; repeat (4) @(posedge clk);
    chk(io_in === 6'b101101, "GPIO readback = pin levels");
    ext = 6'b111111;
    chk(scl_i && sda_i && urx && !miso_i && ss_i, "idle inputs to the PS");

    // ---- 2. functions ----
    setf(0, 1); setf(1, 1); io_out = 6'b000010; #1;
    chk(pt[1:0] == 2'b00 && pin[1:0] == 2'b10, "GPIO output");
    setf(0, 2); setf(1, 3); #1;                         // I2C on pins 0/1
    chk(pt[0] && pt[1] && scl_i && sda_i, "I2C released: pull-ups, reads 1");
    scl_t = 0; #1; chk(!pt[0] && pin[0] == 0 && scl_i == 0, "I2C SCL low (open drain)");
    scl_t = 1; ext[1] = 0; #1; chk(sda_i == 0, "I2C SDA pulled low outside");
    ext[1] = 1;
    setf(2, 4); setf(3, 5); setf(4, 6); setf(5, 7); #1;   // SPI on 2..5
    sclk_t = 0; mosi_t = 0; ss_t = 0; sclk_o = 1; mosi_o = 1; ss_o = 0; #1;
    chk(pin[2] == 1 && pin[3] == 1 && pin[5] == 0 && pt[4], "SPI SCLK/MOSI/SS out, MISO in");
    ext[4] = 1; #1; chk(miso_i == 1, "SPI MISO = pin");
    ext[4] = 0; #1; chk(miso_i == 0, "SPI MISO follows");
    ext[4] = 1;
    setf(2, 8); setf(3, 9); setf(5, 14); utx = 0; ext[3] = 0; #1;
    chk(!pt[2] && pin[2] == 0 && urx == 0 && !pt[5] && pin[5] == ss1_o, "UART TX/RX, SPI SS1");
    utx = 1; ext[3] = 1; #1; chk(urx == 1, "UART RX idle high");
    io_func = 0; #1; chk(pt === 6'b111111, "all back to inputs");

    // ---- 3./4. I2S: pins 0 BCLK, 1 LRCLK, 2 DOUT, 3 DIN (wired to 2) ----
    setf(0, 10); setf(1, 11); setf(2, 12); setf(3, 13);
    loopwire = 1;
    i2s_ctrl = 32'hF;                    // on, TX = HDMI_2, HDMI_1 = DIN, steering
    src_on = 1;
    #20ms;
    und0 = i2s_status[15:8];             // start-up only
    @(nstart); t0 = t_lr; n0 = nstart; s0 = nsent; l0 = i2s_status[3:0];   // exact frame-start times
    #100ms;                               // steady state, source running
    @(nstart); per = (t_lr - t0) / (nstart - n0);
    $display("window: %0d frames played, %0d samples sent, FIFO level %0d -> %0d", nstart - n0, nsent - s0, l0, i2s_status[3:0]);
    lvl = i2s_status[3:0];
    und1 = i2s_status[15:8];
    src_on = 0;
    #2ms;
    $display("I2S: %0d sent, %0d decoded on the pins, %0d at HDMI_1; steady state: frame %.4f us (source 48 kHz + 200 ppm = 20.8292), FIFO level %0d, underruns start %0d (pre-fill), run %0d",
             nsent, nfr, got.size(), per / 1000.0, lvl, und0, und1 - und0);
    chk(per > 20.820e3 && per < 20.840e3, "LRCLK near the source rate");
    chk(lvl >= 2 && lvl <= 7 && l0 >= 2 && l0 <= 7, "FIFO level inside the steering range");
    chk(und1 == und0, "no underrun in steady state");
    // decoded words: find the first sent sample, then all must follow in order
    // (silence words before the first sample are skipped)
    ok_dec = 0;
    while (dec_q.size() > 0 && dec_q[0] !== sent[0]) void'(dec_q.pop_front());
    for (i = 0; i < dec_q.size() && i < sent.size(); i++)
      if (dec_q[i] === sent[i]) ok_dec++;
      else if (ok_dec + 50 > nsent - 10) ;        // tail (after the source stopped)
      else begin chk(0, $sformatf("decoded word %0d %08x want %08x", i, dec_q[i], sent[i])); break; end
    chk(ok_dec > nsent - 20, $sformatf("decoded %0d of %0d samples in order", ok_dec, nsent));
    ok_loop = 0;
    while (got.size() > 0 && got[0] !== sent[0]) void'(got.pop_front());
    for (i = 0; i < got.size() && i < sent.size(); i++)
      if (got[i] === sent[i]) ok_loop++;
      else begin chk(0, $sformatf("HDMI_1 word %0d %08x want %08x", i, got[i], sent[i])); break; end
    chk(ok_loop > nsent - 20, $sformatf("looped %0d of %0d samples in order", ok_loop, nsent));
    chk(und0 < 8, "few underruns at the start");

    // I2S off: pins back to inputs
    i2s_ctrl = 0; io_func = 0; #1;
    chk(pt === 6'b111111, "I2S off: inputs");
    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule
