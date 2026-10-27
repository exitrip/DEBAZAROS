`timescale 1ns/1ps
// hdmi_audio_regs_tb.sv - AXI-Lite writes/reads of hdmi_audio_regs and the
// receiver-status handshake (run by hw/sim/run_hdmi_tx_tb.sh).
module tb;
  reg clk = 0, rclk = 0, rstn = 0; always #5 clk = ~clk; always #3 rclk = ~rclk;
  reg [7:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, arvalid = 0, rready = 0; reg [31:0] wdata = 0;
  wire awready, wready, bvalid, arready, rvalid; wire [1:0] bresp, rresp; wire [31:0] rdata, txc, txf, rxc, i2c, i2i, t0c; wire [0:0] hpd; wire [23:0] iof; wire [5:0] ioo;
  reg pub = 0; reg [31:0] smp = 0, hold = 0;
  hdmi_audio_regs dut (.s_axi_aclk(clk), .s_axi_aresetn(rstn), .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid),
    .s_axi_awready(awready), .s_axi_wdata(wdata), .s_axi_wstrb(4'hf), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(1'b1), .s_axi_araddr(araddr), .s_axi_arvalid(arvalid),
    .s_axi_arready(arready), .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .tx_ctrl(txc), .tx0_ctrl(t0c), .hpd2(hpd), .tx_fs_inc(txf), .rx_ctrl(rxc), .rx_pub(pub), .rx_status(2'b11), .rx_samples(hold),
    .rx_peak(32'h12345678), .rx_acr_n(20'd6144), .rx_acr_cts(20'd74250),
    .io_func(iof), .io_out(ioo), .io_in(6'b101010), .i2s_ctrl(i2c), .i2s_inc(i2i), .i2s_status(32'h0000_0A03));
  integer fails = 0;
  task wr(input [7:0] a, input [31:0] d); begin @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
    while (!awready) @(posedge clk); @(posedge clk); awvalid <= 0; wvalid <= 0; while (bvalid) @(posedge clk); end endtask
  task rd(input [7:0] a, input [31:0] want); begin @(posedge clk); araddr <= a; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; rready <= 1; @(posedge clk); rready <= 0;
    if (rdata !== want) begin fails++; $display("FAIL rd %02x = %08x want %08x", a, rdata, want); end
    @(posedge clk); end endtask
  always @(posedge rclk) begin smp <= smp + 1; if (smp[7:0] == 0) begin hold <= smp; pub <= ~pub; end end
  initial begin
    repeat (3) @(posedge clk); rstn = 1;
    wr(6'h00, 32'h0000_0107); wr(6'h04, 32'd2776544); wr(6'h08, 32'h1);
    rd(6'h00, 32'h0000_0107); rd(6'h04, 32'd2776544); rd(6'h08, 32'h1);
    if (txc !== 32'h107 || txf !== 32'd2776544 || rxc !== 1) begin fails++; $display("FAIL outputs"); end
    rd(6'h3C, 32'h48415544);
    rd(7'h50, 32'd263882791);                      // I2S_INC reset value
    wr(7'h40, 32'hFF_DC_BA98); wr(7'h44, 32'hFF); wr(7'h4C, 32'h7); wr(7'h50, 32'd1234);
    rd(7'h40, 32'h00_DC_BA98); rd(7'h44, 32'h3F); rd(7'h48, 32'h2A); rd(7'h4C, 32'h7);
    rd(7'h50, 32'd1234); rd(7'h54, 32'h0000_0A03);
    if (iof !== 24'hDCBA98 || ioo !== 6'h3F || i2c !== 7 || i2i !== 1234) begin fails++; $display("FAIL I/O outputs"); end
    rd(7'h00, 32'h0000_0107);                      // old registers unchanged
    if (hpd !== 1'b0) begin end   // rx_ctrl = 1 here (loop): HPD still high
    if (hpd !== 1'b1) begin fails++; $display("FAIL HPD not high with RX_CTRL[2] = 0"); end
    wr(7'h08, 32'h5); if (hpd !== 1'b0) begin fails++; $display("FAIL HPD not low with RX_CTRL[2] = 1"); end
    wr(7'h08, 32'h1); if (hpd !== 1'b1) begin fails++; $display("FAIL HPD not back high"); end
    wr(7'h0C, 32'h0000_0205); rd(7'h0C, 32'h0000_0205);   // TX0_CTRL (HDMI_0)
    if (t0c !== 32'h205) begin fails++; $display("FAIL TX0_CTRL output"); end
    repeat (600) @(posedge clk);
    rd(6'h10, 32'h3); rd(6'h18, 32'h12345678); rd(6'h1C, 32'd6144); rd(6'h20, 32'd74250);
    @(posedge clk); araddr <= 6'h14; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; rready <= 1; @(posedge clk); rready <= 0;
    if (rdata[7:0] !== 8'h00) begin fails++; $display("FAIL samples snapshot %08x not taken at a publish", rdata); end
    if (fails) $display("FAILED"); else $display("ALL PASS"); $finish;
  end
endmodule
