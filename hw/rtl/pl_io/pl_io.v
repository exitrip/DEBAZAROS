// pl_io.v - user I/O lines PL_KEY0-5 with IOBUFs around pl_io_core (BD module
// reference). Pins: PL_KEY[3:0] = lines 0-3 (U19, V20, T19, U20); AUDIO_L
// (K17) = line 4 = PCB PL_KEY4; AUDIO_R (E19) = line 5 = PCB PL_KEY5 (old
// port names kept so the XDC does not change). key_in/k4_in/k5_in = the raw
// pin levels for the GPIO at 0x4120_0000 ch1 [5:0] (same bits as before).
`timescale 1ns / 1ps
module pl_io (
    inout  wire [3:0]  PL_KEY,
    inout  wire        AUDIO_L,
    inout  wire        AUDIO_R,
    output wire [3:0]  key_in,
    output wire        k4_in,
    output wire        k5_in,
    input  wire        clk,
    input  wire        rstn,
    input  wire [23:0] io_func,
    input  wire [5:0]  io_out,
    output wire [5:0]  io_in,
    input  wire [31:0] i2s_ctrl,
    input  wire [31:0] i2s_inc,
    output wire [31:0] i2s_status,
    input  wire        I2C0_SCL_O, I2C0_SCL_T, I2C0_SDA_O, I2C0_SDA_T,
    output wire        I2C0_SCL_I, I2C0_SDA_I,
    input  wire        SPI0_SCLK_O, SPI0_SCLK_T, SPI0_MOSI_O, SPI0_MOSI_T,
    input  wire        SPI0_SS_O, SPI0_SS_T, SPI0_SS1_O,
    output wire        SPI0_SCLK_I, SPI0_MOSI_I, SPI0_MISO_I, SPI0_SS_I,
    input  wire        UART0_TX,
    output wire        UART0_RX,
    input  wire        rx_clk,
    input  wire [15:0] rx_l, rx_r,
    input  wire        rx_valid,
    input  wire        tx_clk,
    input  wire [15:0] loop_l, loop_r,
    input  wire        loop_valid,
    output wire [15:0] aud_l, aud_r,
    output wire        aud_valid,
    output wire [15:0] aud0_l, aud0_r,
    output wire        aud0_valid,
    input  wire [2:0]  pcm_wr,
    input  wire [31:0] pcm_wdata,
    input  wire [3:0]  pcm_run,
    input  wire [3:0]  pcm_flush,
    input  wire        cap_pop,
    output wire [31:0] cap_head,
    output wire [9:0]  pcm_level0, pcm_level1, pcm_level2, cap_level,
    output wire [3:0]  pcm_xrun,
    output wire [31:0] pcm_frames
);
    wire [5:0] po, pt, pi;
    pl_io_core core (
        .clk(clk), .rstn(rstn), .io_func(io_func), .io_out(io_out), .io_in(io_in),
        .i2s_ctrl(i2s_ctrl), .i2s_inc(i2s_inc), .i2s_status(i2s_status),
        .pin_o(po), .pin_t(pt), .pin_i(pi),
        .i2c0_scl_o(I2C0_SCL_O), .i2c0_scl_t(I2C0_SCL_T), .i2c0_sda_o(I2C0_SDA_O),
        .i2c0_sda_t(I2C0_SDA_T), .i2c0_scl_i(I2C0_SCL_I), .i2c0_sda_i(I2C0_SDA_I),
        .spi0_sclk_o(SPI0_SCLK_O), .spi0_sclk_t(SPI0_SCLK_T), .spi0_mosi_o(SPI0_MOSI_O),
        .spi0_mosi_t(SPI0_MOSI_T), .spi0_ss_o(SPI0_SS_O), .spi0_ss_t(SPI0_SS_T),
        .spi0_ss1_o(SPI0_SS1_O), .spi0_sclk_i(SPI0_SCLK_I), .spi0_mosi_i(SPI0_MOSI_I),
        .spi0_miso_i(SPI0_MISO_I), .spi0_ss_i(SPI0_SS_I),
        .uart0_tx(UART0_TX), .uart0_rx(UART0_RX),
        .rx_clk(rx_clk), .rx_l(rx_l), .rx_r(rx_r), .rx_valid(rx_valid),
        .tx_clk(tx_clk), .loop_l(loop_l), .loop_r(loop_r), .loop_valid(loop_valid),
        .aud_l(aud_l), .aud_r(aud_r), .aud_valid(aud_valid),
        .aud0_l(aud0_l), .aud0_r(aud0_r), .aud0_valid(aud0_valid),
        .pcm_wr(pcm_wr), .pcm_wdata(pcm_wdata), .pcm_run(pcm_run), .pcm_flush(pcm_flush),
        .cap_pop(cap_pop), .cap_head(cap_head), .pcm_level0(pcm_level0),
        .pcm_level1(pcm_level1), .pcm_level2(pcm_level2), .cap_level(cap_level),
        .pcm_xrun(pcm_xrun), .pcm_frames(pcm_frames));

    assign key_in = pi[3:0];
    assign k4_in = pi[4];
    assign k5_in = pi[5];

`ifdef VERILATOR
    // simulation: pins are not modelled here (pl_io_core has its own test)
    assign pi = 6'b111111;
`else
    IOBUF b0 (.IO(PL_KEY[0]), .I(po[0]), .T(pt[0]), .O(pi[0]));
    IOBUF b1 (.IO(PL_KEY[1]), .I(po[1]), .T(pt[1]), .O(pi[1]));
    IOBUF b2 (.IO(PL_KEY[2]), .I(po[2]), .T(pt[2]), .O(pi[2]));
    IOBUF b3 (.IO(PL_KEY[3]), .I(po[3]), .T(pt[3]), .O(pi[3]));
    IOBUF b4 (.IO(AUDIO_L),   .I(po[4]), .T(pt[4]), .O(pi[4]));
    IOBUF b5 (.IO(AUDIO_R),   .I(po[5]), .T(pt[5]), .O(pi[5]));
`endif
endmodule
