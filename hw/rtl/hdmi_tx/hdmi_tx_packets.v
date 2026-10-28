// hdmi_tx_packets.v - data-island packets for ONE audio format: 48 kHz,
// 2 channels, 16-bit L-PCM (all media is pre-rendered to it). Output: the
// 9-bit symbol of each island pixel (header bit + 2 x 4 subpacket bits).
//   AVI InfoFrame, Audio InfoFrame: constant, from hdmi_tx_rom.v (generated
//     by gen_rom.py, ECC included), like the EDID ROM of dvi2rgb
//   Audio Clock Regeneration: N = 6144, CTS measured (pixel clocks per 48
//     samples); 4 equal subpackets
//   Audio Sample: ONE stereo sample per packet (subpacket 0; 1-3 empty), so
//     one BCH engine serves both dynamic packets
//   Null
// Packet rules, channel status and ECC: ported from hdl-util/hdmi (c) 2019
// Sameer Puri, MIT licence (LICENSE-hdl-util-MIT); HDMI 1.4a sections 5.2.3.4,
// 5.3.3, 5.3.4, 7.2; IEC 60958-3.
`timescale 1ns / 1ps
module hdmi_tx_packets (
    input  wire        clk,
    input  wire        rst,
    input  wire        audio_en,
    input  wire [1:0]  avi_sel,      // AVI VIC: 0 = 4 (720p60), 1 = 34 (1080p30), 2 = 16 (1080p60), 3 = none
    input  wire        field_end,    // pulse once or twice per frame
    input  wire        pkt_en,       // first pixel of a packet slot (one clock early)
    input  wire        period,       // data-island packet pixels
    input  wire        smp_valid,    // one stereo sample
    input  wire [15:0] smp_l,
    input  wire [15:0] smp_r,
    output wire [8:0]  packet_data
);
    // ---- pixel counter in the packet ---------------------------------------
    reg [4:0] counter = 0;
    always @(posedge clk)
        counter <= (rst || !period) ? 5'd0 : counter + 5'd1;

    // ---- sample FIFO, 4 deep (LUTRAM) ----------------------------------------
    reg [31:0] fifo [0:3];
    reg [2:0]  wp = 0, rp = 0;
    wire       empty = wp == rp, full = (wp - rp) == 3'd4;

    // ---- ACR: CTS = pixel clocks per N/128 = 48 samples ---------------------
    reg [19:0] cts_cnt = 0, cts = 0;
    reg [5:0]  acr_smp = 0;
    reg        acr_pending = 0;
    wire       acr_done = smp_valid && acr_smp == 6'd47;

    localparam T_NULL = 3'd0, T_ACR = 3'd1, T_ASP = 3'd2, T_AVI = 3'd3, T_AIF = 3'd4;
    reg [2:0] ptype = T_NULL;
    // take decisions in the pkt_en clock (a late clear would also clear a
    // flag that is set again in that clock)
    wire take_acr = pkt_en && audio_en && acr_pending;
    wire take_asp = pkt_en && audio_en && !empty && !acr_pending;

    always @(posedge clk) begin
        if (smp_valid && audio_en && !full)
            fifo[wp[1:0]] <= {smp_r, smp_l};
        if (rst || !audio_en) begin
            wp <= 0; rp <= 0;
            cts_cnt <= 0; acr_smp <= 0; acr_pending <= 0;
        end else begin
            if (smp_valid && !full) wp <= wp + 3'd1;
            if (take_asp) rp <= rp + 3'd1;
            cts_cnt <= cts_cnt + 20'd1;
            if (smp_valid) begin
                acr_smp <= acr_done ? 6'd0 : acr_smp + 6'd1;
                if (acr_done) begin
                    cts <= cts_cnt + 20'd1;
                    cts_cnt <= 0;
                end
            end
            if (acr_done) acr_pending <= 1'b1;
            else if (take_acr) acr_pending <= 1'b0;
        end
    end

    // ---- packet picker: InfoFrames at least once per two fields --------------
    reg        avi_sent = 0, aif_sent = 0;
    reg [31:0] asp = 0;          // the sample being sent {R, L}
    reg [7:0]  frame = 0;        // IEC 60958 frame number of that sample, 0..191
    reg [7:0]  frame_next = 0;
    always @(posedge clk) begin
        if (rst) begin
            ptype <= T_NULL;
            avi_sent <= 0; aif_sent <= 0;
            frame_next <= 0;
        end else begin
            if (field_end) begin
                avi_sent <= 0; aif_sent <= 0;
            end
            if (pkt_en) begin
                if (take_acr)
                    ptype <= T_ACR;
                else if (take_asp) begin
                    ptype <= T_ASP;
                    asp <= fifo[rp[1:0]];
                    frame <= frame_next;
                    frame_next <= (frame_next == 8'd191) ? 8'd0 : frame_next + 8'd1;
                end else if (audio_en && !aif_sent) begin
                    ptype <= T_AIF;
                    aif_sent <= 1'b1;
                end else if (!avi_sent) begin
                    ptype <= T_AVI;
                    avi_sent <= 1'b1;
                end else
                    ptype <= T_NULL;
            end
        end
    end

    // ---- dynamic packets: header + subpacket 0 --------------------------------
    // IEC 60958 channel status, bit 0 first: consumer, L-PCM, no copyright
    // assertion, 48 kHz ([27:24] = 0010 as hdl-util), channel 1/2 ([23:20]),
    // 16 bit in a 20-bit maximum ([35:32] = 0010)
    localparam [39:0] CS_L = {4'b0000, 4'b0010, 2'b00, 2'b00, 4'b0010, 4'd1, 4'd0, 8'd0, 2'b00, 3'b000, 1'b1, 1'b0, 1'b0};
    localparam [39:0] CS_R = {4'b0000, 4'b0010, 2'b00, 2'b00, 4'b0010, 4'd2, 4'd0, 8'd0, 2'b00, 3'b000, 1'b1, 1'b0, 1'b0};
    wire cl = (frame < 8'd40) ? CS_L[frame[5:0]] : 1'b0;
    wire cr = (frame < 8'd40) ? CS_R[frame[5:0]] : 1'b0;
    wire [23:0] smp24_l = {asp[15:0], 8'h00}, smp24_r = {asp[31:16], 8'h00};
    // {P, C, U, V} right, left (V = U = 0; P = even parity), then R, L
    wire [55:0] asp_sub = {^{cr, smp24_r}, cr, 2'b00, ^{cl, smp24_l}, cl, 2'b00, smp24_r, smp24_l};
    wire [23:0] asp_hdr = {3'b000, (frame == 8'd0), 8'h00, 4'b0001, 8'h02};
    wire [19:0] n_val = 20'd6144;
    wire [55:0] acr_sub = {n_val[7:0], n_val[15:8], {4'd0, n_val[19:16]},
                           cts[7:0], cts[15:8], {4'd0, cts[19:16]}, 8'd0};
    wire        is_acr = ptype == T_ACR;
    wire [23:0] hdr  = is_acr ? 24'h000001 : asp_hdr;
    wire [55:0] sub  = is_acr ? acr_sub : asp_sub;

    // BCH(64,56) / BCH(32,24), x^8 + x^7 + x^6 + 1, LSB first
    function [7:0] next_ecc;
        input [7:0] ecc;
        input b;
        next_ecc = (ecc >> 1) ^ ((ecc[0] ^ b) ? 8'b10000011 : 8'd0);
    endfunction
    reg  [7:0] par_s = 0, par_h = 0;
    // The bits leave in order (2 subpacket bits + 1 header bit per clock):
    // shift registers instead of 56:1 / 24:1 index muxes (2026-10-28, for
    // 6.73 ns). They load in the first packet clock (counter 0), which uses
    // sub[1:0] / hdr[0] directly; ptype and the sample change in that clock.
    reg  [55:0] sub_sh = 0;
    reg  [23:0] hdr_sh = 0;
    wire [1:0]  sb = (counter == 5'd0) ? sub[1:0] : sub_sh[1:0];
    wire        hb = (counter == 5'd0) ? hdr[0] : hdr_sh[0];
    always @(posedge clk) begin
        sub_sh <= ((counter == 5'd0) ? sub : sub_sh) >> 2;
        hdr_sh <= ((counter == 5'd0) ? hdr : hdr_sh) >> 1;
    end
    always @(posedge clk)
        if (rst || !period || counter == 5'd31) begin
            par_s <= 0; par_h <= 0;
        end else if (counter < 5'd28) begin
            par_s <= next_ecc(next_ecc(par_s, sb[0]), sb[1]);
            if (counter < 5'd24) par_h <= next_ecc(par_h, hb);
        end
    // bits 0..55 = subpacket, 56..63 = par_s; header 0..23, then par_h
    wire be = (counter < 5'd28) ? sb[0] : par_s[{counter[1:0], 1'b0}];
    wire bo = (counter < 5'd28) ? sb[1] : par_s[{counter[1:0], 1'b1}];
    wire bh = (counter < 5'd24) ? hb : par_h[counter[2:0]];
    wire rep = is_acr;              // ACR: subpackets 1-3 = 0; ASP: empty
    wire [8:0] dyn = {rep & bo, rep & bo, rep & bo, bo, rep & be, rep & be, rep & be, be, bh};

    // ---- constant packets ---------------------------------------------------------
    wire [8:0] rom_data;
    hdmi_tx_rom rom (.addr({ptype == T_AVI ? {1'b0, avi_sel} : 3'd4, counter}), .data(rom_data));

    assign packet_data = (ptype == T_AVI || ptype == T_AIF) ? rom_data :
                         (ptype == T_ACR || ptype == T_ASP) ? dyn : 9'd0;
endmodule
