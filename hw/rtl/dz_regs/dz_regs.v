// dz_regs.v - one register block in place of the four AXI GPIOs that serve as
// register banks (2026-10-29; ROADMAP.md section 14, "GPIO consolidation").
// One AXI-Lite subordinate over 0x4120_0000-0x4127_FFFF (512 KB, aligned):
// the old GPIOs keep their addresses and register offsets, so the software
// and the address contract stay as they are. Each AXI GPIO cost ~63-160 LUT,
// 222-453 FF and a crossbar port for 64 bits of registers (routed `fs`).
//
// Bank = address bits [18:16]:
//   0  0x4120_0000  was axi_gpio_hdmi_in_phase0_div_gPhase1:
//                   +0x000 ch1 DATA, INPUT (gpio_in, 2-FF synchronized as in
//                          the IP), +0x004 TRI (reads all 1s)
//                   +0x008 ch2 DATA, output (reset 0x0100_0000), +0x00C TRI (0)
//                   +0x11C GIER [31] global interrupt enable
//                   +0x120 IP ISR [0] ch1 changed (TOGGLE ON WRITE: write 1 to
//                          clear it, as the IP); [1] stays 0 (ch2 is output)
//                   +0x128 IP IER [1:0]
//                   irq = GIER[31] & |(ISR & IER) (was ip2intc_irpt, GIC 66)
//   1  0x4121_0000  was HDMI_0/axi_gpio_mainG_shift_memdelay:
//                   +0x0 ch1 (reset 0xFFFF_FFFF), +0x8 ch2 (reset 0)
//   3  0x4123_0000  was HDMI_1/axi_gpio_divOsc_gosc_shiftPhaseOsc:
//                   +0x0 ch1 (reset 0x0101_0101), +0x8 ch2 (reset 0)
//   6  0x4126_0000  was HDMI_1/axi_gpio_divPhase_gmain_shiftPhase_gfeedback:
//                   +0x0 ch1 (reset 0x01FF_FFFF), +0x8 ch2 (reset 0x0080_8080)
//   2, 4, 5, 7      free: read 0, writes ignored (the old design answered
//                   0x4122 / 0x4124 with a bus error; now OKAY)
// Output channels read back what was written; their TRI registers read 0;
// TRI writes are ignored (the directions are fixed, as in the old IPs).
//
// New compared with the AXI GPIO: byte and halfword writes (WSTRB). Nearly
// every field in these banks is byte- or halfword-aligned (dividers [31:24],
// gains [23:16] [15:8] [7:0], offsets [15:0], the delay [29:16]), so one
// 8- or 16-bit store changes one field: no read-modify-write.
`timescale 1ns / 1ps
module dz_regs (
    input  wire        s_axi_aclk,     // FCLK0
    input  wire        s_axi_aresetn,
    // AXI4-Lite subordinate, 512 KB
    input  wire [18:0] s_axi_awaddr,
    input  wire        s_axi_awvalid,
    output reg         s_axi_awready = 0,
    input  wire [31:0] s_axi_wdata,
    input  wire [3:0]  s_axi_wstrb,
    input  wire        s_axi_wvalid,
    output reg         s_axi_wready = 0,
    output wire [1:0]  s_axi_bresp,
    output reg         s_axi_bvalid = 0,
    input  wire        s_axi_bready,
    input  wire [18:0] s_axi_araddr,
    input  wire        s_axi_arvalid,
    output reg         s_axi_arready = 0,
    output reg  [31:0] s_axi_rdata = 0,
    output wire [1:0]  s_axi_rresp,
    output reg         s_axi_rvalid = 0,
    input  wire        s_axi_rready,
    // bank 0 (0x4120_0000): ch1 input, ch2 output, interrupt
    input  wire [31:0] gpio_in,
    output reg  [31:0] b0_ch2 = 32'h0100_0000,
    output wire        irq,
    // bank 1 (0x4121_0000), bank 3 (0x4123_0000), bank 6 (0x4126_0000)
    output reg  [31:0] b1_ch1 = 32'hFFFF_FFFF,
    output reg  [31:0] b1_ch2 = 32'h0000_0000,
    output reg  [31:0] b3_ch1 = 32'h0101_0101,
    output reg  [31:0] b3_ch2 = 32'h0000_0000,
    output reg  [31:0] b6_ch1 = 32'h01FF_FFFF,
    output reg  [31:0] b6_ch2 = 32'h0080_8080
);
    assign s_axi_bresp = 2'b00;
    assign s_axi_rresp = 2'b00;

    // ---- bank 0 input: 2-FF synchronizer, change detect, interrupt ------------------
    (* ASYNC_REG = "TRUE" *) reg [31:0] in_s1 = 0, in_s2 = 0;
    reg [31:0] in_q = 0;
    reg        gier = 0;
    reg [1:0]  isr = 0, ier = 0;
    always @(posedge s_axi_aclk) begin
        in_s1 <= gpio_in;
        in_s2 <= in_s1;
        in_q  <= in_s2;
    end
    wire changed = in_s2 != in_q;
    assign irq = gier & |(isr & ier);

    // ---- write: address and data together; byte strobes --------------------------------
    wire wr = s_axi_awvalid && s_axi_wvalid && !s_axi_awready && !s_axi_bvalid;
    wire [2:0] wbank = s_axi_awaddr[18:16];
    // word address: an 8- or 16-bit store to +1..+3 arrives with those low
    // address bits AND its WSTRB lanes - the lanes select the bytes
    wire [8:0] woff  = {s_axi_awaddr[8:2], 2'b00};
    wire       wsel  = s_axi_awaddr[15:9] == 0;     // registers sit in the first 512 B
    integer b;
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_awready <= 0; s_axi_wready <= 0; s_axi_bvalid <= 0;
            b0_ch2 <= 32'h0100_0000;
            b1_ch1 <= 32'hFFFF_FFFF; b1_ch2 <= 32'h0000_0000;
            b3_ch1 <= 32'h0101_0101; b3_ch2 <= 32'h0000_0000;
            b6_ch1 <= 32'h01FF_FFFF; b6_ch2 <= 32'h0080_8080;
            gier <= 0; isr <= 0; ier <= 0;
        end else begin
            s_axi_awready <= wr;
            s_axi_wready <= wr;
            // ISR: set by a change of the input; a written 1 toggles (TOW)
            isr[0] <= (isr[0] | changed) ^ (wr && wsel && wbank == 3'd0 && woff == 9'h120 &&
                                           s_axi_wstrb[0] && s_axi_wdata[0]);
            if (wr && wsel) begin
                for (b = 0; b < 4; b = b + 1)
                    if (s_axi_wstrb[b])
                        case ({wbank, woff})
                            {3'd0, 9'h008}: b0_ch2[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd1, 9'h000}: b1_ch1[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd1, 9'h008}: b1_ch2[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd3, 9'h000}: b3_ch1[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd3, 9'h008}: b3_ch2[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd6, 9'h000}: b6_ch1[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            {3'd6, 9'h008}: b6_ch2[8*b +: 8] <= s_axi_wdata[8*b +: 8];
                            default: ;
                        endcase
                if (wbank == 3'd0 && woff == 9'h11C && s_axi_wstrb[3]) gier <= s_axi_wdata[31];
                if (wbank == 3'd0 && woff == 9'h128 && s_axi_wstrb[0]) ier <= s_axi_wdata[1:0];
            end
            if (wr)
                s_axi_bvalid <= 1'b1;
            else if (s_axi_bready)
                s_axi_bvalid <= 1'b0;
        end
    end

    // ---- read: address latched at accept, the mux one clock later ------------------
    // (the mux straight on ARADDR failed FCLK0 by 0.27 ns, 9 ns of routing from
    // the crossbar, build regs2)
    reg  [18:0] ra_q = 0;
    reg         rd_pend = 0;
    wire [2:0] rbank = ra_q[18:16];
    wire [8:0] roff  = {ra_q[8:2], 2'b00};
    reg  [31:0] rv;
    always @* begin
        rv = 32'd0;
        if (ra_q[15:9] == 0)
            case ({rbank, roff})
                {3'd0, 9'h000}: rv = in_s2;
                {3'd0, 9'h004}: rv = 32'hFFFF_FFFF;     // ch1 TRI: all inputs
                {3'd0, 9'h008}: rv = b0_ch2;
                {3'd0, 9'h11C}: rv = {gier, 31'd0};
                {3'd0, 9'h120}: rv = {30'd0, isr};
                {3'd0, 9'h128}: rv = {30'd0, ier};
                {3'd1, 9'h000}: rv = b1_ch1;
                {3'd1, 9'h008}: rv = b1_ch2;
                {3'd3, 9'h000}: rv = b3_ch1;
                {3'd3, 9'h008}: rv = b3_ch2;
                {3'd6, 9'h000}: rv = b6_ch1;
                {3'd6, 9'h008}: rv = b6_ch2;
                default: rv = 32'd0;
            endcase
    end
    always @(posedge s_axi_aclk) begin
        if (!s_axi_aresetn) begin
            s_axi_arready <= 0; s_axi_rvalid <= 0; rd_pend <= 0;
        end else begin
            s_axi_arready <= s_axi_arvalid && !s_axi_arready && !rd_pend && !s_axi_rvalid;
            rd_pend <= 1'b0;
            if (s_axi_arvalid && !s_axi_arready && !rd_pend && !s_axi_rvalid) begin
                ra_q <= s_axi_araddr;
                rd_pend <= 1'b1;
            end
            if (rd_pend) begin
                s_axi_rdata <= rv;
                s_axi_rvalid <= 1'b1;
            end else if (s_axi_rready)
                s_axi_rvalid <= 1'b0;
        end
    end
endmodule
