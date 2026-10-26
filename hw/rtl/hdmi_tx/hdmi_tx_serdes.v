// hdmi_tx_serdes.v - 10:1 TMDS serializer + TMDS_33 output buffer, the same
// structure as Digilent rgb2dvi OutputSERDES.vhd: OSERDESE2 master + slave in
// DDR mode, bit 0 first (master D1 = bit 0 .. D8 = bit 7, slave D3/D4 = bits
// 8/9). CLK = SerialClk (5x), CLKDIV = PixelClk: they must be a phase-aligned
// pair (axi_dynclk: BUFIO + BUFR in the same clock region, or two BUFGs).
`timescale 1ns / 1ps
module hdmi_tx_serdes (
    input  wire       PixelClk,
    input  wire       SerialClk,
    input  wire       rst,        // synchronous to PixelClk, active high
    input  wire [9:0] pdata,
    output wire       out_p,
    output wire       out_n
);
`ifdef VERILATOR
    // simulation: the testbench checks the 10-bit words before this block
    assign out_p = 1'b0;
    assign out_n = 1'b1;
`else
    wire sdata, shift1, shift2;
    OBUFDS #(.IOSTANDARD("TMDS_33")) obuf (.O(out_p), .OB(out_n), .I(sdata));
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
        .TRISTATE_WIDTH(1), .TBYTE_CTL("FALSE"), .TBYTE_SRC("FALSE"),
        .SERDES_MODE("MASTER")
    ) primary (
        .OQ(sdata), .OFB(), .TQ(), .TFB(), .SHIFTOUT1(), .SHIFTOUT2(), .TBYTEOUT(),
        .CLK(SerialClk), .CLKDIV(PixelClk),
        .D1(pdata[0]), .D2(pdata[1]), .D3(pdata[2]), .D4(pdata[3]),
        .D5(pdata[4]), .D6(pdata[5]), .D7(pdata[6]), .D8(pdata[7]),
        .OCE(1'b1), .RST(rst), .SHIFTIN1(shift1), .SHIFTIN2(shift2),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), .TCE(1'b0));
    OSERDESE2 #(
        .DATA_RATE_OQ("DDR"), .DATA_RATE_TQ("SDR"), .DATA_WIDTH(10),
        .TRISTATE_WIDTH(1), .TBYTE_CTL("FALSE"), .TBYTE_SRC("FALSE"),
        .SERDES_MODE("SLAVE")
    ) secondary (
        .OQ(), .OFB(), .TQ(), .TFB(), .SHIFTOUT1(shift1), .SHIFTOUT2(shift2), .TBYTEOUT(),
        .CLK(SerialClk), .CLKDIV(PixelClk),
        .D1(1'b0), .D2(1'b0), .D3(pdata[8]), .D4(pdata[9]),
        .D5(1'b0), .D6(1'b0), .D7(1'b0), .D8(1'b0),
        .OCE(1'b1), .RST(rst), .SHIFTIN1(1'b0), .SHIFTIN2(1'b0),
        .T1(1'b0), .T2(1'b0), .T3(1'b0), .T4(1'b0), .TBYTEIN(1'b0), .TCE(1'b0));
`endif
endmodule
