`timescale 1ns/1ps
// dz_regs_tb.sv - the register block that replaces the four AXI GPIOs
// (hw/rtl/dz_regs/dz_regs.v) against the AXI GPIO behaviour it copies: reset
// values, word / byte / halfword writes, outputs, free banks, the input with
// its synchronizer and the change interrupt (GIER, IER, toggle-on-write ISR),
// TRI read-back (run by hw/sim/run_dz_regs_tb.sh).
module tb;
  reg clk = 0, rstn = 0; always #5 clk = ~clk;
  reg [18:0] awaddr = 0, araddr = 0; reg awvalid = 0, wvalid = 0, arvalid = 0, rready = 0;
  reg [31:0] wdata = 0; reg [3:0] strb = 4'hF;
  wire awready, wready, bvalid, arready, rvalid; wire [1:0] bresp, rresp; wire [31:0] rdata;
  reg [31:0] gin = 32'h0000_0000;
  wire [31:0] b0c2, b1c1, b1c2, b3c1, b3c2, b6c1, b6c2; wire irq;
  dz_regs dut (.s_axi_aclk(clk), .s_axi_aresetn(rstn),
    .s_axi_awaddr(awaddr), .s_axi_awvalid(awvalid), .s_axi_awready(awready), .s_axi_wdata(wdata), .s_axi_wstrb(strb),
    .s_axi_wvalid(wvalid), .s_axi_wready(wready), .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(1'b1),
    .s_axi_araddr(araddr), .s_axi_arvalid(arvalid), .s_axi_arready(arready), .s_axi_rdata(rdata), .s_axi_rresp(rresp),
    .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .gpio_in(gin), .b0_ch2(b0c2), .irq(irq),
    .b1_ch1(b1c1), .b1_ch2(b1c2), .b3_ch1(b3c1), .b3_ch2(b3c2), .b6_ch1(b6c1), .b6_ch2(b6c2));
  integer fails = 0, i;
  task wr(input [18:0] a, input [31:0] d); begin @(posedge clk); awaddr <= a; wdata <= d; awvalid <= 1; wvalid <= 1;
    while (!awready) @(posedge clk); @(posedge clk); awvalid <= 0; wvalid <= 0; while (bvalid) @(posedge clk); end endtask
  task rdv(input [18:0] a, output [31:0] v); begin @(posedge clk); araddr <= a; arvalid <= 1;
    while (!rvalid) @(posedge clk); arvalid <= 0; v = rdata; rready <= 1; @(posedge clk); rready <= 0; @(posedge clk); end endtask
  task rd(input [18:0] a, input [31:0] want); reg [31:0] v; begin rdv(a, v);
    if (v !== want) begin fails++; $display("FAIL rd %05x = %08x want %08x", a, v, want); end end endtask
  task out(input [31:0] got, input [31:0] want, input string name); begin
    if (got !== want) begin fails++; $display("FAIL output %s = %08x want %08x", name, got, want); end end endtask
  // the output registers: address and reset value
  reg [18:0] oa [0:6]; reg [31:0] orst [0:6];
  initial begin
    oa[0] = 19'h0_0008; orst[0] = 32'h0100_0000;
    oa[1] = 19'h1_0000; orst[1] = 32'hFFFF_FFFF; oa[2] = 19'h1_0008; orst[2] = 32'h0000_0000;
    oa[3] = 19'h3_0000; orst[3] = 32'h0101_0101; oa[4] = 19'h3_0008; orst[4] = 32'h0000_0000;
    oa[5] = 19'h6_0000; orst[5] = 32'h01FF_FFFF; oa[6] = 19'h6_0008; orst[6] = 32'h0080_8080;
  end
  function [31:0] outv(input integer k);
    case (k) 0: outv = b0c2; 1: outv = b1c1; 2: outv = b1c2; 3: outv = b3c1; 4: outv = b3c2; 5: outv = b6c1; default: outv = b6c2; endcase
  endfunction
  reg [31:0] v;
  initial begin
    repeat (3) @(posedge clk); rstn = 1; repeat (2) @(posedge clk);
    // ---- reset values, read-back and outputs ----
    for (i = 0; i < 7; i = i + 1) begin rd(oa[i], orst[i]); out(outv(i), orst[i], "reset"); end
    // ---- word writes: each register on its own ----
    for (i = 0; i < 7; i = i + 1) wr(oa[i], 32'h1000_0000 * i + 32'h0012_3456 + i);
    for (i = 0; i < 7; i = i + 1) begin rd(oa[i], 32'h1000_0000 * i + 32'h0012_3456 + i); out(outv(i), 32'h1000_0000 * i + 32'h0012_3456 + i, "word"); end
    // ---- byte and halfword writes change only their bytes ----
    wr(19'h1_0000, 32'h1122_3344);
    strb = 4'b0100; wr(19'h1_0000, 32'hAABB_CCDD); rd(19'h1_0000, 32'h11BB_3344);    // byte 2 (gain R lane)
    strb = 4'b1000; wr(19'h1_0000, 32'h7700_0000); rd(19'h1_0000, 32'h77BB_3344);    // byte 3 (divider)
    strb = 4'b0011; wr(19'h1_0008, 32'hFFFF_BEEF); rd(19'h1_0008, 32'h0012_BEEF ^ 32'h0012_0000 | (32'h1000_0000 * 2 + 32'h0012_3456 + 2) & 32'hFFFF_0000);
    strb = 4'b1100; wr(19'h6_0000, 32'h0123_FFFF); rd(19'h6_0000, 32'h0123_0000 | (32'h1000_0000 * 5 + 32'h0012_3456 + 5) & 32'h0000_FFFF);
    strb = 4'hF;
    out(b1c1, 32'h77BB_3344, "byte");
    // a CPU byte / halfword store arrives with the low address bits set too
    // (the board test found this, 2026-10-29): +2 with lane 2, +3 with lane 3
    strb = 4'b0100; wr(19'h1_0002, 32'h00CC_0000); rd(19'h1_0000, 32'h77CC_3344);
    strb = 4'b1000; wr(19'h1_0003, 32'h5500_0000); rd(19'h1_0000, 32'h55CC_3344);
    strb = 4'b1100; wr(19'h1_0002, 32'hABCD_0000); rd(19'h1_0000, 32'hABCD_3344);
    strb = 4'hF;   rd(19'h1_0002, 32'hABCD_3344);                   // unaligned read = the word
    // ---- free banks and offsets: read 0, writes change nothing ----
    rd(19'h2_0000, 0); rd(19'h4_0000, 0); rd(19'h5_0008, 0); rd(19'h7_0000, 0); rd(19'h1_0200, 0); rd(19'h1_0010, 0);
    wr(19'h2_0000, 32'hDEAD_BEEF); wr(19'h4_0008, 32'hDEAD_BEEF); wr(19'h1_0200, 32'hDEAD_BEEF); wr(19'h3_0004, 32'hDEAD_BEEF);
    rd(19'h1_0000, 32'hABCD_3344); rd(19'h3_0000, 32'h3012_3459); rd(19'h3_0004, 0);
    // ---- TRI read-back: ch1 of bank 0 is all inputs, the rest outputs ----
    rd(19'h0_0004, 32'hFFFF_FFFF); rd(19'h0_000C, 0); rd(19'h6_000C, 0);
    // ---- input: synchronized, read-back ----
    gin = 32'hA5A5_0F0F; repeat (4) @(posedge clk); rd(19'h0_0000, 32'hA5A5_0F0F);
    if (irq !== 0) begin fails++; $display("FAIL irq without GIER/IER"); end
    // ---- interrupt: ISR set by a change, IER + GIER gate, TOW clear ----
    rd(19'h0_0120, 32'h1);                                     // the change above set ISR[0]
    wr(19'h0_0120, 32'h1); rd(19'h0_0120, 32'h0);             // write 1: clears (toggle)
    wr(19'h0_0128, 32'h1); wr(19'h0_011C, 32'h8000_0000);
    rd(19'h0_0128, 32'h1); rd(19'h0_011C, 32'h8000_0000);
    if (irq !== 0) begin fails++; $display("FAIL irq set without a change"); end
    gin = 32'hA5A5_0F0E; repeat (4) @(posedge clk);
    if (irq !== 1) begin fails++; $display("FAIL irq not set by an input change"); end
    rd(19'h0_0120, 32'h1);
    wr(19'h0_0120, 32'h1); repeat (2) @(posedge clk);
    if (irq !== 0) begin fails++; $display("FAIL irq not cleared by ISR write"); end
    wr(19'h0_0120, 32'h1); rd(19'h0_0120, 32'h1);             // TOW: a 1 on a clear bit sets it (as the IP)
    if (irq !== 1) begin fails++; $display("FAIL TOW set"); end
    wr(19'h0_0120, 32'h1);
    wr(19'h0_011C, 0); gin = 32'h0; repeat (4) @(posedge clk);
    if (irq !== 0) begin fails++; $display("FAIL irq with GIER 0"); end
    rd(19'h0_0120, 32'h1);                                     // ISR still records the change
    wr(19'h0_0120, 32'h1); wr(19'h0_0128, 0);
    // ---- reset restores the defaults ----
    rstn = 0; repeat (3) @(posedge clk); rstn = 1; repeat (2) @(posedge clk);
    for (i = 0; i < 7; i = i + 1) begin rd(oa[i], orst[i]); out(outv(i), orst[i], "reset again"); end
    rd(19'h0_011C, 0); rd(19'h0_0128, 0);
    if (bresp !== 0 || rresp !== 0) begin fails++; $display("FAIL response not OKAY"); end
    if (fails == 0) $display("dz_regs: ALL PASS"); else $display("dz_regs: %0d FAILURE(S)", fails);
    $finish;
  end
  initial begin #2ms $display("dz_regs: TIMEOUT"); $finish; end
endmodule
