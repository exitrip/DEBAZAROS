// pl_io_core.v - function select for the 6 user I/O lines (PL_KEY0-5, header
// P1) + I2S master + audio routing. No tri-state here (pin_o / pin_t /
// pin_i); pl_io.v adds the IOBUFs. Registers: hdmi_audio_regs 0x40-0x54.
//
// func (4 bits per pin, func[4n+3:4n] = pin n):
//   0 GPIO input (reset default: output off, as before)   8 UART0 TXD (PS)
//   1 GPIO output, value io_out[n]                         9 UART0 RXD (PS)
//   2 I2C0 SCL (PS, open drain; 10k pull-ups on board)    10 I2S BCLK
//   3 I2C0 SDA (PS, open drain)                           11 I2S LRCLK
//   4 SPI0 SCLK (PS master)                               12 I2S DOUT
//   5 SPI0 MOSI                                           13 I2S DIN
//   6 SPI0 MISO (input)                                   14 SPI0 SS1 (2nd CS)
//   7 SPI0 SS0 (CS)                                       15 = 0 (reserved)
// An input function on several pins: SCL/SDA/RXD = AND (idle high), MISO and
// DIN = OR. Unmapped inputs read idle (SCL/SDA/RXD 1, MISO/DIN 0).
// Caution: a button pressed while its line drives high shorts the output.
//
// i2s_ctrl: [0] I2S on, [1] DOUT plays the HDMI_2 input audio (else silence),
// [2] HDMI_1 audio = I2S DIN (else the HDMI_2 loop), [3] steer the bit clock
// by the TX FIFO level (follows the HDMI_2 source clock), [4] HDMI_0 audio =
// I2S DIN (else the HDMI_2 loop). Same source on both outputs = the same
// samples on both; each hdmi_tx has its own test tone (TX_CTRL / TX0_CTRL).
// Clock domains: clk = FCLK0 (registers, I2S), rx_clk = HDMI_2 pixel clock,
// tx_clk = HDMI_1 pixel clock.
`timescale 1ns / 1ps
module pl_io_core (
    input  wire        clk,
    input  wire        rstn,
    input  wire [23:0] io_func,
    input  wire [5:0]  io_out,
    output wire [5:0]  io_in,          // synchronized to clk
    input  wire [31:0] i2s_ctrl,
    input  wire [31:0] i2s_inc,
    output wire [31:0] i2s_status,     // [3:0] TX FIFO level, [15:8] underruns
    // pins (pl_io adds IOBUFs)
    output reg  [5:0]  pin_o,
    output reg  [5:0]  pin_t,          // 1 = input (high impedance)
    input  wire [5:0]  pin_i,
    // PS7 EMIO
    input  wire        i2c0_scl_o, i2c0_scl_t, i2c0_sda_o, i2c0_sda_t,
    output wire        i2c0_scl_i, i2c0_sda_i,
    input  wire        spi0_sclk_o, spi0_sclk_t, spi0_mosi_o, spi0_mosi_t,
    input  wire        spi0_ss_o, spi0_ss_t, spi0_ss1_o,
    output wire        spi0_sclk_i, spi0_mosi_i, spi0_miso_i, spi0_ss_i,
    input  wire        uart0_tx,
    output wire        uart0_rx,
    // audio
    input  wire        rx_clk,
    input  wire [15:0] rx_l, rx_r,      // HDMI_2 input audio (rx_clk)
    input  wire        rx_valid,
    input  wire        tx_clk,
    input  wire [15:0] loop_l, loop_r,  // hdmi_rx loop FIFO output (tx_clk)
    input  wire        loop_valid,
    output reg  [15:0] aud_l = 0, aud_r = 0,   // to HDMI_1's hdmi_tx (tx_clk)
    output reg         aud_valid = 0,
    output reg  [15:0] aud0_l = 0, aud0_r = 0, // to HDMI_0's hdmi_tx (tx_clk)
    output reg         aud0_valid = 0
);
    wire rst = ~rstn;
    wire bclk, lrclk, dout;

    // ---- pin outputs --------------------------------------------------------
    integer n, m;
    reg [3:0] f, g;
    always @* begin
        for (n = 0; n < 6; n = n + 1) begin
            f = io_func[4*n +: 4];
            pin_o[n] = 1'b0;
            pin_t[n] = 1'b1;
            case (f)
                4'd1:  begin pin_o[n] = io_out[n];   pin_t[n] = 1'b0; end
                4'd2:  begin pin_o[n] = i2c0_scl_o;  pin_t[n] = i2c0_scl_t; end
                4'd3:  begin pin_o[n] = i2c0_sda_o;  pin_t[n] = i2c0_sda_t; end
                4'd4:  begin pin_o[n] = spi0_sclk_o; pin_t[n] = spi0_sclk_t; end
                4'd5:  begin pin_o[n] = spi0_mosi_o; pin_t[n] = spi0_mosi_t; end
                4'd7:  begin pin_o[n] = spi0_ss_o;   pin_t[n] = spi0_ss_t; end
                4'd8:  begin pin_o[n] = uart0_tx;    pin_t[n] = 1'b0; end
                4'd10: begin pin_o[n] = bclk;        pin_t[n] = ~i2s_ctrl[0]; end
                4'd11: begin pin_o[n] = lrclk;       pin_t[n] = ~i2s_ctrl[0]; end
                4'd12: begin pin_o[n] = dout;        pin_t[n] = ~i2s_ctrl[0]; end
                4'd14: begin pin_o[n] = spi0_ss1_o;  pin_t[n] = 1'b0; end
                default: ;
            endcase
        end
    end

    // ---- pin inputs to the PS and the I2S receiver ---------------------------
    reg scl_i, sda_i, rxd_i, miso_i, din_i;
    always @* begin
        scl_i = 1'b1; sda_i = 1'b1; rxd_i = 1'b1; miso_i = 1'b0; din_i = 1'b0;
        for (m = 0; m < 6; m = m + 1) begin
            g = io_func[4*m +: 4];
            if (g == 4'd2)  scl_i  = scl_i  & pin_i[m];
            if (g == 4'd3)  sda_i  = sda_i  & pin_i[m];
            if (g == 4'd9)  rxd_i  = rxd_i  & pin_i[m];
            if (g == 4'd6)  miso_i = miso_i | pin_i[m];
            if (g == 4'd13) din_i  = din_i  | pin_i[m];
        end
    end
    assign i2c0_scl_i = scl_i;
    assign i2c0_sda_i = sda_i;
    assign uart0_rx = rxd_i;
    assign spi0_miso_i = miso_i;
    assign spi0_sclk_i = 1'b0;          // master only
    assign spi0_mosi_i = 1'b0;
    assign spi0_ss_i = 1'b1;            // no other master: no mode fault

    (* ASYNC_REG = "TRUE" *) reg [5:0] in_s1 = 0, in_s2 = 0;
    (* ASYNC_REG = "TRUE" *) reg [1:0] din_s = 0;
    always @(posedge clk) begin
        {in_s2, in_s1} <= {in_s1, pin_i};
        din_s <= {din_s[0], din_i};
    end
    assign io_in = in_s2;

    // ---- I2S TX: HDMI_2 audio -> FIFO -> I2S (clk) ---------------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] txsrc_s = 0;
    always @(posedge rx_clk) txsrc_s <= {txsrc_s[0], i2s_ctrl[1]};
    wire [31:0] txf_data;
    wire        txf_empty, tx_pop;
    wire [3:0]  txf_level;
    dz_async_fifo #(.W(32), .AW(3)) txf (
        .wr_clk(rx_clk), .wr_en(rx_valid & txsrc_s[1]), .wr_data({rx_r, rx_l}), .wr_full(),
        .rd_clk(clk), .rd_en(tx_pop), .rd_data(txf_data), .rd_empty(txf_empty),
        .rd_level(txf_level));

    // pre-fill: after switching on or after an underrun, send silence until
    // the FIFO holds 4 words, so the steering starts in the middle of its range
    reg prime = 1'b1;
    reg [7:0] und_q = 0;
    always @(posedge clk) begin
        und_q <= underruns;
        if (rst || !i2s_ctrl[0] || underruns != und_q) prime <= 1'b1;
        else if (txf_level >= 4'd4) prime <= 1'b0;
    end

    // bit clock steering: about 124 ppm per word of FIFO level away from 4
    wire signed [4:0]  lvl_err = $signed({1'b0, txf_level}) - 5'sd4;
    wire signed [31:0] steer = i2s_ctrl[3] ? ($signed(lvl_err) <<< 15) : 32'sd0;
    reg [31:0] inc_q = 0;
    always @(posedge clk) inc_q <= i2s_inc + steer;

    wire [31:0] rx_word;
    wire        rx_word_valid;
    wire [7:0]  underruns;
    dz_i2s i2s (
        .clk(clk), .rst(rst), .on(i2s_ctrl[0]), .inc(inc_q),
        .bclk(bclk), .lrclk(lrclk), .dout(dout), .din(din_s[1]),
        .tx_data(txf_data), .tx_empty(txf_empty | prime), .tx_pop(tx_pop),
        .rx_data(rx_word), .rx_valid(rx_word_valid), .underruns(underruns));
    assign i2s_status = {16'd0, underruns, 4'd0, txf_level};

    // ---- I2S RX -> FIFO -> HDMI_1 audio (tx_clk) ------------------------------
    wire [31:0] rxf_data;
    wire        rxf_empty;
    (* ASYNC_REG = "TRUE" *) reg [1:0] rxsrc_s = 0, rxsrc0_s = 0;
    wire use_i2s = rxsrc_s[1], use_i2s0 = rxsrc0_s[1];
    dz_async_fifo #(.W(32), .AW(3)) rxf (
        .wr_clk(clk), .wr_en(rx_word_valid), .wr_data(rx_word), .wr_full(),
        .rd_clk(tx_clk), .rd_en(use_i2s | use_i2s0), .rd_data(rxf_data), .rd_empty(rxf_empty),
        .rd_level());
    always @(posedge tx_clk) begin
        rxsrc_s <= {rxsrc_s[0], i2s_ctrl[2]};
        rxsrc0_s <= {rxsrc0_s[0], i2s_ctrl[4]};
        if (use_i2s) begin
            aud_valid <= !rxf_empty;
            {aud_r, aud_l} <= rxf_data;
        end else begin
            aud_valid <= loop_valid;
            aud_l <= loop_l;
            aud_r <= loop_r;
        end
        if (use_i2s0) begin
            aud0_valid <= !rxf_empty;
            {aud0_r, aud0_l} <= rxf_data;
        end else begin
            aud0_valid <= loop_valid;
            aud0_l <= loop_l;
            aud0_r <= loop_r;
        end
    end
endmodule
