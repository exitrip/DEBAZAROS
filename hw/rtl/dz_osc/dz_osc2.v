// dz_osc2.v - DDS pattern engine, both channels behind ONE AXI port
// (2026-10-29; ROADMAP.md section 14). Replaces dds_axi_interface_0/1 and
// both DDS compilers (each channel has its own sine table: one RAMB18
// instead of the compiler's 7 RAMB36 + 1 RAMB18).
//
//   0x43D0_0000 + 0x0000  channel 0 (HDMI_0; the old dds_axi_interface_0
//                         address: +0 PINC and +4 STATUS stay compatible)
//   0x43D0_0000 + 0x4000  channel 1 (HDMI_1; was 0x44D0_0000)
// Register map of a channel: dz_osc_ch.v. The chain inputs of each channel
// are the step / wrap pulses of the other one (divider chains,
// cross-modulation). The raster (VTC vsync / hsync / active_video, pixel
// clock) and the external trigger are synchronized once here, for both:
// an edge comes 2-3 FCLK0 clocks late and moves by at most 10 ns.
`timescale 1ns / 1ps
module dz_osc2 (
    input  wire        clk,        // FCLK0 = s_axi_aclk
    input  wire        aresetn,
    // AXI4-Lite subordinate, 32 KB
    input  wire [14:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready = 0,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready = 0,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid = 0,
    input  wire        s_axi_bready,
    input  wire [14:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready = 0,
    output reg  [31:0] s_axi_rdata = 0,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid = 0,
    input  wire        s_axi_rready,
    // raster from the shared VTC (pixel clock, asynchronous), trigger
    input  wire        vsync,
    input  wire        hsync,
    input  wire        line_de,
    input  wire        ext_trig,
    // channel 0 (HDMI_0) and channel 1 (HDMI_1)
    output wire [15:0] wave0,      // to the old sine leg (div16_8_recip_0 num)
    output wire [15:0] phase0,     // to the old phase leg (phase[31:16])
    output wire [31:0] phase0_full,// HDMI_0 phase without delay (event block)
    output wire [15:0] wave1,
    output wire [15:0] phase1,
    output wire [31:0] phase1_full,
    output wire [1:0]  step_pulse, // for the event block / debugging
    output wire [1:0]  wrap_pulse
);
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // ---- raster syncs: 2-FF synchronizers, rising edges (shared) --------------------
    (* ASYNC_REG = "TRUE" *) reg [1:0] vs_s = 0, hs_s = 0, de_s = 0, ex_s = 0;
    reg vs_q = 0, hs_q = 0, de_q = 0, ex_q = 0;
    always @(posedge clk) begin
        vs_s <= {vs_s[0], vsync};    vs_q <= vs_s[1];
        hs_s <= {hs_s[0], hsync};    hs_q <= hs_s[1];
        de_s <= {de_s[0], line_de};  de_q <= de_s[1];
        ex_s <= {ex_s[0], ext_trig}; ex_q <= ex_s[1];
    end
    wire vs_e = vs_s[1] & ~vs_q, hs_e = hs_s[1] & ~hs_q;
    wire de_e = de_s[1] & ~de_q, ex_e = ex_s[1] & ~ex_q;

    // ---- AXI write: address and data together, one channel by addr[14] ---------------
    wire wr = s_axi_awvalid && s_axi_wvalid && !s_axi_awready && !s_axi_bvalid;
    always @(posedge clk) begin
        if (!aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
        end else begin
            s_axi_awready <= wr;
            s_axi_wready <= wr;
            if (wr)
                s_axi_bvalid <= 1'b1;
            else if (s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // ---- AXI read: the address is registered, the data one clock later ---------------
    reg        rd_pend = 0;
    reg [14:0] ra = 0;
    wire [31:0] rd0, rd1;
    always @(posedge clk) begin
        if (!aresetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0; rd_pend <= 0;
        end else begin
            s_axi_arready <= s_axi_arvalid && !s_axi_arready && !s_axi_rvalid && !rd_pend;
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid && !rd_pend) begin
                ra <= s_axi_araddr;
                rd_pend <= 1'b1;
            end else if (rd_pend) begin
                rd_pend <= 1'b0;
                s_axi_rvalid <= 1'b1;
                s_axi_rdata <= ra[14] ? rd1 : rd0;
            end else if (s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end

    // ---- the two channels, chained to each other -----------------------------------------
    wire [1:0] sp, wp;
    assign step_pulse = sp;
    assign wrap_pulse = wp;
    dz_osc_ch ch0 (.clk(clk), .rst(!aresetn),
        .we(wr && !s_axi_awaddr[14]), .waddr(s_axi_awaddr[13:0]), .wdata(s_axi_wdata),
        .wstrb(s_axi_wstrb), .raddr(ra[13:0]), .rdata(rd0),
        .vs_e(vs_e), .hs_e(hs_e), .de_e(de_e), .ex_e(ex_e),
        .chain_step_in(sp[1]), .chain_wrap_in(wp[1]), .step_pulse(sp[0]), .wrap_pulse(wp[0]),
        .phase(phase0_full), .wave_out(wave0), .phase_out(phase0));
    dz_osc_ch ch1 (.clk(clk), .rst(!aresetn),
        .we(wr && s_axi_awaddr[14]), .waddr(s_axi_awaddr[13:0]), .wdata(s_axi_wdata),
        .wstrb(s_axi_wstrb), .raddr(ra[13:0]), .rdata(rd1),
        .vs_e(vs_e), .hs_e(hs_e), .de_e(de_e), .ex_e(ex_e),
        .chain_step_in(sp[0]), .chain_wrap_in(wp[0]), .step_pulse(sp[1]), .wrap_pulse(wp[1]),
        .phase(phase1_full), .wave_out(wave1), .phase_out(phase1));
endmodule
