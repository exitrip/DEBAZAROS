// hdmi_rx_tb.sv - hdmi_tx -> (dvi2rgb decoder model) -> hdmi_rx loop
// (run with hw/sim/run_hdmi_tx_tb.sh).
//   +mode=0  DVI source: hdmi_rx passes dvi2rgb's outputs through, one clock later
//   +mode=1  HDMI + audio: corrected DE/syncs/pixels == the transmitter input,
//            every audio sample comes out of the loop FIFO (tx_clk, another
//            clock) in order, ACR N/CTS reach the status outputs
// The model of dvi2rgb's TMDS_Decoder keeps its two HDMI faults: DE = 1 for
// every non-control symbol (islands, guard bands) and stale syncs in islands.
`timescale 1ns/1ps
module tb;
  localparam H_ACT = 160, H_FP = 10, H_SYNC = 20, H_TOT = 300;
  localparam V_ACT = 24, V_FP = 2, V_SYNC = 2, V_TOT = 30;
  localparam NCYC = 60 * H_TOT * V_TOT;

  reg clk = 0, tclk = 0;
  always #5 clk = ~clk;
  always #3.7 tclk = ~tclk;       // loop FIFO output clock (another clock)
  reg rst_n = 0;
  integer mode = 0;

  integer h = 0, v = 0;
  reg [23:0] rgb = 0;
  wire de = h < H_ACT && v < V_ACT;
  wire hs = h >= H_ACT + H_FP && h < H_ACT + H_FP + H_SYNC;
  wire vs = v >= V_ACT + V_FP && v < V_ACT + V_FP + V_SYNC;
  always @(posedge clk) begin
    h <= (h == H_TOT - 1) ? 0 : h + 1;
    if (h == H_TOT - 1) v <= (v == V_TOT - 1) ? 0 : v + 1;
    rgb <= $random;
  end

  reg [31:0] ctrl = 0;
  reg [15:0] al = 0, ar = 0;
  reg av = 0;
  integer acnt = 0;
  always @(posedge clk) begin
    av <= 0;
    acnt <= (acnt == 250) ? 0 : acnt + 1;
    if (acnt == 250) begin av <= 1; al <= $random; ar <= $random; end
  end

  wire tp, tn; wire [2:0] dp, dn;
  hdmi_tx tx (.TMDS_Clk_p(tp), .TMDS_Clk_n(tn), .TMDS_Data_p(dp), .TMDS_Data_n(dn),
    .aRst_n(rst_n), .vid_pData(rgb), .vid_pVDE(de), .vid_pHSync(hs), .vid_pVSync(vs),
    .PixelClk(clk), .SerialClk(1'b0), .ctrl(ctrl), .fs_inc(32'd0),
    .aud_l(al), .aud_r(ar), .aud_valid(av));
  wire [29:0] sym = {tx.tmds2, tx.tmds1, tx.tmds0};

  // ---- dvi2rgb TMDS_Decoder model: outputs and pRawSym registered together --
  function automatic [7:0] dec(input [9:0] s);
    reg [7:0] q, d;
    q = s[9] ? ~s[7:0] : s[7:0];
    d[0] = q[0];
    for (int i = 1; i < 8; i++) d[i] = s[8] ? (q[i] ^ q[i-1]) : ~(q[i] ^ q[i-1]);
    return d;
  endfunction
  function automatic int tok(input [9:0] s);
    case (s)
      10'b1101010100: return 0; 10'b0010101011: return 1;
      10'b0101010100: return 2; 10'b1010101011: return 3;
      default: return -1;
    endcase
  endfunction
  reg [23:0] m_data = 0; reg m_vde = 0, m_hs = 0, m_vs = 0; reg [29:0] m_raw = 0;
  always @(posedge clk) begin
    m_raw <= sym;
    if (tok(sym[9:0]) >= 0 && tok(sym[19:10]) >= 0 && tok(sym[29:20]) >= 0) begin
      m_vde <= 0; m_data <= 0;
      m_hs <= tok(sym[9:0]) & 1; m_vs <= (tok(sym[9:0]) >> 1) & 1;
    end else begin
      m_vde <= 1;                                   // also islands, guards
      m_data <= {dec(sym[29:20]), dec(sym[9:0]), dec(sym[19:10])};
    end
  end

  wire [23:0] o_data; wire o_vde, o_hs, o_vs;
  wire rx_pub; wire [1:0] rx_status; wire [31:0] rx_samples, rx_peak; wire [19:0] rx_n, rx_cts;
  wire [15:0] lo_l, lo_r; wire lo_v;
  hdmi_rx rx (.clk(clk), .pLocked(rst_n), .vid_pData(m_data), .vid_pVDE(m_vde),
    .vid_pHSync(m_hs), .vid_pVSync(m_vs), .pRawSym(m_raw),
    .o_pData(o_data), .o_pVDE(o_vde), .o_pHSync(o_hs), .o_pVSync(o_vs),
    .rx_ctrl(32'h1), .rx_pub(rx_pub), .rx_status(rx_status), .rx_samples(rx_samples),
    .rx_peak(rx_peak), .rx_acr_n(rx_n), .rx_acr_cts(rx_cts),
    .tx_clk(tclk), .tx_aud_l(lo_l), .tx_aud_r(lo_r), .tx_aud_valid(lo_v));

  // ---- checks ---------------------------------------------------------------------
  localparam LAT = 14 + 1 + 1;          // tx + decoder model + hdmi_rx
  reg [26:0] hist [0:NCYC];
  reg [26:0] mhist [0:NCYC];
  integer cyc = 0, fails = 0, nvid = 0, nsync = 0;
  task automatic fail(input string m);
    fails++;
    if (fails <= 20) $display("FAIL @%0d: %s", cyc, m);
  endtask
  always @(posedge clk) begin
    if (rst_n) begin
      hist[cyc] = {de, vs, hs, rgb};
      mhist[cyc] = {m_vde, m_vs, m_hs, m_data};
    end
    #1;
    if (rst_n && cyc > 3 * H_TOT * V_TOT) begin
      if (mode == 0) begin
        // DVI: dvi2rgb's outputs, one clock later
        if ({o_vde, o_vs, o_hs, o_data} !== mhist[cyc]) fail("DVI pass-through differs");   // mhist = pre-edge value
        nsync++;
      end else begin
        reg [26:0] in;
        in = hist[cyc - LAT];
        if (o_vde !== in[26]) fail($sformatf("DE %b want %b", o_vde, in[26]));
        if (o_hs !== in[24] || o_vs !== in[25]) fail("sync");
        if (in[26]) begin
          nvid++;
          if (o_data !== in[23:0]) fail($sformatf("pixel %06x want %06x", o_data, in[23:0]));
        end
        nsync++;
      end
    end
    if (rst_n) cyc++;
  end

  // audio: transmitted samples vs the loop FIFO output
  reg [31:0] sent [$];
  integer nrx = 0, synced = 0;
  always @(posedge clk) if (rst_n && av && mode == 1) sent.push_back({ar, al});
  always @(posedge tclk) if (lo_v) begin
    if (!synced) begin
      while (sent.size() > 0 && sent[0] !== {lo_r, lo_l}) void'(sent.pop_front());
      synced = 1;
    end
    if (sent.size() == 0) fail("sample that was not sent");
    else begin
      reg [31:0] w;
      w = sent.pop_front();
      if (w !== {lo_r, lo_l}) fail($sformatf("sample %0d %08x want %08x", nrx, {lo_r, lo_l}, w));
    end
    nrx++;
  end

  initial begin
    if (!$value$plusargs("mode=%d", mode)) mode = 0;
    ctrl = (mode == 1) ? 32'h3 : 32'h0;
    repeat (5) @(posedge clk);
    rst_n = 1;
    wait (cyc == NCYC);
    $display("rx mode %0d: %0d video pixels, %0d sync checks, %0d samples looped (%0d in flight), status %b, N %0d CTS %0d, peak %08x",
             mode, nvid, nsync, nrx, sent.size(), rx_status, rx_n, rx_cts, rx_peak);
    if (mode == 1) begin
      if (nvid < 40 * H_ACT * V_ACT) fail("too few video pixels");
      if (nrx < 1500) fail("too few samples");
      if (sent.size() > 12) fail("samples lost");
      if (rx_n != 6144 || rx_cts != 48 * 251) fail("ACR status");
      if (rx_status != 2'b11) fail("status bits");
    end else if (nrx != 0 || rx_status != 0) fail("audio from a DVI source");
    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule
