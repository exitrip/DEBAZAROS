// hdmi_tx_cdc.v - the 30 TMDS bits of one output from the global pixel clock
// (wclk, BUFG) to the OSERDES CLKDIV (rclk, BUFR / 5) (2026-11-02, ROADMAP.md
// task 20). Both clocks have the same frequency, but the BUFR divider starts
// at any one of 5 serial clocks after its CLR: the phase is unknown, so a
// FIFO (8 words, LUTRAM, gray-code pointers) and not a register. The read
// side starts at 4 words and then takes one word per clock; the level stays
// constant. Empty (a clock stopped or glitched: MMCM relock): it waits for 4
// words again; full: it jumps back to 4 words (the oldest are lost). Both resets assert asynchronously
// (aRst_n = dynclk LOCKED) and clear the pointers.
// Only for the BUFIO/BUFR variant (axi_dynclk kSerialBufg = false); with the
// BUFG pair the OSERDES take the pixel-clock data directly.
`timescale 1ns / 1ps
module hdmi_tx_cdc #(
    parameter W = 30
) (
    input  wire         wclk,
    input  wire         wrst,          // synchronous to wclk, active high
    input  wire [W-1:0] wdata,
    input  wire         rclk,
    input  wire         rrst,          // synchronous to rclk, active high
    output reg  [W-1:0] rdata = 0
);
    (* ram_style = "distributed" *) reg [W-1:0] mem [0:7];
    reg [3:0] wp = 0, wg = 0, rp = 0;
    (* ASYNC_REG = "TRUE" *) reg [3:0] wg_s1 = 0, wg_s2 = 0;   // in rclk

    function [3:0] g2b;
        input [3:0] g;
        begin
            g2b[3] = g[3];
            g2b[2] = g2b[3] ^ g[2];
            g2b[1] = g2b[2] ^ g[1];
            g2b[0] = g2b[1] ^ g[0];
        end
    endfunction

    // write side: one word per clock (a full FIFO only on a clock fault;
    // the read side then restarts)
    always @(posedge wclk) begin
        if (wrst) begin
            wp <= 0;
            wg <= 0;
        end else begin
            mem[wp[2:0]] <= wdata;
            wp <= wp + 1'b1;
            wg <= (wp + 1'b1) ^ ((wp + 1'b1) >> 1);
        end
    end

    // read side
    wire [3:0] level = g2b(wg_s2) - rp;
    wire [3:0] jp = g2b(wg_s2) - 4'd4;          // 4 words behind the writer
    reg run = 0;
    always @(posedge rclk) begin
        {wg_s2, wg_s1} <= {wg_s1, wg};
        if (rrst) begin
            rp <= 0;
            run <= 0;
            {wg_s2, wg_s1} <= 0;
            rdata <= 0;
        end else begin
            if (level[3]) begin                  // full: jump back to 4 words
                rdata <= mem[jp[2:0]];           // (and read on: no word twice)
                rp <= jp + 1'b1;
            end else begin
                if (!run)
                    run <= level >= 4'd4;
                else if (level == 0)             // empty: wait for 4 words
                    run <= 0;
                if (run && level != 0) begin
                    rdata <= mem[rp[2:0]];
                    rp <= rp + 1'b1;
                end
            end
        end
    end
endmodule
