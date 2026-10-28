// hdmi_audio_regs.v - AXI4-Lite registers for HDMI audio: hdmi_tx control
// (output) and the status of the HDMI_2 audio receiver (input). BD module
// reference; one new address in the PS map.
//
//   0x00 RW TX_CTRL     -> hdmi_tx ctrl ([0] HDMI, [1] audio, [2] tone, [9:8] AVI VIC)
//   0x04 RW TX_FS_INC   -> hdmi_tx fs_inc (internal 48 kHz NCO)
//   0x08 RW RX_CTRL     [0] loop received audio into hdmi_tx, [1] clear peaks,
//                       [2] force HDMI_2 hot-plug LOW (reset 0 = HPD high, as
//                       before; a pulse makes the source re-read the EDID)
//   0x0C RW TX0_CTRL    HDMI_0's hdmi_tx ctrl (bits as TX_CTRL, which is HDMI_1);
//                       both outputs share TX_FS_INC (same pixel clock)
//   0x10 RO RX_STATUS   [0] data islands seen, [1] audio samples seen (last update)
//   0x14 RO RX_SAMPLES  stereo samples received (wraps)
//   0x18 RO RX_PEAK     [31:16] R, [15:0] L: peak |sample| since the last clear
//   0x1C RO RX_ACR_N    N of the last Audio Clock Regeneration packet
//   0x20 RO RX_ACR_CTS  CTS of the last Audio Clock Regeneration packet
//   0x3C RO ID          "HAUD" (0x48415544)
// User I/O lines PL_KEY0-5 + I2S (hw/rtl/pl_io, 2026-10-27):
//   0x40 RW IO_FUNC     4 bits per line (line n = [4n+3:4n]), see pl_io_core.v
//   0x44 RW IO_OUT      [5:0] GPIO output values (function 1)
//                       [9:8] fan J3 / J5 pin 4 opto ON (= pin 4 pulled low);
//                       [11:10] J3 / J5 pin 4 follows the VTC vsync instead
//                       (on during the sync pulse: frame sync to other units).
//                       Reset 0 = optos off. Fan pin 3 inputs: GPIO
//                       0x4120_0000 ch1 [15] J3, [16] J5 (raw, active low)
//                       [12] LED_RED pin level (W14; may not be fitted)
//                       [13] J3 pin 4 = hardware PWM (wins over [8] / [10])
//   0x90 RW PWM_CTRL    J3 hardware PWM (2026-10-27): [23:0] period in 10 ns
//                       counts (>= 2; 2000000 = 50 Hz; max 167 ms), [30]
//                       invert: active = opto OFF = pin 4 high (RC servo
//                       pulses), [31] restart the period at each vsync start
//                       (pulses locked to the video frame)
//   0x94 RW PWM_DUTY    [23:0] active counts at the start of each period
//                       (taken at the period start: no glitch pulses);
//                       0 = never active, >= period = always active
//   0x98 RO PWM_ID      "PWM1" (0x50574D31): software finds the PWM by this
//   0x48 RO IO_IN       [5:0] line levels (also at 0x4120_0000 ch1 [5:0])
//   0x4C RW I2S_CTRL    [0] on, [1] DOUT = HDMI_2 audio, [2] HDMI_1 audio = DIN,
//                       [3] steer the bit clock by the FIFO level
//   0x50 RW I2S_INC     bit clock NCO (reset 263882791 = 48 kHz at 100 MHz)
//   0x54 RO I2S_STATUS  [3:0] TX FIFO level, [15:8] underruns (saturates)
// Linux PCM (ALSA card "debaz-audio", 2026-10-27; pl_io_core.v): three
// playback streams (0 HDMI_0, 1 HDMI_1, 2 I2S DOUT) and one capture stream
// (3 = HDMI_2 input), each a 512-word FIFO of {R[31:16], L[15:0]} words.
// Route a stream to its output with I2S_CTRL [6] / [5] / [7].
//   0x60 RW PCM_CTRL    [3:0] run per stream; [11:8] write 1 = empty the FIFO
//                       (reads 0)
//   0x64 WO PCM0_DATA   one frame into the HDMI_0 FIFO (lost if full)
//   0x68 WO PCM1_DATA   one frame into the HDMI_1 FIFO
//   0x6C RO CAP_DATA    oldest captured frame; the read removes it (check
//                       CAP level first: an empty FIFO returns a stale word)
//   0x70 WO PCM2_DATA   one frame into the I2S FIFO
//   0x74 RO LEVEL01     [25:16] PCM1 level, [9:0] PCM0 level (words)
//   0x78 RO LEVEL2C     [25:16] capture level, [9:0] PCM2 level
//   0x7C RW IRQ_STATUS  [3:0] level condition per stream (live): playback
//                       level <= threshold / capture level >= threshold;
//                       [7:4] xrun latched (underrun 0-2, capture overrun 3),
//                       write 1 to clear
//   0x80 RW IRQ_EN      [3:0] level conditions, [7:4] xruns -> irq (level high)
//   0x84 RO PCM_FRAMES  48 kHz pacer frames (wraps; HDMI streams pop 1 each)
//   0x88 RW THRESH01    [24:16] PCM1, [8:0] PCM0 threshold (words)
//   0x8C RW THRESH2C    [24:16] capture, [8:0] PCM2 threshold
// Events (page 1 = 0x1000-0x1FFF, its own interrupt `ev_irq`, so a UIO node
// can own it apart from the ALSA driver; 2026-10-27). Sources (bit n):
// [0] fan J3 pin 3, [1] fan J5 pin 3, [7:2] user I/O lines 0-5 (pin levels),
// [8] VTC vsync. Timestamps = EV_TIME at the edge (+3 clocks for the
// synchronizers; vsync up to 1 more), 10 ns per count, wraps every 42.9 s.
//   0x1000 RO EV_ID        "EVNT" (0x45564E54)
//   0x1004 RO EV_TIME      free-running 100 MHz counter
//   0x1008 RW EV_PEND      [8:0] edges seen (enabled in RISE/FALL); write 1 = clear
//   0x100C RW EV_IRQ_EN    [8:0] EV_PEND bits -> ev_irq (level high)
//   0x1010 RW EV_RISE      [8:0] count rising edges
//   0x1014 RW EV_FALL      [8:0] count falling edges (pin 3 / buttons: active low)
//   0x1018 RO EV_LEVEL     [8:0] synchronized levels now
//   0x1020 RO TS_J3        time of the last enabled J3 edge
//   0x1024 RO TS_J5        time of the last enabled J5 edge
//   0x1028 RO TS_LINE      time of the last enabled edge of lines 0-5
//   0x102C RO TS_VSYNC     time of the last vsync start (always)
//   0x1030 RO DDS0_AT_VS   HDMI_0 DDS phase (32 bit) at the last vsync start
//   0x1034 RO DDS0_PHASE   HDMI_0 DDS phase now
//
// The rx_* inputs live in the receiver clock domain: the receiver copies
// them into hold registers and toggles rx_pub; this block takes the copy
// after the toggle passes a 2-FF synchronizer, so no value tears.
`timescale 1ns / 1ps
module hdmi_audio_regs #(
    parameter integer C_S_AXI_ADDR_WIDTH = 13
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
    output reg  [31:0] tx0_ctrl = 0,
    output reg  [31:0] tx_fs_inc = 0,
    output reg  [31:0] rx_ctrl = 0,
    output wire [0:0]  hpd2,           // HDMI_2 hot-plug detect pin (HDMI_HPD_2)
    output reg  [23:0] io_func = 0,
    output reg  [5:0]  io_out = 0,
    input  wire        vsync,          // VTC vsync (pixel clock; to the pins only)
    output wire        j3p4,           // FPGA pin levels for the fan optos
    output wire        j5p4,           // (low = opto on)
    output wire [0:0]  led_red,
    input  wire        j3p3,           // fan pin 3 inputs (raw pins)
    input  wire        j5p3,
    input  wire [31:0] dds_phase,      // HDMI_0 DDS phase (FCLK0 = s_axi_aclk)
    output reg         ev_irq = 0,
    input  wire [5:0]  io_in,
    output reg  [31:0] i2s_ctrl = 0,
    output reg  [31:0] i2s_inc = 32'd263882791,
    input  wire [31:0] i2s_status,
    output reg  [2:0]  pcm_wr = 0,
    output reg  [31:0] pcm_wdata = 0,
    output reg  [3:0]  pcm_run = 0,
    output reg  [3:0]  pcm_flush = 0,
    output reg         cap_pop = 0,
    input  wire [31:0] cap_head,
    input  wire [9:0]  pcm_level0, pcm_level1, pcm_level2, cap_level,
    input  wire [3:0]  pcm_xrun,
    input  wire [31:0] pcm_frames,
    output reg         irq = 0,

    input  wire        rx_pub,         // toggles when the rx_* hold values change
    input  wire [1:0]  rx_status,
    input  wire [31:0] rx_samples,
    input  wire [31:0] rx_peak,
    input  wire [19:0] rx_acr_n,
    input  wire [19:0] rx_acr_cts
);
    assign hpd2 = ~rx_ctrl[2];
    reg [3:0] fan = 0;
    reg       led_r = 0, pwm_sel = 0;
    assign led_red = led_r;
    // ---- J3 hardware PWM ---------------------------------------------------------
    reg [31:0] pwm_ctrl = 0;
    reg [23:0] pwm_duty = 0, pwm_dact = 0, pwm_cnt = 0;
    reg        pwm_q = 1'b1;               // FPGA pin level (high = opto off)
    wire       vs_start;                   // from the event synchronizer below
    wire       pwm_wrap = pwm_cnt >= pwm_ctrl[23:0] - 24'd1;
    always @(posedge s_axi_aclk) begin
        if ((pwm_ctrl[31] && vs_start) || pwm_wrap) begin
            pwm_cnt <= 24'd0;
            pwm_dact <= pwm_duty;
        end else
            pwm_cnt <= pwm_cnt + 24'd1;
        // active = count < duty; opto on = active (invert: active = opto off)
        pwm_q <= ~((pwm_cnt < pwm_dact) ^ pwm_ctrl[30]);
    end
    assign j3p4 = pwm_sel ? pwm_q : ~(fan[2] ? vsync : fan[0]);
    assign j5p4 = ~(fan[3] ? vsync : fan[1]);
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

    // ---- Linux PCM interrupt ------------------------------------------------------
    reg  [7:0]  irq_en = 0;
    reg  [3:0]  xrun = 0;
    reg  [8:0]  thr0 = 0, thr1 = 0, thr2 = 0, thrc = 0;
    wire [3:0]  lvl_cond = {cap_level >= {1'b0, thrc}, pcm_level2 <= {1'b0, thr2},
                            pcm_level1 <= {1'b0, thr1}, pcm_level0 <= {1'b0, thr0}};
    wire [7:0]  irq_st = {xrun, lvl_cond & pcm_run};
    always @(posedge s_axi_aclk) irq <= |(irq_st & irq_en);

    // ---- events (page 1) ---------------------------------------------------------
    (* ASYNC_REG = "TRUE" *) reg [2:0] ev_s1 = 0, ev_s2 = 0;
    always @(posedge s_axi_aclk) {ev_s2, ev_s1} <= {ev_s1, {vsync, j5p3, j3p3}};
    wire [8:0]  ev_lvl = {ev_s2[2], io_in, ev_s2[1:0]};   // io_in is synchronized in pl_io
    reg  [8:0]  ev_q = 0, ev_pend = 0, ev_en = 0, ev_rise = 0, ev_fall = 0;
    reg  [31:0] ev_time = 0, ts_j3 = 0, ts_j5 = 0, ts_line = 0, ts_vs = 0, ph_vs = 0;
    wire [8:0]  ev_hit = (ev_lvl & ~ev_q & ev_rise) | (~ev_lvl & ev_q & ev_fall);
    assign vs_start = ev_lvl[8] && !ev_q[8];
    always @(posedge s_axi_aclk) begin
        ev_q <= ev_lvl;
        ev_time <= ev_time + 32'd1;
        if (ev_hit[0]) ts_j3 <= ev_time;
        if (ev_hit[1]) ts_j5 <= ev_time;
        if (|ev_hit[7:2]) ts_line <= ev_time;
        if (vs_start) begin ts_vs <= ev_time; ph_vs <= dds_phase; end
        ev_irq <= |(ev_pend & ev_en);
    end

    // ---- write channel: address and data together (AXI-Lite) ------------------
    wire wr = s_axi_awvalid && s_axi_wvalid && !s_axi_awready && !s_axi_bvalid;
    integer b;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            tx_ctrl <= 0; tx0_ctrl <= 0; tx_fs_inc <= 0; rx_ctrl <= 0;
            io_func <= 0; io_out <= 0; fan <= 0; i2s_ctrl <= 0; i2s_inc <= 32'd263882791;
            pcm_wr <= 0; pcm_run <= 0; pcm_flush <= 0; irq_en <= 0; xrun <= 0;
            led_r <= 0; pwm_sel <= 0; pwm_ctrl <= 0; pwm_duty <= 0; ev_pend <= 0; ev_en <= 0; ev_rise <= 0; ev_fall <= 0;
            thr0 <= 0; thr1 <= 0; thr2 <= 0; thrc <= 0;
        end else begin
            s_axi_awready <= wr;
            s_axi_wready <= wr;
            pcm_wr <= 0;
            pcm_flush <= 0;
            xrun <= xrun | pcm_xrun;
            ev_pend <= ev_pend | ev_hit;
            if (wr && s_axi_awaddr[12]) begin
                case (s_axi_awaddr[7:2])
                    6'h02: ev_pend <= (ev_pend & ~s_axi_wdata[8:0]) | ev_hit;
                    6'h03: ev_en <= s_axi_wdata[8:0];
                    6'h04: ev_rise <= s_axi_wdata[8:0];
                    6'h05: ev_fall <= s_axi_wdata[8:0];
                    default: ;
                endcase
                s_axi_bvalid <= 1'b1;
            end else if (wr) begin
                case (s_axi_awaddr[7:2])
                    6'h19: pcm_wr[0] <= 1'b1;
                    6'h1A: pcm_wr[1] <= 1'b1;
                    6'h1C: pcm_wr[2] <= 1'b1;
                    6'h18: if (s_axi_wstrb[1]) pcm_flush <= s_axi_wdata[11:8];
                    6'h1F: if (s_axi_wstrb[0]) xrun <= (xrun & ~s_axi_wdata[7:4]) | pcm_xrun;
                    default: ;
                endcase
                pcm_wdata <= s_axi_wdata;
                for (b = 0; b < 4; b = b + 1)
                    if (s_axi_wstrb[b])
                        case (s_axi_awaddr[7:2])
                            6'h00: tx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h01: tx_fs_inc[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h02: rx_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h03: tx0_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h10: if (b < 3) io_func[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h11: if (b == 0) io_out <= s_axi_wdata[5:0];
                                   else if (b == 1) begin
                                       fan <= s_axi_wdata[11:8];
                                       led_r <= s_axi_wdata[12];
                                       pwm_sel <= s_axi_wdata[13];
                                   end
                            6'h13: i2s_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h14: i2s_inc[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h18: if (b == 0) pcm_run <= s_axi_wdata[3:0];
                            6'h20: if (b == 0) irq_en <= s_axi_wdata[7:0];
                            6'h24: pwm_ctrl[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h25: if (b < 3) pwm_duty[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            6'h22: if (b == 0) thr0[7:0] <= s_axi_wdata[7:0];
                                   else if (b == 1) thr0[8] <= s_axi_wdata[8];
                                   else if (b == 2) thr1[7:0] <= s_axi_wdata[23:16];
                                   else thr1[8] <= s_axi_wdata[24];
                            6'h23: if (b == 0) thr2[7:0] <= s_axi_wdata[7:0];
                                   else if (b == 1) thr2[8] <= s_axi_wdata[8];
                                   else if (b == 2) thrc[7:0] <= s_axi_wdata[23:16];
                                   else thrc[8] <= s_axi_wdata[24];
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
            s_axi_arready <= 0; s_axi_rvalid <= 0; cap_pop <= 0;
        end else begin
            s_axi_arready <= s_axi_arvalid && !s_axi_arready && !s_axi_rvalid;
            cap_pop <= 0;
            if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid && s_axi_araddr[12]) begin
                case (s_axi_araddr[7:2])
                    6'h00: s_axi_rdata <= 32'h45564E54;
                    6'h01: s_axi_rdata <= ev_time;
                    6'h02: s_axi_rdata <= {23'd0, ev_pend};
                    6'h03: s_axi_rdata <= {23'd0, ev_en};
                    6'h04: s_axi_rdata <= {23'd0, ev_rise};
                    6'h05: s_axi_rdata <= {23'd0, ev_fall};
                    6'h06: s_axi_rdata <= {23'd0, ev_lvl};
                    6'h08: s_axi_rdata <= ts_j3;
                    6'h09: s_axi_rdata <= ts_j5;
                    6'h0A: s_axi_rdata <= ts_line;
                    6'h0B: s_axi_rdata <= ts_vs;
                    6'h0C: s_axi_rdata <= ph_vs;
                    6'h0D: s_axi_rdata <= dds_phase;
                    default: s_axi_rdata <= 0;
                endcase
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_arvalid && !s_axi_arready && !s_axi_rvalid) begin
                case (s_axi_araddr[7:2])
                    6'h00: s_axi_rdata <= tx_ctrl;
                    6'h01: s_axi_rdata <= tx_fs_inc;
                    6'h02: s_axi_rdata <= rx_ctrl;
                    6'h03: s_axi_rdata <= tx0_ctrl;
                    6'h04: s_axi_rdata <= {30'd0, st};
                    6'h05: s_axi_rdata <= samples;
                    6'h06: s_axi_rdata <= peak;
                    6'h07: s_axi_rdata <= {12'd0, acr_n};
                    6'h08: s_axi_rdata <= {12'd0, acr_cts};
                    6'h0F: s_axi_rdata <= 32'h48415544;
                    6'h10: s_axi_rdata <= {8'd0, io_func};
                    6'h11: s_axi_rdata <= {18'd0, pwm_sel, led_r, fan, 2'd0, io_out};
                    6'h12: s_axi_rdata <= {26'd0, io_in};
                    6'h13: s_axi_rdata <= i2s_ctrl;
                    6'h14: s_axi_rdata <= i2s_inc;
                    6'h15: s_axi_rdata <= i2s_status;
                    6'h18: s_axi_rdata <= {28'd0, pcm_run};
                    6'h1B: begin s_axi_rdata <= cap_head; cap_pop <= 1'b1; end
                    6'h1D: s_axi_rdata <= {6'd0, pcm_level1, 6'd0, pcm_level0};
                    6'h1E: s_axi_rdata <= {6'd0, cap_level, 6'd0, pcm_level2};
                    6'h1F: s_axi_rdata <= {24'd0, irq_st};
                    6'h20: s_axi_rdata <= {24'd0, irq_en};
                    6'h21: s_axi_rdata <= pcm_frames;
                    6'h22: s_axi_rdata <= {7'd0, thr1, 7'd0, thr0};
                    6'h23: s_axi_rdata <= {7'd0, thrc, 7'd0, thr2};
                    6'h24: s_axi_rdata <= pwm_ctrl;
                    6'h25: s_axi_rdata <= {8'd0, pwm_duty};
                    6'h26: s_axi_rdata <= 32'h50574D31;
                    default: s_axi_rdata <= 0;
                endcase
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule
