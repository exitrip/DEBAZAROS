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
//
// The rx_* inputs live in the receiver clock domain: the receiver copies
// them into hold registers and toggles rx_pub; this block takes the copy
// after the toggle passes a 2-FF synchronizer, so no value tears.
`timescale 1ns / 1ps
module hdmi_audio_regs #(
    parameter integer C_S_AXI_ADDR_WIDTH = 6
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
        end else begin
            s_axi_awready <= wr;
            s_axi_wready <= wr;
            if (wr) begin
                for (b = 0; b < 4; b = b + 1)
                    if (s_axi_wstrb[b])
                        case (s_axi_awaddr[5:2])
                            4'h0: tx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            4'h1: tx_fs_inc[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            4'h2: rx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
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
                case (s_axi_araddr[5:2])
                    4'h0: s_axi_rdata <= tx_ctrl;
                    4'h1: s_axi_rdata <= tx_fs_inc;
                    4'h2: s_axi_rdata <= rx_ctrl;
                    4'h4: s_axi_rdata <= {30'd0, st};
                    4'h5: s_axi_rdata <= samples;
                    4'h6: s_axi_rdata <= peak;
                    4'h7: s_axi_rdata <= {12'd0, acr_n};
                    4'h8: s_axi_rdata <= {12'd0, acr_cts};
                    4'hF: s_axi_rdata <= 32'h48415544;
                    default: s_axi_rdata <= 0;
                endcase
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule
