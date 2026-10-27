// hdmi_audio_regs.v - AXI4-Lite registers for HDMI audio: hdmi_tx control
// (output) and the status of the HDMI_2 audio receiver (input). BD module
// reference; one new address in the PS map.
//
//   0x00 RW TX_CTRL     -> hdmi_tx ctrl ([0] HDMI, [1] audio, [2] tone, [9:8] AVI VIC)
//   0x04 RW TX_FS_INC   -> hdmi_tx fs_inc (internal 48 kHz NCO)
//   0x08 RW RX_CTRL     [0] loop received audio into hdmi_tx, [1] clear peaks
//   0x10 RO RX_STATUS   [0] data islands seen, [1] audio samples seen (last update)
//   0x14 RO RX_SAMPLES  stereo samples received (wraps)
//   0x18 RO RX_PEAK     [31:16] R, [15:0] L: peak |sample| since the last clear
//   0x1C RO RX_ACR_N    N of the last Audio Clock Regeneration packet
//   0x20 RO RX_ACR_CTS  CTS of the last Audio Clock Regeneration packet
//   0x3C RO ID          "HAUD" (0x48415544)
// User I/O lines PL_KEY0-5 + I2S (hw/rtl/pl_io, 2026-10-27):
//   0x40 RW IO_FUNC     4 bits per line (line n = [4n+3:4n]), see pl_io_core.v
//   0x44 RW IO_OUT      [5:0] GPIO output values (function 1)
//   0x48 RO IO_IN       [5:0] line levels (also at 0x4120_0000 ch1 [5:0])
//   0x4C RW I2S_CTRL    [0] on, [1] DOUT = HDMI_2 audio, [2] HDMI_1 audio = DIN,
//                       [3] steer the bit clock by the FIFO level
//   0x50 RW I2S_INC     bit clock NCO (reset 263882791 = 48 kHz at 100 MHz)
//   0x54 RO I2S_STATUS  [3:0] TX FIFO level, [15:8] underruns (saturates)
//
// The rx_* inputs live in the receiver clock domain: the receiver copies
// them into hold registers and toggles rx_pub; this block takes the copy
// after the toggle passes a 2-FF synchronizer, so no value tears.
`timescale 1ns / 1ps
module hdmi_audio_regs #(
    parameter integer C_S_AXI_ADDR_WIDTH = 7
) (
    input  wire        s_axi_aclk,
    input  wire        s_axi_aresetn,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready = 0,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready = 0,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid = 0,
    input  wire        s_axi_bready,
    input  wire [C_S_AXI_ADDR_WIDTH-1:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready = 0,
    output reg  [31:0] s_axi_rdata = 0,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid = 0,
    input  wire        s_axi_rready,

    output reg  [31:0] tx_ctrl = 0,
    output reg  [31:0] tx_fs_inc = 0,
    output reg  [31:0] rx_ctrl = 0,
    output reg  [23:0] io_func = 0,
    output reg  [5:0]  io_out = 0,
    input  wire [5:0]  io_in,
    output reg  [31:0] i2s_ctrl = 0,
    output reg  [31:0] i2s_inc = 32'd263882791,
    input  wire [31:0] i2s_status,

    input  wire        rx_pub,         // toggles when the rx_* hold values change
    input  wire [1:0]  rx_status,
    input  wire [31:0] rx_samples,
    input  wire [31:0] rx_peak,
    input  wire [19:0] rx_acr_n,
    input  wire [19:0] rx_acr_cts
);
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // ---- receiver status, clock-domain crossing ---------------------------
    (* ASYNC_REG = "TRUE" *) reg [2:0] pub_sync = 0;
    reg [1:0]  st = 0;
    reg [31:0] samples = 0, peak = 0;
    reg [19:0] acr_n = 0, acr_cts = 0;
    always @(posedge s_axi_aclk) begin
        pub_sync <= {pub_sync[1:0], rx_pub};
        if (pub_sync[2] ^ pub_sync[1]) begin
            st <= rx_status;
            samples <= rx_samples;
            peak <= rx_peak;
            acr_n <= rx_acr_n;
            acr_cts <= rx_acr_cts;
        end
    end

    // ---- write channel: address and data together (AXI-Lite) ------------------
    wire wr = s_axi_awvalid && s_axi_wvalid && !s_axi_awready && !s_axi_bvalid;
    integer b;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            tx_ctrl <= 0; tx_fs_inc <= 0; rx_ctrl <= 0;
            io_func <= 0; io_out <= 0; i2s_ctrl <= 0; i2s_inc <= 32'd263882791;
        end else begin
            s_axi_awready <= wr;
            s_axi_wready <= wr;
            if (wr) begin
                for (b = 0; b < 4; b = b + 1)
                    if (s_axi_wstrb[b])
                        case (s_axi_awaddr[6:2])
                            5'h00: tx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            5'h01: tx_fs_inc[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            5'h02: rx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            5'h10: if (b < 3) io_func[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            5'h11: if (b == 0) io_out <= s_axi_wdata[5:0];
                            5'h13: i2s_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            5'h14: i2s_inc[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            default: ;
                        endcase
                s_axi_bvalid <= 1'b1;
            end else if (s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // ---- read channel ------------------------------------------------------------
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0;
        end else begin
            s_axi_arready <= s_axi_arvalid && !s_axi_arready && !s_axi_rvalid;
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                case (s_axi_araddr[6:2])
                    5'h00: s_axi_rdata <= tx_ctrl;
                    5'h01: s_axi_rdata <= tx_fs_inc;
                    5'h02: s_axi_rdata <= rx_ctrl;
                    5'h04: s_axi_rdata <= {30'd0, st};
                    5'h05: s_axi_rdata <= samples;
                    5'h06: s_axi_rdata <= peak;
                    5'h07: s_axi_rdata <= {12'd0, acr_n};
                    5'h08: s_axi_rdata <= {12'd0, acr_cts};
                    5'h0F: s_axi_rdata <= 32'h48415544;
                    5'h10: s_axi_rdata <= {8'd0, io_func};
                    5'h11: s_axi_rdata <= {26'd0, io_out};
                    5'h12: s_axi_rdata <= {26'd0, io_in};
                    5'h13: s_axi_rdata <= i2s_ctrl;
                    5'h14: s_axi_rdata <= i2s_inc;
                    5'h15: s_axi_rdata <= i2s_status;
                    default: s_axi_rdata <= 0;
                endcase
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule
