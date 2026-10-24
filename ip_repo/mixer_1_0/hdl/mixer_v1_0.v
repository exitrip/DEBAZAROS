
`timescale 1 ns / 1 ps

  	module mixer_v1_0 #
	(
		// Users to add parameters here
        parameter integer OUT_WIDTH	= 32,
        parameter integer IN_WIDTH	= 32,
        parameter integer IN_NUM	= 8,
        parameter integer OUT_NUM   = 9,
		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 10
	)
	(
		// Users to add ports here
		input wire pix_clk,
    output wire [OUT_WIDTH-1 : 0] dout0, //rr
    output wire [OUT_WIDTH-1 : 0] dout1, //br
    output wire [OUT_WIDTH-1 : 0] dout2, //gr
    output wire [OUT_WIDTH-1 : 0] dout3, //rb
    output wire [OUT_WIDTH-1 : 0] dout4, //bb
    output wire [OUT_WIDTH-1 : 0] dout5, //gb
    output wire [OUT_WIDTH-1 : 0] dout6, //rg
    output wire [OUT_WIDTH-1 : 0] dout7, //bg
    output wire [OUT_WIDTH-1 : 0] dout8, //gg
    input wire [IN_WIDTH-1 : 0] din0,
    input wire [IN_WIDTH-1 : 0] din1, 
    input wire [IN_WIDTH-1 : 0] din2,
    input wire [IN_WIDTH-1 : 0] din3,   
    input wire [IN_WIDTH-1 : 0] din4,
    input wire [IN_WIDTH-1 : 0] din5,
    input wire [IN_WIDTH-1 : 0] din6,
    input wire [IN_WIDTH-1 : 0] din7,

		// User ports ends
		// Do not modify the ports beyond this line


		// Ports of Axi Slave Bus Interface S00_AXI
		input wire  s00_axi_aclk,
		input wire  s00_axi_aresetn,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_awaddr,
		input wire [2 : 0] s00_axi_awprot,
		input wire  s00_axi_awvalid,
		output wire  s00_axi_awready,
		input wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_wdata,
		input wire [(C_S00_AXI_DATA_WIDTH/8)-1 : 0] s00_axi_wstrb,
		input wire  s00_axi_wvalid,
		output wire  s00_axi_wready,
		output wire [1 : 0] s00_axi_bresp,
		output wire  s00_axi_bvalid,
		input wire  s00_axi_bready,
		input wire [C_S00_AXI_ADDR_WIDTH-1 : 0] s00_axi_araddr,
		input wire [2 : 0] s00_axi_arprot,
		input wire  s00_axi_arvalid,
		output wire  s00_axi_arready,
		output wire [C_S00_AXI_DATA_WIDTH-1 : 0] s00_axi_rdata,
		output wire [1 : 0] s00_axi_rresp,
		output wire  s00_axi_rvalid,
		input wire  s00_axi_rready
	);
	// gains[out_chan]][in_chan]
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gains [(OUT_NUM-1):0][(IN_NUM-1):0];
    // ctls[out_chan][num]
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] ctrl[(OUT_NUM-1):0][1:0];
// Instantiation of Axi Bus Interface S00_AXI
	mixer_v1_0_S00_AXI # ( 
	    .C_IN_NUM(IN_NUM),
		.C_S_AXI_DATA_WIDTH(C_S00_AXI_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(C_S00_AXI_ADDR_WIDTH)
	) mixer_v1_0_S00_AXI_inst (
		.S_AXI_ACLK(s00_axi_aclk),
		.S_AXI_ARESETN(s00_axi_aresetn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready),
	
		.GAIN_0_0(gains[0][0]),
        .GAIN_0_1(gains[0][1]),
        .GAIN_0_2(gains[0][2]),
        .GAIN_0_3(gains[0][3]),
        .GAIN_0_4(gains[0][4]),
//        .GAIN_0_5(gains[0][5]),
//        .GAIN_0_6(gains[0][6]),
//        .GAIN_0_7(gains[0][7]),
        .CTRL_0_0(ctrl[0][0]),
        .CTRL_0_1(ctrl[0][1]),
    
        .GAIN_1_0(gains[1][0]),
        .GAIN_1_1(gains[1][1]),
        .GAIN_1_2(gains[1][2]),
        .GAIN_1_3(gains[1][3]),
        .GAIN_1_4(gains[1][4]),
//        .GAIN_1_5(gains[1][5]),
//        .GAIN_1_6(gains[1][6]),
//        .GAIN_1_7(gains[1][7]),
        .CTRL_1_0(ctrl[1][0]),
        .CTRL_1_1(ctrl[1][1]),
        
        .GAIN_2_0(gains[2][0]),
        .GAIN_2_1(gains[2][1]),
        .GAIN_2_2(gains[2][2]),
        .GAIN_2_3(gains[2][3]),
        .GAIN_2_4(gains[2][4]),
//        .GAIN_2_5(gains[2][5]),
//        .GAIN_2_6(gains[2][6]),
//        .GAIN_2_7(gains[2][7]),
        .CTRL_2_0(ctrl[2][0]),
        .CTRL_2_1(ctrl[2][1]),
        
        .GAIN_3_0(gains[3][0]),
        .GAIN_3_1(gains[3][1]),
        .GAIN_3_2(gains[3][2]),
        .GAIN_3_3(gains[3][3]),
        .GAIN_3_4(gains[3][4]),
//        .GAIN_3_5(gains[3][5]),
//        .GAIN_3_6(gains[3][6]),
//        .GAIN_3_7(gains[3][7]),
        .CTRL_3_0(ctrl[3][0]),
        .CTRL_3_1(ctrl[3][1]),
    
        .GAIN_4_0(gains[4][0]),
        .GAIN_4_1(gains[4][1]),
        .GAIN_4_2(gains[4][2]),
        .GAIN_4_3(gains[4][3]),
        .GAIN_4_4(gains[4][4]),
//        .GAIN_4_5(gains[4][5]),
//        .GAIN_4_6(gains[4][6]),
//        .GAIN_4_7(gains[4][7]),
        .CTRL_4_0(ctrl[4][0]),
        .CTRL_4_1(ctrl[4][1]),
        
        .GAIN_5_0(gains[5][0]),
        .GAIN_5_1(gains[5][1]),
        .GAIN_5_2(gains[5][2]),
        .GAIN_5_3(gains[5][3]),
        .GAIN_5_4(gains[5][4]),
//        .GAIN_5_5(gains[5][5]),
//        .GAIN_5_6(gains[5][6]),
//        .GAIN_5_7(gains[5][7]),
        .CTRL_5_0(ctrl[5][0]),
        .CTRL_5_1(ctrl[5][1]),
        
        .GAIN_6_0(gains[6][0]),
        .GAIN_6_1(gains[6][1]),
        .GAIN_6_2(gains[6][2]),
        .GAIN_6_3(gains[6][3]),
        .GAIN_6_4(gains[6][4]),
//        .GAIN_6_5(gains[6][5]),
//        .GAIN_6_6(gains[6][6]),
//        .GAIN_6_7(gains[6][7]),
        .CTRL_6_0(ctrl[6][0]),
        .CTRL_6_1(ctrl[6][1]),
    
        .GAIN_7_0(gains[7][0]),
        .GAIN_7_1(gains[7][1]),
        .GAIN_7_2(gains[7][2]),
        .GAIN_7_3(gains[7][3]),
        .GAIN_7_4(gains[7][4]),
//        .GAIN_7_5(gains[7][5]),
//        .GAIN_7_6(gains[7][6]),
//        .GAIN_7_7(gains[7][7]),
        .CTRL_7_0(ctrl[7][0]),
        .CTRL_7_1(ctrl[7][1]),
        
        .GAIN_8_0(gains[8][0]),
        .GAIN_8_1(gains[8][1]),
        .GAIN_8_2(gains[8][2]),
        .GAIN_8_3(gains[8][3]),
        .GAIN_8_4(gains[8][4]),
//        .GAIN_8_5(gains[8][5]),
//        .GAIN_8_6(gains[8][6]),
//        .GAIN_8_7(gains[8][7]),
        .CTRL_8_0(ctrl[8][0]),
        .CTRL_8_1(ctrl[8][1])
	);
 
    // Two source pixel streams, indexed 0=R 1=G 2=B
    wire [IN_WIDTH-1:0] pixA [0:2];
    wire [IN_WIDTH-1:0] pixB [0:2];
    assign pixA[0] = din0;   assign pixA[1] = din1;   assign pixA[2] = din2;
    assign pixB[0] = din5;   assign pixB[1] = din6;   assign pixB[2] = din7;

    reg [OUT_WIDTH-1 : 0] dout_r [0:OUT_NUM-1];

    genvar i;
    generate
      for (i = 0; i < OUT_NUM; i = i + 1) begin : gen_chan
        // stream select: 0 = A {din0,din1,din2}, 1 = B {din5,din6,din7}
        wire sel = ctrl[i][1][0];
        // muxed RGB for mode 1
        wire [IN_WIDTH-1:0] m0 = sel ? pixB[0] : pixA[0];
        wire [IN_WIDTH-1:0] m1 = sel ? pixB[1] : pixA[1];
        wire [IN_WIDTH-1:0] m2 = sel ? pixB[2] : pixA[2];
        // comparison / passthrough source: chans 0-2 red, 3-5 green, 6-8 blue
        wire [IN_WIDTH-1:0] cmp = sel ? pixB[i/3] : pixA[i/3];

        always @(posedge pix_clk)
        begin
          case (ctrl[i][0][7:0])
            8'h0:
              dout_r[i] <= 0;
            8'h1:
              dout_r[i] <= gains[i][0]*m0 + gains[i][1]*m1 + gains[i][2]*m2
                         + gains[i][3]*din3 + gains[i][4]*din4;
            8'h3:
              dout_r[i] <= {cmp, 8'hff};
            8'h4:
              dout_r[i] <= ctrl[i][0][31:16];

            // level clipping -> pixel
            8'h10:
              dout_r[i] <= (cmp >= ctrl[i][1][23:16]) ? {cmp, 8'hff} : 0;
            8'h11:
              dout_r[i] <= (cmp <= ctrl[i][1][31:24]) ? {cmp, 8'hff} : 0;
            8'h12:
              dout_r[i] <= (cmp == ctrl[i][1][23:16]) ? {cmp, 8'hff} : 0;
            8'h13:
              dout_r[i] <= (cmp >= ctrl[i][1][23:16] && cmp <= ctrl[i][1][31:24]) ? {cmp, 8'hff} : 0;

            // level clipping -> constant K
            8'h20:
              dout_r[i] <= (cmp >= ctrl[i][1][23:16]) ? ctrl[i][0][31:16] : 0;
            8'h21:
              dout_r[i] <= (cmp <= ctrl[i][1][31:24]) ? ctrl[i][0][31:16] : 0;
            8'h22:
              dout_r[i] <= (cmp == ctrl[i][1][23:16]) ? ctrl[i][0][31:16] : 0;
            8'h23:
              dout_r[i] <= (cmp >= ctrl[i][1][23:16] && cmp <= ctrl[i][1][31:24]) ? ctrl[i][0][31:16] : 0;

            default:
              dout_r[i] <= 16'h7fff;
          endcase
        end
      end
    endgenerate

    assign dout0 = dout_r[0];
    assign dout1 = dout_r[1];
    assign dout2 = dout_r[2];
    assign dout3 = dout_r[3];
    assign dout4 = dout_r[4];
    assign dout5 = dout_r[5];
    assign dout6 = dout_r[6];
    assign dout7 = dout_r[7];
    assign dout8 = dout_r[8];

  	// User logic ends
	endmodule
  //
  // // Stream select per output channel: ctrl[i][1][0]
  // // 0 = stream A {din0,din1,din2}, 1 = stream B {din5,din6,din7}
  // wire [IN_WIDTH-1:0] mR [OUT_NUM-1:0];
  // wire [IN_WIDTH-1:0] mG [OUT_NUM-1:0];
  // wire [IN_WIDTH-1:0] mB [OUT_NUM-1:0];
	
  // genvar gi;
  // generate
  //   for (gi = 0; gi < OUT_NUM; gi = gi + 1) begin : gen_pixmux
  //     assign mR[gi] = ctrl[gi][1][0] ? din5 : din0;
  //     assign mG[gi] = ctrl[gi][1][0] ? din6 : din1;
  //     assign mB[gi] = ctrl[gi][1][0] ? din7 : din2;
  //   end
  // endgenerate

  // //TODO figure out sane ctrl regs
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[0][0][7:0])
  //       8'h0:
  //         dout0 <= 0;
  //       8'h1:
  //         dout0 <= gains[0][0]*mR[0] + gains[0][1]*mG[0] + gains[0][2]*mB[0] + gains[0][3]*din3 
  //           + gains[0][4]*din4;
  //       8'h3:
  //         dout0 <= {mR[0], 8'hff};
  //       8'h4:
  //         dout0 <= ctrl[0][0][31:16];
        
  //       //level clipping
  //       8'h10:
  //         dout0 <= (mR[0] >= ctrl[0][1][23:16]) ?  {mR[0], 8'hff} : 0;
  //       8'h11:
  //         dout0 <= (mR[0] <= ctrl[0][1][31:24]) ?  {mR[0], 8'hff} : 0;
  //       8'h12:
  //         dout0 <= (mR[0] == ctrl[0][1][23:16]) ?  {mR[0], 8'hff} : 0;
  //       8'h13:
  //         dout0 <= (mR[0] >= ctrl[0][1][23:16] && mR[0] <= ctrl[0][1][31:24]) ?  {mR[0], 8'hff} : 0;

  //       8'h20:
  //         dout0 <= (mR[0] >= ctrl[0][1][23:16]) ?  ctrl[0][0][31:16] : 0;
  //       8'h21:
  //         dout0 <= (mR[0] <= ctrl[0][1][31:24]) ?  ctrl[0][0][31:16] : 0;
  //       8'h22:
  //         dout0 <= (mR[0] == ctrl[0][1][23:16]) ?  ctrl[0][0][31:16] : 0;
  //       8'h23:
  //         dout0 <= (mR[0] >= ctrl[0][1][23:16] && mR[0] <= ctrl[0][1][31:24]) ?  ctrl[0][0][31:16] : 0;

  //       default:
  //         dout0 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[1][0][7:0])
  //       8'h0:
  //         dout1 <= 0;
  //       8'h1:
  //         dout1 <= gains[1][0]*mR[1] + gains[1][1]*mG[1] + gains[1][2]*mB[1] + gains[1][3]*din3 
  //           + gains[1][4]*din4;
  //       8'h3:
  //         dout1 <= {mR[1], 8'hff};
  //       8'h4:
  //         dout1 <= ctrl[1][0][31:16];
  //        //level clipping
  //       8'h10:
  //         dout1 <= (mR[1] >= ctrl[1][1][23:16]) ?  {mR[1], 8'hff} : 0;
  //       8'h11:
  //         dout1 <= (mR[1] <= ctrl[1][1][31:24]) ?  {mR[1], 8'hff} : 0;
  //       8'h12:
  //         dout1 <= (mR[1] == ctrl[1][1][23:16]) ?  {mR[1], 8'hff} : 0;
  //       8'h13:
  //         dout1 <= (mR[1] >= ctrl[1][1][23:16] && mR[1] <= ctrl[1][1][31:24]) ?  {mR[1], 8'hff} : 0;

  //       8'h20:
  //         dout1 <= (mR[1] >= ctrl[1][1][23:16]) ?  ctrl[1][0][31:16] : 0;
  //       8'h21:
  //         dout1 <= (mR[1] <= ctrl[1][1][31:24]) ?  ctrl[1][0][31:16] : 0;
  //       8'h22:
  //         dout1 <= (mR[1] == ctrl[1][1][23:16]) ?  ctrl[1][0][31:16] : 0;
  //       8'h23:
  //         dout1 <= (mR[1] >= ctrl[1][1][23:16] && mR[1] <= ctrl[1][1][31:24]) ?  ctrl[1][0][31:16] : 0;

  //       default:
  //         dout1 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[2][0][7:0])
  //       8'h0:
  //         dout2 <= 0;
  //       8'h1:
  //         dout2 <= gains[2][0]*mR[2] + gains[2][1]*mG[2] + gains[2][2]*mB[2] + gains[2][3]*din3 
  //           + gains[2][4]*din4;
  //       8'h3:
  //         dout2 <= {mR[2], 8'hff};
  //       8'h4:
  //         dout2 <= ctrl[2][0][31:16];
  //       //level clipping
  //       8'h10:
  //         dout2 <= (mR[2] >= ctrl[2][1][23:16]) ?  {mR[2], 8'hff} : 0;
  //       8'h11:
  //         dout2 <= (mR[2] <= ctrl[2][1][31:24]) ?  {mR[2], 8'hff} : 0;
  //       8'h12:
  //         dout2 <= (mR[2] == ctrl[2][1][23:16]) ?  {mR[2], 8'hff} : 0;
  //       8'h13:
  //         dout2 <= (mR[2] >= ctrl[2][1][23:16] && mR[2] <= ctrl[2][1][31:24]) ?  {mR[2], 8'hff} : 0;

  //       8'h20:
  //         dout2 <= (mR[2] >= ctrl[2][1][23:16]) ?  ctrl[2][0][31:16] : 0;
  //       8'h21:
  //         dout2 <= (mR[2] <= ctrl[2][1][31:24]) ?  ctrl[2][0][31:16] : 0;
  //       8'h22:
  //         dout2 <= (mR[2] == ctrl[2][1][23:16]) ?  ctrl[2][0][31:16] : 0;
  //       8'h23:
  //         dout2 <= (mR[2] >= ctrl[2][1][23:16] && mR[2] <= ctrl[2][1][31:24]) ?  ctrl[2][0][31:16] : 0;

  //       default:
  //         dout2 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[3][0][7:0])
  //       8'h0:
  //         dout3 <= 0;
  //       8'h1:
  //         dout3 <= gains[3][0]*mR[3] + gains[3][1]*mG[3] + gains[3][2]*mB[3] + gains[3][3]*din3 
  //           + gains[3][4]*din4;
  //       8'h3:
  //         dout3 <= {din1, 8'hff};
  //       8'h4:
  //         dout3 <= ctrl[3][0][31:16];
  //       //level clipping
  //       8'h10:
  //         dout3 <= (din1 >= ctrl[3][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h11:
  //         dout3 <= (din1 <= ctrl[3][1][31:24]) ?  {din1, 8'hff} : 0;
  //       8'h12:
  //         dout3 <= (din1 == ctrl[3][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h13:
  //         dout3 <= (din1 >= ctrl[3][1][23:16] && din1 <= ctrl[3][1][31:24]) ?  {din1, 8'hff} : 0;

  //       8'h20:
  //         dout3 <= (din1 >= ctrl[3][1][23:16]) ?  ctrl[3][0][31:16] : 0;
  //       8'h21:
  //         dout3 <= (din1 <= ctrl[3][1][31:24]) ?  ctrl[3][0][31:16] : 0;
  //       8'h22:
  //         dout3 <= (din1 == ctrl[3][1][23:16]) ?  ctrl[3][0][31:16] : 0;
  //       8'h23:
  //         dout3 <= (din1 >= ctrl[3][1][23:16] && din1 <= ctrl[3][1][31:24]) ?  ctrl[3][0][31:16] : 0;

  //       default:
  //         dout3 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[4][0][7:0])
  //       8'h0:
  //         dout4 <= 0;
  //       8'h1:
  //         dout4 <= gains[4][0]*din0 + gains[4][1]*din1 + gains[4][2]*din2 + gains[4][3]*din3 
  //           + gains[4][4]*din4;
  //       8'h3:
  //         dout4 <= {din1, 8'hff};
  //       8'h4:
  //         dout4 <= ctrl[4][0][31:16];
  //        //level clipping
  //       8'h10:
  //         dout4 <= (din1 >= ctrl[4][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h11:
  //         dout4 <= (din1 <= ctrl[4][1][31:24]) ?  {din1, 8'hff} : 0;
  //       8'h12:
  //         dout4 <= (din1 == ctrl[4][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h13:
  //         dout4 <= (din1 >= ctrl[4][1][23:16] && din1 <= ctrl[4][1][31:24]) ?  {din1, 8'hff} : 0;

  //       8'h20:
  //         dout4 <= (din1 >= ctrl[4][1][23:16]) ?  ctrl[4][0][31:16] : 0;
  //       8'h21:
  //         dout4 <= (din1 <= ctrl[4][1][31:24]) ?  ctrl[4][0][31:16] : 0;
  //       8'h22:
  //         dout4 <= (din1 == ctrl[4][1][23:16]) ?  ctrl[4][0][31:16] : 0;
  //       8'h23:
  //         dout4 <= (din1 >= ctrl[4][1][23:16] && din1 <= ctrl[4][1][31:24]) ?  ctrl[4][0][31:16] : 0;

  //       default:
  //         dout4 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[5][0][7:0])
  //       8'h0:
  //         dout5 <= 0;
  //       8'h1:
  //         dout5 <= gains[5][0]*din0 + gains[5][1]*din1 + gains[5][2]*din2 + gains[5][3]*din3 
  //           + gains[5][4]*din4;
  //       8'h3:
  //         dout5 <= {din1, 8'hff};
  //       8'h4:
  //         dout5 <= ctrl[5][0][31:16];
  //        //level clipping
  //       8'h10:
  //         dout5 <= (din1 >= ctrl[5][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h11:
  //         dout5 <= (din1 <= ctrl[5][1][31:24]) ?  {din1, 8'hff} : 0;
  //       8'h12:
  //         dout5 <= (din1 == ctrl[5][1][23:16]) ?  {din1, 8'hff} : 0;
  //       8'h13:
  //         dout5 <= (din1 >= ctrl[5][1][23:16] && din1 <= ctrl[5][1][31:24]) ?  {din1, 8'hff} : 0;

  //       8'h20:
  //         dout5 <= (din1 >= ctrl[5][1][23:16]) ?  ctrl[5][0][31:16] : 0;
  //       8'h21:
  //         dout5 <= (din1 <= ctrl[5][1][31:24]) ?  ctrl[5][0][31:16] : 0;
  //       8'h22:
  //         dout5 <= (din1 == ctrl[5][1][23:16]) ?  ctrl[5][0][31:16] : 0;
  //       8'h23:
  //         dout5 <= (din1 >= ctrl[5][1][23:16] && din1 <= ctrl[5][1][31:24]) ?  ctrl[5][0][31:16] : 0;

  //       default:
  //         dout5 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[6][0][7:0])
  //       8'h0:
  //         dout6 <= 0;
  //       8'h1:
  //         dout6 <= gains[6][0]*din0 + gains[6][1]*din1 + gains[6][2]*din2 + gains[6][3]*din3 
  //           + gains[6][4]*din4;
  //       8'h3:
  //         dout6 <= {din2, 8'hff};
  //       8'h4:
  //         dout6 <= ctrl[6][0][31:16];
  //                  //level clipping
  //       8'h10:
  //         dout6 <= (din2 >= ctrl[6][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h11:
  //         dout6 <= (din2 <= ctrl[6][1][31:24]) ?  {din2, 8'hff} : 0;
  //       8'h12:
  //         dout6 <= (din2 == ctrl[6][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h13:
  //         dout6 <= (din2 >= ctrl[6][1][23:16] && din2 <= ctrl[6][1][31:24]) ?  {din2, 8'hff} : 0;

  //       8'h20:
  //         dout6 <= (din2 >= ctrl[6][1][23:16]) ?  ctrl[6][0][31:16] : 0;
  //       8'h21:
  //         dout6 <= (din2 <= ctrl[6][1][31:24]) ?  ctrl[6][0][31:16] : 0;
  //       8'h22:
  //         dout6 <= (din2 == ctrl[6][1][23:16]) ?  ctrl[6][0][31:16] : 0;
  //       8'h23:
  //         dout6 <= (din2 >= ctrl[6][1][23:16] && din2 <= ctrl[6][1][31:24]) ?  ctrl[6][0][31:16] : 0;

  //       default:
  //         dout6 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[7][0][7:0])
  //       8'h0:
  //         dout7 <= 0;
  //       8'h1:
  //         dout7 <= gains[7][0]*din0 + gains[7][1]*din1 + gains[7][2]*din2 + gains[7][3]*din3 
  //           + gains[7][4]*din4;

  //       8'h3:
  //         dout7 <= {din2, 8'hff};
  //       8'h4:
  //         dout7 <= ctrl[7][0][31:16];
  //       //level clipping
  //       8'h10:
  //         dout7 <= (din2 >= ctrl[7][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h11:
  //         dout7 <= (din2 <= ctrl[7][1][31:24]) ?  {din2, 8'hff} : 0;
  //       8'h12:
  //         dout7 <= (din2 == ctrl[7][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h13:
  //         dout7 <= (din2 >= ctrl[7][1][23:16] && din2 <= ctrl[7][1][31:24]) ?  {din2, 8'hff} : 0;

  //       8'h20:
  //         dout7 <= (din2 >= ctrl[7][1][23:16]) ?  ctrl[7][0][31:16] : 0;
  //       8'h21:
  //         dout7 <= (din2 <= ctrl[7][1][31:24]) ?  ctrl[7][0][31:16] : 0;
  //       8'h22:
  //         dout7 <= (din2 == ctrl[7][1][23:16]) ?  ctrl[7][0][31:16] : 0;
  //       8'h23:
  //         dout7 <= (din2 >= ctrl[7][1][23:16] && din2 <= ctrl[7][1][31:24]) ?  ctrl[7][0][31:16] : 0;
        
  //       default:
  //         dout7 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
    
  //   always @(posedge pix_clk)
  //   begin
  //     case (ctrl[8][0][7:0])
  //       8'h0:
  //         dout8 <= 0;
  //       8'h1:
  //         dout8 <= gains[8][0]*din0 + gains[8][1]*din1 + gains[8][2]*din2 + gains[8][3]*din3 
  //           + gains[8][4]*din4;
  //       8'h3:
  //         dout8 <= {din2, 8'hff};
  //       8'h4:
  //         dout8 <= ctrl[8][0][31:16];
  //          //level clipping
  //       8'h10:
  //         dout8 <= (din2 >= ctrl[8][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h11:
  //         dout8 <= (din2 <= ctrl[8][1][31:24]) ?  {din2, 8'hff} : 0;
  //       8'h12:
  //         dout8 <= (din2 == ctrl[8][1][23:16]) ?  {din2, 8'hff} : 0;
  //       8'h13:
  //         dout8 <= (din2 >= ctrl[8][1][23:16] && din2 <= ctrl[8][1][31:24]) ?  {din2, 8'hff} : 0;

  //       8'h20:
  //         dout8 <= (din2 >= ctrl[8][1][23:16]) ?  ctrl[8][0][31:16] : 0;
  //       8'h21:
  //         dout8 <= (din2 <= ctrl[8][1][31:24]) ?  ctrl[8][0][31:16] : 0;
  //       8'h22:
  //         dout8 <= (din2 == ctrl[8][1][23:16]) ?  ctrl[8][0][31:16] : 0;
  //       8'h23:
  //         dout8 <= (din2 >= ctrl[8][1][23:16] && din2 <= ctrl[8][1][31:24]) ?  ctrl[8][0][31:16] : 0;

  //       default:
  //         dout8 <= 16'h7fff;//{OUT_WIDTH{1'b1}};
  //     endcase
  //   end
  // 
	// // User logic ends
	// endmodule