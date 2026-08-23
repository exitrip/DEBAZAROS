module muxRGBVideo (
  input  wire sel_b,
  input  wire [23:0] pix_a,
  input  wire [23:0] pix_b,
  output wire [23:0] pix_o,
  input  wire pixClk_a,
  input  wire pixClk_b,
  output wire pixClk_o,
  input  wire serialClk_a,
  input  wire serialClk_b,
  output wire serialClk_o,
  input  wire hSync_a,
  input  wire hSync_b,
  output wire hSync_o,
  input  wire vSync_a,
  input  wire vSync_b,
  output wire vSync_o,
  input  wire pVDE_a,
  input  wire pVDE_b,
  output wire pVDE_o
);
  assign pix_o = sel_b ? pix_b : pix_a;
  assign pixClk_o = sel_b ? pixClk_b : pixClk_a;
  assign serialClk_o = sel_b ? serialClk_b : serialClk_a;
  assign hSync_o = sel_b ? hSync_b : hSync_a;
  assign vSync_o = sel_b ? vSync_b : vSync_a;
  assign pVDE_o = sel_b ? pVDE_b : pVDE_a;
endmodule
