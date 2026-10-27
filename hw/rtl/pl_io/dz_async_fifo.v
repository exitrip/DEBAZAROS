// dz_async_fifo.v - small asynchronous FIFO (gray-code pointers, 2-FF
// synchronizers, LUTRAM). Show-ahead: rd_data is the oldest word while
// !rd_empty; rd_en pops it. Level counts are as seen in each domain (they can
// lag by two clocks of the other domain). Writes into a full FIFO are lost.
`timescale 1ns / 1ps
module dz_async_fifo #(
    parameter W = 32,
    parameter AW = 3                   // depth 2^AW
) (
    input  wire          wr_clk,
    input  wire          wr_en,
    input  wire [W-1:0]  wr_data,
    output wire          wr_full,
    input  wire          rd_clk,
    input  wire          rd_en,
    output wire [W-1:0]  rd_data,
    output wire          rd_empty,
    output wire [AW:0]   rd_level
);
    reg [W-1:0] mem [0:(1<<AW)-1];
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

    wire [AW:0] wp_r = g2b(wg_s2);
    assign rd_empty = (rg == wg_s2);
    assign rd_level = wp_r - rp;
    assign rd_data = mem[rp[AW-1:0]];
    always @(posedge rd_clk) begin
        {wg_s2, wg_s1} <= {wg_s1, wg};
        if (rd_en && !rd_empty) begin
            rp <= rp + 1'b1;
            rg <= (rp + 1'b1) ^ ((rp + 1'b1) >> 1);
        end
    end
endmodule
