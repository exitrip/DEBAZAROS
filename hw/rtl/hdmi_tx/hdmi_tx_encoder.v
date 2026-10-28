// hdmi_tx_encoder.v - one TMDS channel: video (8b/10b with DC balance),
// control tokens, TERC4 data-island symbols and guard bands.
//
// The video/control part is the 3-stage pipeline of Digilent's rgb2dvi
// TMDS_Encoder.vhd (same algorithm, same latency: output 3 clocks after the
// input), so in DVI use the output is the same as rgb2dvi's. TERC4, guard
// bands and modes: from hdl-util/hdmi tmds_channel.sv (c) 2019 Sameer Puri,
// MIT licence (LICENSE-hdl-util-MIT), HDMI 1.4a sections 5.2.2, 5.2.3, 5.4.
`timescale 1ns / 1ps
module hdmi_tx_encoder #(
    parameter CN = 0              // TMDS channel number 0, 1, 2
) (
    input  wire       clk,
    input  wire [2:0] mode,       // 0 control, 1 video, 2 video guard, 3 data island, 4 island guard
    input  wire [7:0] video,
    input  wire [1:0] ctrl,       // {C1, C0}
    input  wire [3:0] terc4,
    output reg  [9:0] tmds = 10'b1101010100
);
    function [3:0] ones8;
        input [7:0] v;
        ones8 = v[0] + v[1] + v[2] + v[3] + v[4] + v[5] + v[6] + v[7];
    endfunction

    // ---- stage 1 ----------------------------------------------------------
    // no SRLs for the short delay registers: an SRL's long setup time cost
    // the 6.73 ns of 1080p60 (2026-10-28)
    reg [7:0] d1 = 0;
    reg [3:0] n1d1 = 0;
    (* shreg_extract = "no" *) reg [2:0] mode1 = 0;
    (* shreg_extract = "no" *) reg [1:0] ctrl1 = 0;
    (* shreg_extract = "no" *) reg [3:0] terc1 = 0;
    always @(posedge clk) begin
        d1 <= video;
        n1d1 <= ones8(video);
        mode1 <= mode;
        ctrl1 <= ctrl;
        terc1 <= terc4;
    end

    wire [8:0] qm_xor, qm_xnor;
    assign qm_xor[0] = d1[0];
    assign qm_xnor[0] = d1[0];
    genvar i;
    generate
        for (i = 1; i < 8; i = i + 1) begin : g_qm
            assign qm_xor[i]  = qm_xor[i-1] ^ d1[i];
            assign qm_xnor[i] = ~(qm_xnor[i-1] ^ d1[i]);
        end
    endgenerate
    assign qm_xor[8] = 1'b1;
    assign qm_xnor[8] = 1'b0;
    wire [8:0] qm1 = (n1d1 > 4 || (n1d1 == 4 && d1[0] == 1'b0)) ? qm_xnor : qm_xor;

    // ---- stage 2 ----------------------------------------------------------
    reg [8:0] qm2 = 0;
    reg [3:0] n1q2 = 0, n0q2 = 0;
    (* shreg_extract = "no" *) reg [2:0] mode2 = 0;
    (* shreg_extract = "no" *) reg [1:0] ctrl2 = 0;
    (* shreg_extract = "no" *) reg [3:0] terc2 = 0;
    always @(posedge clk) begin
        qm2 <= qm1;
        n1q2 <= ones8(qm1[7:0]);
        n0q2 <= 4'd8 - ones8(qm1[7:0]);
        mode2 <= mode1;
        ctrl2 <= ctrl1;
        terc2 <= terc1;
    end

    reg signed [4:0] cnt3 = 0;       // running disparity
    wire signed [4:0] bias = $signed({1'b0, n0q2}) - $signed({1'b0, n1q2});
    wire balanced = (cnt3 == 0) || (n1q2 == 4);
    wire unbalanced = (cnt3 > 0 && n1q2 > 4) || (cnt3 < 0 && n1q2 < 4);
    reg [9:0] q_video;
    reg signed [4:0] cnt_next;
    always @* begin
        if (balanced) begin
            q_video = qm2[8] ? {1'b0, 1'b1, qm2[7:0]} : {1'b1, 1'b0, ~qm2[7:0]};
            cnt_next = qm2[8] ? cnt3 - bias : cnt3 + bias;
        end else if (unbalanced) begin
            q_video = {1'b1, qm2[8], ~qm2[7:0]};
            cnt_next = cnt3 + $signed({2'b0, qm2[8], 1'b0}) + bias;
        end else begin
            q_video = {1'b0, qm2[8], qm2[7:0]};
            cnt_next = cnt3 - $signed({2'b0, ~qm2[8], 1'b0}) - bias;
        end
    end

    reg [9:0] q_ctrl, q_terc4, q_vguard, q_dguard;
    always @* begin
        case (ctrl2)
            2'b00: q_ctrl = 10'b1101010100;
            2'b01: q_ctrl = 10'b0010101011;
            2'b10: q_ctrl = 10'b0101010100;
            default: q_ctrl = 10'b1010101011;
        endcase
        case (terc2)
            4'b0000: q_terc4 = 10'b1010011100;
            4'b0001: q_terc4 = 10'b1001100011;
            4'b0010: q_terc4 = 10'b1011100100;
            4'b0011: q_terc4 = 10'b1011100010;
            4'b0100: q_terc4 = 10'b0101110001;
            4'b0101: q_terc4 = 10'b0100011110;
            4'b0110: q_terc4 = 10'b0110001110;
            4'b0111: q_terc4 = 10'b0100111100;
            4'b1000: q_terc4 = 10'b1011001100;
            4'b1001: q_terc4 = 10'b0100111001;
            4'b1010: q_terc4 = 10'b0110011100;
            4'b1011: q_terc4 = 10'b1011000110;
            4'b1100: q_terc4 = 10'b1010001110;
            4'b1101: q_terc4 = 10'b1001110001;
            4'b1110: q_terc4 = 10'b0101100011;
            default: q_terc4 = 10'b1011000011;
        endcase
        // video guard band: channels 0 and 2 / channel 1
        q_vguard = (CN == 1) ? 10'b0100110011 : 10'b1011001100;
        // data-island guard band: channels 1, 2 fixed; channel 0 = TERC4 of
        // {1, 1, VSYNC, HSYNC}
        if (CN != 0)
            q_dguard = 10'b0100110011;
        else case (ctrl2)
            2'b00: q_dguard = 10'b1010001110;
            2'b01: q_dguard = 10'b1001110001;
            2'b10: q_dguard = 10'b0101100011;
            default: q_dguard = 10'b1011000011;
        endcase
    end

    // ---- stage 3 ----------------------------------------------------------
    always @(posedge clk) begin
        cnt3 <= (mode2 == 3'd1) ? cnt_next : 5'sd0;
        case (mode2)
            3'd1: tmds <= q_video;
            3'd2: tmds <= q_vguard;
            3'd3: tmds <= q_terc4;
            3'd4: tmds <= q_dguard;
            default: tmds <= q_ctrl;
        endcase
    end
endmodule
