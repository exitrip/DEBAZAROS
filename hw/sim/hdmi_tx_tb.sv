// hdmi_tx_tb.sv - test of hw/rtl/hdmi_tx (run with hw/sim/run_hdmi_tx_tb.sh).
// A small video mode (160x24 active, 300x30 total) drives the block. The
// testbench decodes the three TMDS channels like a receiver:
//   +mode=0  DVI: output == Digilent rgb2dvi TMDS_Encoder (transliterated
//            below) on every clock, at a fixed offset; pixels and syncs decode.
//   +mode=1  HDMI, no audio: preambles (8) + guard bands (2) before every
//            video period and data island, TERC4 islands of whole packets,
//            BCH ECC of every packet, AVI == upstream hdl-util module, SPD.
//   +mode=2  HDMI + audio from aud_valid strobes: + ACR (N, CTS), Audio
//            Sample packets (order, parity, B flags, channel status), Audio
//            InfoFrame == upstream module.
//   +mode=3  HDMI + internal test tone (fs_inc NCO).
// In every mode: each decoded video pixel and every sync state must equal
// the input LAT clocks earlier.
`timescale 1ns/1ps
module tb;
  localparam H_ACT = 160, H_FP = 10, H_SYNC = 20, H_TOT = 300;
  localparam V_ACT = 24, V_FP = 2, V_SYNC = 2, V_TOT = 30;
  localparam LOOK = 10, LAT = LOOK + 6, DVI_OFF = LAT - 3;   // dig_enc output lags its input by 3
  localparam VIC = 4;
  localparam NCYC = 60 * H_TOT * V_TOT;

  reg clk = 0;
  always #5 clk = ~clk;
  reg rst_n = 0;
  integer mode = 0;

  // ---- video source -------------------------------------------------------
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

  // ---- audio source (mode 2): one sample every 251 clocks (~1.2 per line,
  // like 48 kHz at 720p60: 1.07 per line) --------------------
  reg [31:0] ctrl = 0, fs_inc = 0;
  reg [15:0] al = 0, ar = 0;
  reg av = 0;
  integer acnt = 0;
  always @(posedge clk) begin
    av <= 0;
    acnt <= (acnt == 250) ? 0 : acnt + 1;
    if (acnt == 250) begin av <= 1; al <= al + 16'h0203; ar <= ar - 16'h0111; end
  end

  wire tclk_p, tclk_n;
  wire [2:0] td_p, td_n;
  hdmi_tx #(.LOOK(LOOK)) dut (
    .TMDS_Clk_p(tclk_p), .TMDS_Clk_n(tclk_n), .TMDS_Data_p(td_p), .TMDS_Data_n(td_n),
    .aRst_n(rst_n), .vid_pData(rgb), .vid_pVDE(de), .vid_pHSync(hs), .vid_pVSync(vs),
    .PixelClk(clk), .SerialClk(1'b0), .ctrl(ctrl), .fs_inc(fs_inc),
    .aud_l(al), .aud_r(ar), .aud_valid(av));
  wire [9:0] s0 = dut.tmds0, s1 = dut.tmds1, s2 = dut.tmds2;

  // ---- Digilent TMDS_Encoder.vhd, transliterated (DVI reference) -----------
  wire [9:0] r0, r1, r2;
  dig_enc e0 (.clk(clk), .d(rgb[15:8]),  .c0(hs),   .c1(vs),   .vde(de), .q(r0));
  dig_enc e1 (.clk(clk), .d(rgb[7:0]),   .c0(1'b0), .c1(1'b0), .vde(de), .q(r1));
  dig_enc e2 (.clk(clk), .d(rgb[23:16]), .c0(1'b0), .c1(1'b0), .vde(de), .q(r2));

  // ---- upstream InfoFrame modules (reference) ------------------------------
  logic [23:0] ref_avi_h, ref_aif_h;
  logic [55:0] ref_avi_s [3:0];
  logic [55:0] ref_aif_s [3:0];
  auxiliary_video_information_info_frame #(.VIDEO_ID_CODE(VIC), .IT_CONTENT(1'b1))
    ref_avi (.header(ref_avi_h), .sub(ref_avi_s));
  audio_info_frame ref_aif (.header(ref_aif_h), .sub(ref_aif_s));

  // ---- input history ---------------------------------------------------------
  reg [26:0] hist [0:NCYC];
  reg [29:0] rhist [0:NCYC];
  integer cyc = 0;

  // ---- decoder helpers ---------------------------------------------------------
  function automatic int ctrl_tok(input [9:0] s);   // {C1,C0} or -1
    case (s)
      10'b1101010100: return 0;
      10'b0010101011: return 1;
      10'b0101010100: return 2;
      10'b1010101011: return 3;
      default: return -1;
    endcase
  endfunction
  function automatic int terc4(input [9:0] s);
    case (s)
      10'b1010011100: return 0;  10'b1001100011: return 1;
      10'b1011100100: return 2;  10'b1011100010: return 3;
      10'b0101110001: return 4;  10'b0100011110: return 5;
      10'b0110001110: return 6;  10'b0100111100: return 7;
      10'b1011001100: return 8;  10'b0100111001: return 9;
      10'b0110011100: return 10; 10'b1011000110: return 11;
      10'b1010001110: return 12; 10'b1001110001: return 13;
      10'b0101100011: return 14; 10'b1011000011: return 15;
      default: return -1;
    endcase
  endfunction
  function automatic [7:0] tmds_dec(input [9:0] s);
    reg [7:0] q, d;
    q = s[9] ? ~s[7:0] : s[7:0];
    d[0] = q[0];
    for (int i = 1; i < 8; i++) d[i] = s[8] ? (q[i] ^ q[i-1]) : ~(q[i] ^ q[i-1]);
    return d;
  endfunction
  function automatic [7:0] ecc(input [63:0] bits, input int n);
    reg [7:0] e = 0;
    for (int i = 0; i < n; i++) e = (e >> 1) ^ ((e[0] ^ bits[i]) ? 8'b10000011 : 8'd0);
    return e;
  endfunction

  wire vguard = s0 == 10'b1011001100 && s1 == 10'b0100110011 && s2 == 10'b1011001100;
  wire dguard = s1 == 10'b0100110011 && s2 == 10'b0100110011 &&
                terc4(s0) >= 12;

  // ---- scoreboard ----------------------------------------------------------------
  integer fails = 0, nvid = 0, nsync = 0, ndvi = 0, npkt = 0, necc = 0;
  integer cnt_type [0:255];
  task automatic fail(input string m);
    fails++;
    if (fails <= 25) $display("FAIL @%0d: %s", cyc, m);
  endtask

  typedef enum {S_CTRL, S_VIDEO, S_DI, S_DI_END} st_t;
  st_t st = S_CTRL;
  integer ctrl_run = 0, vpre = 0, dpre = 0, vg = 0, dg = 0, dj = 0, lead_pre = 0, lead_ctrl = 0;
  integer di_islands = 0, di_pk_line = -1;
  reg synced = 0;   // checks start after the first complete video period
  reg [31:0] hb;
  reg [63:0] sb [0:3];

  // audio scoreboard
  reg [47:0] sent [$];
  integer nrx = 0, n_acr = 0, cs_bad = 0, sent_base = 0;
  reg asp_synced = 0;   // the checks start in the middle of the stream
  integer blk = -1, nblk = 0;
  integer run = 0, nruns = 0;   // mode 3: square-wave half periods
  reg [23:0] last_tone = 0;   // IEC 60958 frame in the block (-1 = no B flag yet)
  reg [191:0] cs_l, cs_r;
  integer last_cts = -1;
  always @(posedge clk) if (rst_n && dut.smp_valid && dut.audio_en)
    sent.push_back({dut.smp_r, 8'h00, dut.smp_l, 8'h00});   // 16 bit, MSB-aligned

  task automatic check_packet();
    reg [7:0] t;
    reg [7:0] sum;
    t = hb[7:0];
    npkt++;
    cnt_type[t]++;
    if (ecc({32'd0, hb}, 24) !== hb[31:24]) begin necc++; fail($sformatf("header ECC type %02x", t)); end
    for (int k = 0; k < 4; k++)
      if (ecc(sb[k], 56) !== sb[k][63:56]) begin necc++; fail($sformatf("sub %0d ECC type %02x", k, t)); end
    if (t[7]) begin   // InfoFrame: checksum over header + 28 bytes == 0
      sum = hb[7:0] + hb[15:8] + hb[23:16];
      for (int k = 0; k < 4; k++) for (int b = 0; b < 7; b++) sum += sb[k][8*b +: 8];
      if (sum !== 0) fail($sformatf("InfoFrame %02x checksum %02x", t, sum));
    end
    case (t)
      8'h82: begin
        if (hb[23:0] !== ref_avi_h) fail("AVI header != hdl-util");
        for (int k = 0; k < 4; k++) if (sb[k][55:0] !== ref_avi_s[k]) fail($sformatf("AVI sub %0d != hdl-util", k));
      end
      8'h84: begin
        if (hb[23:0] !== ref_aif_h) fail("Audio InfoFrame header != hdl-util");
        for (int k = 0; k < 4; k++) if (sb[k][55:0] !== ref_aif_s[k]) fail($sformatf("AIF sub %0d != hdl-util", k));
      end
      8'h01: begin
        integer n, cts;
        n = {sb[0][35:32], sb[0][47:40], sb[0][55:48]};
        cts = {sb[0][11:8], sb[0][23:16], sb[0][31:24]};
        n_acr++;
        if (n != 6144) fail($sformatf("ACR N %0d", n));
        if (mode == 2 && cts != 48 * 251) fail($sformatf("ACR CTS %0d, want %0d", cts, 48 * 251));
        if (mode == 3 && (cts < 48 * 251 - 1 || cts > 48 * 251 + 1)) fail($sformatf("ACR CTS %0d", cts));
        last_cts = cts;
        for (int k = 1; k < 4; k++) if (sb[k][55:0] !== sb[0][55:0]) fail("ACR subpackets differ");
      end
      8'h02: begin
        if (hb[11:8] !== 4'b0001) fail("ASP: not 1 sample");
        for (int k = 1; k < 4; k++) if (sb[k][55:0] !== 0) fail("ASP: subpacket 1-3 not empty");
        for (int k = 0; k < 1; k++) begin
          reg [47:0 ] s;
          reg [7:0] fl;
          s = sb[k][47:0];
          fl = sb[k][55:48];
          if (^{fl[3:0], s[23:0]} !== 1'b0) fail("ASP left parity");
          if (^{fl[7:4], s[47:24]} !== 1'b0) fail("ASP right parity");
          // B flag: start of a 192-frame block, exactly every 192 samples
          if (hb[20 + k]) begin
            if (blk >= 0 && blk != 191) fail($sformatf("B flag after %0d frames (want 192)", blk + 1));
            blk = 0;
          end else if (blk >= 0) begin
            blk++;
            if (blk > 191) begin fail("no B flag after 192 frames"); blk = 0; end
          end
          if (blk >= 0) begin
            cs_l[blk] = fl[2];
            cs_r[blk] = fl[6];
          end
          if (mode == 3) begin
            // test tone: L == R == +-0x080000, half period 24 samples
            if (s[23:0] !== s[47:24] || (s[23:0] !== 24'h080000 && s[23:0] !== 24'hF80000))
              fail($sformatf("tone sample %012x", s));
            if (s[23:0] === last_tone) run++;
            else begin
              if (nruns > 1 && run != 24) fail($sformatf("tone half period %0d (want 24)", run));
              nruns++; run = 1; last_tone = s[23:0];
            end
            nrx++;
            sent.delete();
          end else begin
          if (!asp_synced) begin
            // drop the samples sent before the first checked packet
            while (sent.size() > 0 && sent[0] !== s) begin sent.pop_front(); sent_base++; end
            nrx = sent_base;
            asp_synced = 1;
          end
          if (sent.size() == 0) fail("ASP sample that was not sent");
          else begin
            reg [47:0] w;
            w = sent.pop_front();
            if (w !== s) fail($sformatf("ASP sample %0d: got %012x want %012x", nrx, s, w));
          end
          nrx++;
          end
          if (blk == 191) begin
            // consumer, L-PCM, fs 48 kHz (bit 25), channel 1 / 2, 24 bit
            nblk++;
            if (cs_l[39:0] !== 40'h02_02_10_00_04) begin cs_bad++; fail($sformatf("channel status L %010x", cs_l[39:0])); end
            if (cs_r[39:0] !== 40'h02_02_20_00_04) begin cs_bad++; fail($sformatf("channel status R %010x", cs_r[39:0])); end
          end
        end
      end
      8'h00: ;
      default: fail($sformatf("unknown packet type %02x", t));
    endcase
  endtask

  always @(posedge clk) begin
    if (rst_n) begin
      hist[cyc] = {de, vs, hs, rgb};
      rhist[cyc] = {r2, r1, r0};
    end
    #1;
    if (rst_n && cyc > LAT + 2 * H_TOT * V_TOT) begin
      reg [26:0] in;
      in = hist[cyc - LAT];
      // DVI: same symbols as Digilent rgb2dvi
      if (mode == 0) begin
        ndvi++;
        if ({s2, s1, s0} !== rhist[cyc - DVI_OFF])
          fail($sformatf("DVI symbols %03x %03x %03x != rgb2dvi %03x %03x %03x",
                         s2, s1, s0, rhist[cyc - DVI_OFF][29:20], rhist[cyc - DVI_OFF][19:10], rhist[cyc - DVI_OFF][9:0]));
      end
      case (st)
        S_CTRL, S_DI_END: begin
          if (ctrl_tok(s0) >= 0 && ctrl_tok(s1) >= 0 && ctrl_tok(s2) >= 0) begin
            if (st == S_DI_END && dg != 2) fail($sformatf("trailing island guard %0d", dg));
            st = S_CTRL;
            if (in[26]) fail("control symbol during DE");
            if (ctrl_tok(s0) != {in[25], in[24]}) fail("sync in control period");
            nsync++;
            if (ctrl_tok(s1) == 1 && ctrl_tok(s2) == 0) begin vpre++; if (dpre) fail("mixed preamble"); end
            else if (ctrl_tok(s1) == 1 && ctrl_tok(s2) == 1) begin dpre++; if (vpre) fail("mixed preamble"); end
            else if (ctrl_tok(s1) == 0 && ctrl_tok(s2) == 0) begin
              if (vpre || dpre) fail("preamble interrupted");
              ctrl_run++;
            end else fail("bad control token on ch1/ch2");
            vg = 0; dg = 0;
            if (vpre == 1 || dpre == 1) lead_ctrl = ctrl_run;
          end else if (st == S_DI_END && dguard) begin
            dg++;
            if (dg > 2) fail("trailing guard > 2");
          end else if (vguard && mode != 0) begin
            vg++;
            if (synced && vpre != 8) fail($sformatf("video preamble %0d (want 8)", vpre));
          end else if (dguard && mode != 0 && dpre == 8) begin
            dg++;
            if (dg == 2) begin st = S_DI; dj = -1; end   // -1: this guard symbol
          end else begin
            // first video pixel
            if (synced && mode != 0 && vg != 2) fail($sformatf("video guard %0d (want 2), preamble %0d", vg, vpre));
            if (synced && mode != 0 && lead_ctrl < 4) fail($sformatf("control period before preamble %0d (< 4)", lead_ctrl));
            st = S_VIDEO;
          end
          if (st == S_CTRL && dg == 0 && vg == 0 && !(ctrl_tok(s1) == 0 && ctrl_tok(s2) == 0) && 0) ;
          if (st == S_VIDEO) begin vpre = 0; dpre = 0; ctrl_run = 0; vg = 0; end
        end
        S_DI: ;
        S_VIDEO: ;
      endcase
      if (st == S_VIDEO) begin
        if (ctrl_tok(s0) >= 0 && ctrl_tok(s1) >= 0 && ctrl_tok(s2) >= 0) begin
          st = S_CTRL; ctrl_run = 1; synced = 1;
          if (in[26]) fail("video period ended early");
        end else begin
          nvid++;
          if (!in[26]) fail("video symbol outside DE");
          if ({tmds_dec(s2), tmds_dec(s0), tmds_dec(s1)} !== in[23:0])
            fail($sformatf("pixel %06x != %06x", {tmds_dec(s2), tmds_dec(s0), tmds_dec(s1)}, in[23:0]));
        end
      end else if (st == S_DI && dj < 0) begin
        dj = 0;
      end else if (st == S_DI) begin
        if (dj > 0 && dj % 32 == 0 && dguard) begin
          st = S_DI_END; dg = 1; di_islands++;
          if (di_pk_line < 0) di_pk_line = dj / 32;
          else if (di_pk_line != dj / 32) fail($sformatf("packets per island %0d != %0d", dj / 32, di_pk_line));
          vpre = 0; dpre = 0; ctrl_run = 0;
        end else begin
          int t0, t1, t2, j;
          t0 = terc4(s0); t1 = terc4(s1); t2 = terc4(s2);
          if (t0 < 0 || t1 < 0 || t2 < 0) fail("non-TERC4 symbol in data island");
          if (in[26]) fail("data island during DE");
          if (t0[1:0] != {in[25], in[24]}) fail("sync in data island");
          if (!t0[3]) fail("ch0 bit 3 = 0 in data island");
          nsync++;
          j = dj % 32;
          hb[j] = t0[2];
          for (int k = 0; k < 4; k++) begin
            sb[k][2 * j] = t1[k];
            sb[k][2 * j + 1] = t2[k];
          end
          dj++;
          if (dj % 32 == 0) check_packet();
        end
      end
    end
    if (rst_n) cyc++;
  end

  initial begin
    if (!$value$plusargs("mode=%d", mode)) mode = 0;
    for (int k = 0; k < 256; k++) cnt_type[k] = 0;
    case (mode)
      0: ctrl = 0;
      1: ctrl = 32'h1;                 // AVI select 0 = VIC 4
      2: ctrl = 32'h3;
      default: begin
        ctrl = 32'h7;
        fs_inc = 32'd17111423;          // 2^32 / 251
      end
    endcase
    repeat (5) @(posedge clk);
    rst_n = 1;
    wait (cyc == NCYC);
    $display("mode %0d: %0d video pixels, %0d sync checks, %0d DVI symbol compares, %0d islands (%0d packets each), %0d packets: ACR %0d ASP %0d AVI %0d AIF %0d SPD %0d null %0d; %0d audio samples received (%0d sent, %0d still buffered)",
             mode, nvid, nsync, ndvi, di_islands, di_pk_line, npkt, cnt_type[1], cnt_type[2],
             cnt_type[8'h82], cnt_type[8'h84], cnt_type[8'h83], cnt_type[0], nrx, nrx + sent.size(), sent.size());
    if (nvid < 40 * H_ACT * V_ACT) fail("too few video pixels");
    if (mode == 0 && (npkt || di_islands)) fail("data islands in DVI mode");
    if (mode != 0 && cnt_type[8'h82] < 20) fail("AVI InfoFrames missing");
    if (mode == 1 && (cnt_type[1] || cnt_type[2] || cnt_type[8'h84])) fail("audio packets without audio");
    if (mode >= 2 && (cnt_type[1] < 20 || cnt_type[2] < 1500 || cnt_type[8'h84] < 20)) fail("audio packets missing");
    if (mode >= 2 && sent.size() > 8) fail("audio samples left behind");
    if (mode == 3 && nruns < 50) fail("too few tone half periods");
    if (mode >= 2 && nblk < 2) fail("fewer than 2 channel-status blocks");
    if (mode >= 2) $display("  %0d channel-status blocks checked, %0d ACR packets, last CTS %0d", nblk, n_acr, last_cts);
    if (fails) $display("FAILED %0d", fails); else $display("ALL PASS");
    $finish;
  end
endmodule

// Digilent rgb2dvi TMDS_Encoder.vhd (3 pipeline stages), for comparison
module dig_enc (input clk, input [7:0] d, input c0, input c1, input vde, output reg [9:0] q);
  reg [7:0] d1; reg [3:0] n1d1; reg c0_1, c1_1, vde_1, c0_2, c1_2, vde_2;
  reg [8:0] qm2; reg [3:0] n1q2, n0q2; reg signed [4:0] cnt3 = 0;
  function [3:0] ones(input [7:0] x); ones = x[0]+x[1]+x[2]+x[3]+x[4]+x[5]+x[6]+x[7]; endfunction
  reg [8:0] x1, xn1, qm1;
  always @* begin
    x1[0] = d1[0]; xn1[0] = d1[0];
    for (int i = 1; i < 8; i++) begin x1[i] = x1[i-1] ^ d1[i]; xn1[i] = ~(xn1[i-1] ^ d1[i]); end
    x1[8] = 1; xn1[8] = 0;
    qm1 = (n1d1 > 4 || (n1d1 == 4 && d1[0] == 0)) ? xn1 : x1;
  end
  wire bal = cnt3 == 0 || n1q2 == 4;
  wire nbal = (cnt3 > 0 && n1q2 > 4) || (cnt3 < 0 && n1q2 < 4);
  wire signed [4:0] bias = $signed({1'b0, n0q2}) - $signed({1'b0, n1q2});
  reg [9:0] qo; reg signed [4:0] cn;
  always @* begin
    if (!vde_2) begin
      case ({c1_2, c0_2}) 0: qo = 10'b1101010100; 1: qo = 10'b0010101011; 2: qo = 10'b0101010100; default: qo = 10'b1010101011; endcase
      cn = 0;
    end else if (bal && !qm2[8]) begin qo = {1'b1, 1'b0, ~qm2[7:0]}; cn = cnt3 + bias; end
    else if (bal) begin qo = {1'b0, 1'b1, qm2[7:0]}; cn = cnt3 - bias; end
    else if (nbal) begin qo = {1'b1, qm2[8], ~qm2[7:0]}; cn = cnt3 + $signed({2'b0, qm2[8], 1'b0}) + bias; end
    else begin qo = {1'b0, qm2[8], qm2[7:0]}; cn = cnt3 - $signed({2'b0, ~qm2[8], 1'b0}) - bias; end
  end
  always @(posedge clk) begin
    d1 <= d; n1d1 <= ones(d); c0_1 <= c0; c1_1 <= c1; vde_1 <= vde;
    qm2 <= qm1; n1q2 <= ones(qm1[7:0]); n0q2 <= 8 - ones(qm1[7:0]); c0_2 <= c0_1; c1_2 <= c1_1; vde_2 <= vde_1;
    cnt3 <= cn; q <= qo;
  end
endmodule
