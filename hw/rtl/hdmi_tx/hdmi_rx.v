// hdmi_rx.v - HDMI receive side after dvi2rgb (DEBAZAROS fork with pRawSym):
// corrects the video timing for HDMI sources and extracts the audio.
//
// dvi2rgb decodes every symbol that is not a control token as video, and it
// keeps the last control-token syncs during data islands. With an HDMI
// source that gives DE = 1 in every data island and guard band, and HSYNC
// edges inside an island get lost. This block classifies each pixel from the
// raw symbols, like an HDMI receiver:
//   video preamble (8 x CTL0) + 2 guard symbols -> video until a control token
//   island preamble (CTL0 + CTL2) + 2 guard -> packets of 32 pixels + 2 guard
//   a data symbol without a preamble -> video (DVI source: same as before)
// Outputs: dvi2rgb's pixels with the corrected DE; syncs from the control
// tokens, inside islands from the TERC4 bits of channel 0. One clock later
// than dvi2rgb's outputs.
//
// Audio: ONE format, 2-ch 16-bit L-PCM (the EDID offers only 48 kHz 16 bit).
// Packets with a bad BCH ECC or a non-TERC4 symbol are dropped. Audio Sample
// packets give up to 4 stereo samples; ACR packets give N and CTS. The
// samples go (rx_ctrl[0] = loop) through an async FIFO into the transmitter
// clock domain (tx_clk), for hdmi_tx aud_l/aud_r/aud_valid.
// Status for hdmi_audio_regs: hold registers + rx_pub toggle every 2^16 clocks.
`timescale 1ns / 1ps
module hdmi_rx (
    input  wire        clk,            // dvi2rgb PixelClk
    input  wire        pLocked,        // dvi2rgb pLocked
    input  wire [23:0] vid_pData,      // dvi2rgb outputs (kAddBUFG = false)
    input  wire        vid_pVDE,
    input  wire        vid_pHSync,
    input  wire        vid_pVSync,
    input  wire [29:0] pRawSym,        // {ch2, ch1, ch0} 10-bit symbols
    output reg  [23:0] o_pData = 0,
    output reg         o_pVDE = 0,
    output reg         o_pHSync = 0,
    output reg         o_pVSync = 0,

    input  wire [31:0] rx_ctrl,        // [0] loop to tx, [1] clear peaks (any clock)
    output reg         rx_pub = 0,
    output reg  [1:0]  rx_status = 0,
    output reg  [31:0] rx_samples = 0,
    output reg  [31:0] rx_peak = 0,
    output reg  [19:0] rx_acr_n = 0,
    output reg  [19:0] rx_acr_cts = 0,

    output wire [15:0] rx_l,           // received samples in this clock domain
    output wire [15:0] rx_r,           // (pl_io: I2S output), one per rx_valid
    output wire        rx_valid,
    output wire        rx_clk_out,     // = clk, for blocks outside HDMI_2

    input  wire        tx_clk,         // hdmi_tx PixelClk
    output reg  [15:0] tx_aud_l = 0,
    output reg  [15:0] tx_aud_r = 0,
    output reg         tx_aud_valid = 0
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] lock_s = 0;
    always @(posedge clk) lock_s <= {lock_s[0], pLocked};
    wire rst = ~lock_s[1];

    wire [9:0] s0 = pRawSym[9:0], s1 = pRawSym[19:10], s2 = pRawSym[29:20];

    function [2:0] ctl;                    // {valid, C1, C0}
        input [9:0] s;
        case (s)
            10'b1101010100: ctl = 3'b100;
            10'b0010101011: ctl = 3'b101;
            10'b0101010100: ctl = 3'b110;
            10'b1010101011: ctl = 3'b111;
            default:        ctl = 3'b000;
        endcase
    endfunction
    function [4:0] terc4;                  // {valid, nibble}
        input [9:0] s;
        case (s)
            10'b1010011100: terc4 = 5'h10; 10'b1001100011: terc4 = 5'h11;
            10'b1011100100: terc4 = 5'h12; 10'b1011100010: terc4 = 5'h13;
            10'b0101110001: terc4 = 5'h14; 10'b0100011110: terc4 = 5'h15;
            10'b0110001110: terc4 = 5'h16; 10'b0100111100: terc4 = 5'h17;
            10'b1011001100: terc4 = 5'h18; 10'b0100111001: terc4 = 5'h19;
            10'b0110011100: terc4 = 5'h1A; 10'b1011000110: terc4 = 5'h1B;
            10'b1010001110: terc4 = 5'h1C; 10'b1001110001: terc4 = 5'h1D;
            10'b0101100011: terc4 = 5'h1E; 10'b1011000011: terc4 = 5'h1F;
            default:        terc4 = 5'h00;
        endcase
    endfunction

    wire [2:0] c0 = ctl(s0), c1 = ctl(s1), c2 = ctl(s2);
    wire [4:0] t0 = terc4(s0), t1 = terc4(s1), t2 = terc4(s2);
    wire is_ctl = c0[2] & c1[2] & c2[2];
    wire vpre = is_ctl && c1[1:0] == 2'b01 && c2[1:0] == 2'b00;
    wire dpre = is_ctl && c1[1:0] == 2'b01 && c2[1:0] == 2'b01;
    wire dguard = s1 == 10'b0100110011 && s2 == 10'b0100110011;

    // ---- period state machine -------------------------------------------------
    localparam S_CTL = 3'd0, S_VGRD = 3'd1, S_VID = 3'd2, S_DGRD = 3'd3, S_DATA = 3'd4, S_TRAIL = 3'd5;
    reg [2:0] st = S_CTL;
    reg [3:0] pre_n = 0;      // length of the preamble run just before this symbol
    reg       pre_di = 0;     // that run is an island preamble
    reg [1:0] gcnt = 0;       // guard symbols consumed in this guard state
    reg [9:0] dj = 0;         // packet pixels so far in this island
    reg [2:0] nst;
    always @* begin
        nst = st;
        case (st)
            S_CTL:   nst = (pre_n >= 4'd6) ? (pre_di ? S_DGRD : S_VGRD) : S_VID;
            S_VGRD:  if (gcnt == 2'd2) nst = S_VID;
            S_DGRD:  if (gcnt == 2'd2) nst = S_DATA;
            S_DATA:  if (dj[4:0] == 5'd0 && dj != 0 && dguard) nst = S_TRAIL;
            S_TRAIL: if (gcnt == 2'd2) nst = S_CTL;
            default: ;
        endcase
        if (is_ctl) nst = S_CTL;      // a control token always ends a period
    end
    wire data_px = (nst == S_DATA);   // this symbol is a packet pixel
    wire [4:0] j = (st == S_DATA) ? dj[4:0] : 5'd0;

    always @(posedge clk) begin
        if (rst) begin
            st <= S_CTL; pre_n <= 0; gcnt <= 0; dj <= 0;
        end else begin
            st <= nst;
            if (vpre || dpre) begin
                if (pre_n != 0 && pre_di == dpre) begin
                    if (pre_n != 4'd15) pre_n <= pre_n + 4'd1;
                end else begin
                    pre_n <= 4'd1;
                    pre_di <= dpre;
                end
            end else
                pre_n <= 0;
            gcnt <= (nst != st) ? 2'd1 : (gcnt == 2'd3 ? gcnt : gcnt + 2'd1);
            if (data_px) dj <= (st == S_DATA) ? dj + 10'd1 : 10'd1;
        end
    end

    // ---- video outputs ------------------------------------------------------------
    reg hs_q = 0, vs_q = 0;
    wire in_island = !is_ctl && t0[4] &&
                     (nst == S_DGRD || nst == S_DATA || nst == S_TRAIL || st == S_TRAIL);
    wire hs_n = is_ctl ? c0[0] : in_island ? t0[0] : hs_q;
    wire vs_n = is_ctl ? c0[1] : in_island ? t0[1] : vs_q;
    wire vde_n = (nst == S_VID);
    always @(posedge clk) begin
        hs_q <= hs_n; vs_q <= vs_n;
        o_pHSync <= hs_n;
        o_pVSync <= vs_n;
        o_pVDE <= vde_n & vid_pVDE;
        o_pData <= vde_n ? vid_pData : 24'd0;
    end

    // ---- packets ------------------------------------------------------------------
    reg [31:0] hdr = 0;
    reg [63:0] sb0 = 0, sb1 = 0, sb2 = 0, sb3 = 0;
    reg [7:0]  ph = 0, ps0 = 0, ps1 = 0, ps2 = 0, ps3 = 0;
    reg        bad = 0, done = 0;
    function [7:0] next_ecc;
        input [7:0] ecc;
        input b;
        next_ecc = (ecc >> 1) ^ ((ecc[0] ^ b) ? 8'b10000011 : 8'd0);
    endfunction
    function [7:0] ecc2;                 // two bits, b[0] first
        input [7:0] ecc;
        input [1:0] b;
        ecc2 = next_ecc(next_ecc(ecc, b[0]), b[1]);
    endfunction
    wire [7:0] ph_i = (j == 0) ? 8'd0 : ph, ps0_i = (j == 0) ? 8'd0 : ps0,
               ps1_i = (j == 0) ? 8'd0 : ps1, ps2_i = (j == 0) ? 8'd0 : ps2,
               ps3_i = (j == 0) ? 8'd0 : ps3;
    always @(posedge clk) begin
        done <= 1'b0;
        if (data_px) begin
            bad <= ((j == 0) ? 1'b0 : bad) | ~(t0[4] & t1[4] & t2[4]);
            if (j < 5'd24) ph <= next_ecc(ph_i, t0[2]);
            if (j < 5'd28) begin
                ps0 <= ecc2(ps0_i, {t2[0], t1[0]}); ps1 <= ecc2(ps1_i, {t2[1], t1[1]});
                ps2 <= ecc2(ps2_i, {t2[2], t1[2]}); ps3 <= ecc2(ps3_i, {t2[3], t1[3]});
            end
            hdr[j] <= t0[2];
            sb0[{j, 1'b0}] <= t1[0]; sb0[{j, 1'b1}] <= t2[0];
            sb1[{j, 1'b0}] <= t1[1]; sb1[{j, 1'b1}] <= t2[1];
            sb2[{j, 1'b0}] <= t1[2]; sb2[{j, 1'b1}] <= t2[2];
            sb3[{j, 1'b0}] <= t1[3]; sb3[{j, 1'b1}] <= t2[3];
            if (j == 5'd31) done <= ~rst;
        end
    end
    // after the last pixel: header and subpacket ECC
    wire hdr_ok = !bad && hdr[31:24] == ph;
    wire [3:0] sub_ok = {sb3[63:56] == ps3, sb2[63:56] == ps2, sb1[63:56] == ps1, sb0[63:56] == ps0};

    // ---- status registers (declared before use) ------------------------------------
    reg [19:0] acr_n = 0, acr_cts = 0;
    reg [31:0] nsmp = 0;
    reg [15:0] pk_l = 0, pk_r = 0, tick = 0;
    reg        islands = 0, audio = 0;
    (* ASYNC_REG = "TRUE" *) reg [2:0] clr_s = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] loop_s = 0;
    wire pub_tick = tick == 16'hFFFF;

    // ---- audio samples and ACR --------------------------------------------------------
    reg [3:0]  pend = 0;               // samples of the last good packet still to send
    reg [63:0] q0 = 0, q1 = 0, q2 = 0, q3 = 0;
    reg        smp_valid = 0;
    reg [15:0] smp_l = 0, smp_r = 0;
    always @(posedge clk) begin
        smp_valid <= 1'b0;
        if (done && hdr_ok) begin
            if (hdr[7:0] == 8'h02) begin
                pend <= hdr[11:8] & sub_ok;
                q0 <= sb0; q1 <= sb1; q2 <= sb2; q3 <= sb3;
            end
            if (hdr[7:0] == 8'h01 && sub_ok[0]) begin
                acr_n <= {sb0[35:32], sb0[47:40], sb0[55:48]};
                acr_cts <= {sb0[11:8], sb0[23:16], sb0[31:24]};
            end
        end else if (pend != 0) begin
            // 16-bit samples are the top of the 24-bit field: L [23:8], R [47:32]
            smp_valid <= 1'b1;
            if (pend[0]) begin smp_l <= q0[23:8]; smp_r <= q0[47:32]; pend[0] <= 1'b0; end
            else if (pend[1]) begin smp_l <= q1[23:8]; smp_r <= q1[47:32]; pend[1] <= 1'b0; end
            else if (pend[2]) begin smp_l <= q2[23:8]; smp_r <= q2[47:32]; pend[2] <= 1'b0; end
            else begin smp_l <= q3[23:8]; smp_r <= q3[47:32]; pend[3] <= 1'b0; end
        end
        if (rst) pend <= 0;
    end

    assign rx_l = smp_l;
    assign rx_r = smp_r;
    assign rx_valid = smp_valid;
    assign rx_clk_out = clk;

    // ---- status: live values, published every 2^16 clocks ---------------------------
    wire [15:0] al = smp_l[15] ? -smp_l : smp_l, ar = smp_r[15] ? -smp_r : smp_r;
    always @(posedge clk) begin
        tick <= tick + 16'd1;
        clr_s <= {clr_s[1:0], rx_ctrl[1]};
        loop_s <= {loop_s[0], rx_ctrl[0]};
        if (done && hdr_ok) islands <= 1'b1;
        if (smp_valid) begin
            audio <= 1'b1;
            nsmp <= nsmp + 32'd1;
            if (al > pk_l) pk_l <= al;
            if (ar > pk_r) pk_r <= ar;
        end
        if (clr_s[2] ^ clr_s[1]) begin pk_l <= 0; pk_r <= 0; end
        if (pub_tick) begin
            rx_status <= {audio, islands};
            rx_samples <= nsmp;
            rx_peak <= {pk_r, pk_l};
            rx_acr_n <= acr_n;
            rx_acr_cts <= acr_cts;
            rx_pub <= ~rx_pub;
            islands <= 1'b0;
            audio <= 1'b0;
        end
    end

    // ---- loop: async FIFO (8 x 32 bit, gray pointers) into tx_clk -------------------
    function [3:0] bin2gray;
        input [3:0] b;
        bin2gray = b ^ (b >> 1);
    endfunction
    function [3:0] gray2bin;
        input [3:0] g;
        gray2bin = {g[3], g[3] ^ g[2], g[3] ^ g[2] ^ g[1], g[3] ^ g[2] ^ g[1] ^ g[0]};
    endfunction
    reg [31:0] fifo [0:7];
    reg [3:0]  wp = 0, wg = 0;           // write pointer (binary, gray), rx clock
    reg [3:0]  rp = 0, rg = 0;           // read pointer, tx clock
    (* ASYNC_REG = "TRUE" *) reg [3:0] rg_s1 = 0, rg_s2 = 0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] wg_s1 = 0, wg_s2 = 0;
    wire [3:0] rp_w = gray2bin(rg_s2);   // read pointer seen by the write side
    wire full = (wp[3] != rp_w[3]) && (wp[2:0] == rp_w[2:0]);
    always @(posedge clk) begin
        {rg_s2, rg_s1} <= {rg_s1, rg};
        if (smp_valid && loop_s[1] && !full) begin
            fifo[wp[2:0]] <= {smp_r, smp_l};
            wp <= wp + 4'd1;
            wg <= bin2gray(wp + 4'd1);
        end
    end
    wire empty = (rg == wg_s2);
    always @(posedge tx_clk) begin
        {wg_s2, wg_s1} <= {wg_s1, wg};
        tx_aud_valid <= 1'b0;
        if (!empty) begin
            {tx_aud_r, tx_aud_l} <= fifo[rp[2:0]];
            tx_aud_valid <= 1'b1;
            rp <= rp + 4'd1;
            rg <= bin2gray(rp + 4'd1);
        end
    end
endmodule
