// dz_i2s.v - I2S master, 2 channels, 16-bit samples in 32-bit slots
// (BCLK = 64 x fs), Philips format: LRCLK low = left, changes on the BCLK
// falling edge, MSB one BCLK after the LRCLK edge, data changes on falling
// edges and is sampled on rising edges.
//
// Clocking: an NCO on clk toggles BCLK; inc = 2 * 64 * fs * 2^32 / f_clk
// (48 kHz at 100 MHz: 263882791). BCLK jitter = one clk period.
// TX: one stereo word from tx_data ({R, L}) at each frame start (tx_pop);
//     tx_empty -> silence (underruns counted).
// RX: one stereo word per frame on rx_valid ({R, L}).
`timescale 1ns / 1ps
module dz_i2s (
    input  wire        clk,
    input  wire        rst,
    input  wire        on,          // clocks run; off = BCLK/LRCLK/DOUT low
    input  wire [31:0] inc,
    output reg         bclk = 0,
    output reg         lrclk = 0,
    output reg         dout = 0,
    input  wire        din,         // already synchronized to clk
    input  wire [31:0] tx_data,
    input  wire        tx_empty,
    output reg         tx_pop = 0,
    output reg  [31:0] rx_data = 0,
    output reg         rx_valid = 0,
    output reg  [7:0]  underruns = 0
);
    reg [31:0] acc = 0;
    reg        tick = 0;
    always @(posedge clk) {tick, acc} <= on ? {1'b0, acc} + {1'b0, inc} : 33'd0;

    reg [5:0]  cnt = 6'd63;         // BCLK in the frame; [5] = right slot
    reg [15:0] word_l = 0, word_r = 0;
    reg [15:0] sh = 0;              // receive shift register
    reg [15:0] rx_l = 0;
    wire [5:0] cnt_n = cnt + 6'd1;
    wire [4:0] p = cnt_n[4:0];      // bit position in the slot after this edge

    always @(posedge clk) begin
        tx_pop <= 1'b0;
        rx_valid <= 1'b0;
        if (rst || !on) begin
            bclk <= 0; lrclk <= 0; dout <= 0; cnt <= 6'd63;
        end else if (tick) begin
            bclk <= ~bclk;
            if (bclk) begin
                // falling edge: next bit position, LRCLK and DOUT change
                cnt <= cnt_n;
                lrclk <= cnt_n[5];
                if (cnt_n == 6'd0) begin       // frame start: take a word
                    if (!tx_empty) begin
                        word_l <= tx_data[15:0];
                        word_r <= tx_data[31:16];
                        tx_pop <= 1'b1;
                    end else begin
                        word_l <= 0; word_r <= 0;
                        if (underruns != 8'hFF) underruns <= underruns + 8'd1;
                    end
                end
                if (p >= 5'd1 && p <= 5'd16)
                    // word_l/word_r were loaded at position 0 (one edge earlier)
                    dout <= cnt_n[5] ? word_r[16 - p] : word_l[16 - p];
                else
                    dout <= 1'b0;
            end else begin
                // rising edge: sample DIN at bit positions 1..16
                if (cnt[4:0] >= 5'd1 && cnt[4:0] <= 5'd16)
                    sh <= {sh[14:0], din};
                if (cnt[4:0] == 5'd16) begin
                    if (!cnt[5])
                        rx_l <= {sh[14:0], din};
                    else begin
                        rx_data <= {sh[14:0], din, rx_l};
                        rx_valid <= 1'b1;
                    end
                end
            end
        end
    end
endmodule
