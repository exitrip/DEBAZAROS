// dz_bram_fifo.v - dual-clock FIFO in block RAM (512 x 32 = one BRAM18 at the
// defaults). Gray-code pointers with 2-FF synchronizers, as dz_async_fifo.
// Read side: rd_head is the oldest word; it is valid one rd_clk after a pop or
// after the FIFO became non-empty (the RAM output register re-reads the head
// address on every clock). Callers pop at most every other clock.
// rd_flush empties the FIFO from the read side (no reset across clocks).
// Writes into a full FIFO are lost; wr_full / rd_level tell the callers.
`timescale 1ns / 1ps
module dz_bram_fifo #(
    parameter W = 32,
    parameter AW = 9                   // depth 2^AW
) (
    input  wire          wr_clk,
    input  wire          wr_en,
    input  wire [W-1:0]  wr_data,
    output wire          wr_full,
    input  wire          rd_clk,
    input  wire          rd_pop,
    input  wire          rd_flush,
    output reg  [W-1:0]  rd_head = 0,
    output wire          rd_empty,
    output wire [AW:0]   rd_level
);
    (* ram_style = "block" *) reg [W-1:0] mem [0:(1<<AW)-1];
    reg [AW:0] wp = 0, wg = 0, rp = 0, rg = 0;
    (* ASYNC_REG = "TRUE" *) reg [AW:0] rg_s1 = 0, rg_s2 = 0;   // in wr_clk
    (* ASYNC_REG = "TRUE" *) reg [AW:0] wg_s1 = 0, wg_s2 = 0;   // in rd_clk

    function [AW:0] g2b;
        input [AW:0] g;
        integer i;
        begin
            g2b[AW] = g[AW];
            for (i = AW - 1; i >= 0; i = i - 1)
                g2b[i] = g2b[i + 1] ^ g[i];
        end
    endfunction

    // ---- write side --------------------------------------------------------
    wire [AW:0] rp_w = g2b(rg_s2);
    assign wr_full = (wp[AW] != rp_w[AW]) && (wp[AW-1:0] == rp_w[AW-1:0]);
    always @(posedge wr_clk) begin
        {rg_s2, rg_s1} <= {rg_s1, rg};
        if (wr_en && !wr_full) begin
            mem[wp[AW-1:0]] <= wr_data;
            wp <= wp + 1'b1;
            wg <= (wp + 1'b1) ^ ((wp + 1'b1) >> 1);
        end
    end

    // ---- read side ---------------------------------------------------------
    wire [AW:0] wp_r = g2b(wg_s2);
    assign rd_empty = (rp == wp_r);
    assign rd_level = wp_r - rp;
    wire [AW:0] rp_n = rd_flush ? wp_r : (rd_pop && !rd_empty) ? rp + 1'b1 : rp;
    always @(posedge rd_clk) begin
        {wg_s2, wg_s1} <= {wg_s1, wg};
        rp <= rp_n;
        rg <= rp_n ^ (rp_n >> 1);
        rd_head <= mem[rp_n[AW-1:0]];  // registered read: the next head
    end
endmodule
