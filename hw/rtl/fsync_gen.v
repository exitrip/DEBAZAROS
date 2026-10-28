// fsync_gen.v - frame sync for the display VDMAs (2026-10-28): the shared
// VTC's vsync (pixel clock) -> 2-FF synchronizer in the VDMA stream clock
// (FCLK2) -> a one-clock pulse at the vsync start. Both display VDMAs run
// with c_use_mm2s_fsync = 1: each MM2S frame starts at this pulse, and new
// register values (address, crop, size) take effect at a frame start. Before
// (free-running VDMA), an address commit cut the frame in progress and the
// vid_out lost lock (CLAUDE.md "Display VDMA wedge"). BD module reference.
`timescale 1ns / 1ps
module fsync_gen (
    input  wire clk,        // VDMA m_axis_mm2s_aclk (FCLK2)
    input  wire vsync,      // VTC vsync_out, active high (pixel clock domain)
    output reg  fsync = 0   // to axi_vdma mm2s_fsync, one clk at the vsync start
);
    (* ASYNC_REG = "TRUE" *) reg [1:0] vs_s = 0;
    reg vs_q = 0;
    always @(posedge clk) begin
        vs_s <= {vs_s[0], vsync};
        vs_q <= vs_s[1];
        fsync <= vs_s[1] & ~vs_q;
    end
endmodule
