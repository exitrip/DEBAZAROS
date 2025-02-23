
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
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
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
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gains [4:0][3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_1 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_2 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_3 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_4 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_5 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_6 [3:0];
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_7 [3:0];
    // ctls[out_chan][num]
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] ctrl[4:0][1:0];
// Instantiation of Axi Bus Interface S00_AXI
	mixer_v1_0_S00_AXI # ( 
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
        .GAIN_0_5(gains[0][5]),
        .GAIN_0_6(gains[0][6]),
        .GAIN_0_7(gains[0][7]),
        .CTRL_0_0(ctrl[0][0]),
        .CTRL_0_1(ctrl[0][1]),
    
        .GAIN_1_0(gains[1][0]),
        .GAIN_1_1(gains[1][1]),
        .GAIN_1_2(gains[1][2]),
        .GAIN_1_3(gains[1][3]),
        .GAIN_1_4(gains[1][4]),
        .GAIN_1_5(gains[1][5]),
        .GAIN_1_6(gains[1][6]),
        .GAIN_1_7(gains[1][7]),
        .CTRL_1_0(ctrl[1][0]),
        .CTRL_1_1(ctrl[1][1]),
        
        .GAIN_2_0(gains[2][0]),
        .GAIN_2_1(gains[2][1]),
        .GAIN_2_2(gains[2][2]),
        .GAIN_2_3(gains[2][3]),
        .GAIN_2_4(gains[2][4]),
        .GAIN_2_5(gains[2][5]),
        .GAIN_2_6(gains[2][6]),
        .GAIN_2_7(gains[2][7]),
        .CTRL_2_0(ctrl[2][0]),
        .CTRL_2_1(ctrl[2][1]),
        
        .GAIN_3_0(gains[3][0]),
        .GAIN_3_1(gains[3][1]),
        .GAIN_3_2(gains[3][2]),
        .GAIN_3_3(gains[3][3]),
        .GAIN_3_4(gains[3][4]),
        .GAIN_3_5(gains[3][5]),
        .GAIN_3_6(gains[3][6]),
        .GAIN_3_7(gains[3][7]),
        .CTRL_3_0(ctrl[3][0]),
        .CTRL_3_1(ctrl[3][1]),
    
        .GAIN_4_0(gains[4][0]),
        .GAIN_4_1(gains[4][1]),
        .GAIN_4_2(gains[4][2]),
        .GAIN_4_3(gains[4][3]),
        .GAIN_4_4(gains[4][4]),
        .GAIN_4_5(gains[4][5]),
        .GAIN_4_6(gains[4][6]),
        .GAIN_4_7(gains[4][7]),
        .CTRL_4_0(ctrl[4][0]),
        .CTRL_4_1(ctrl[4][1]),
        
        .GAIN_5_0(gains[5][0]),
        .GAIN_5_1(gains[5][1]),
        .GAIN_5_2(gains[5][2]),
        .GAIN_5_3(gains[5][3]),
        .GAIN_5_4(gains[5][4]),
        .GAIN_5_5(gains[5][5]),
        .GAIN_5_6(gains[5][6]),
        .GAIN_5_7(gains[5][7]),
        .CTRL_5_0(ctrl[5][0]),
        .CTRL_5_1(ctrl[5][1]),
        
        .GAIN_6_0(gains[6][0]),
        .GAIN_6_1(gains[6][1]),
        .GAIN_6_2(gains[6][2]),
        .GAIN_6_3(gains[6][3]),
        .GAIN_6_4(gains[6][4]),
        .GAIN_6_5(gains[6][5]),
        .GAIN_6_6(gains[6][6]),
        .GAIN_6_7(gains[6][7]),
        .CTRL_6_0(ctrl[6][0]),
        .CTRL_6_1(ctrl[6][1]),
    
        .GAIN_7_0(gains[7][0]),
        .GAIN_7_1(gains[7][1]),
        .GAIN_7_2(gains[7][2]),
        .GAIN_7_3(gains[7][3]),
        .GAIN_7_4(gains[7][4]),
        .GAIN_7_5(gains[7][5]),
        .GAIN_7_6(gains[7][6]),
        .GAIN_7_7(gains[7][7]),
        .CTRL_7_0(ctrl[7][0]),
        .CTRL_7_1(ctrl[7][1]),
        
        .GAIN_8_0(gains[8][0]),
        .GAIN_8_1(gains[8][1]),
        .GAIN_8_2(gains[8][2]),
        .GAIN_8_3(gains[8][3]),
        .GAIN_8_4(gains[8][4]),
        .GAIN_8_5(gains[8][5]),
        .GAIN_8_6(gains[8][6]),
        .GAIN_8_7(gains[8][7]),
        .CTRL_8_0(ctrl[8][0]),
        .CTRL_8_1(ctrl[8][1])
	);
 
	// Add user logic here
	
	reg [OUT_WIDTH-1 : 0] dout[4:0];
	assign dout0 = dout[0];
    assign dout1 = dout[1];
    assign dout2 = dout[2];
    assign dout3 = dout[3];
    assign dout4 = dout[4];
    assign dout5 = dout[5];
    assign dout6 = dout[6];
    assign dout7 = dout[7];
    assign dout8 = dout[8];
    assign dout9 = dout[9]; 
    
//    genvar i;
//    generate
//      for (i = 0; i < 9; i = i + 1) begin : gen_case_block
//        always @(posedge pix_clk) 
//        begin
//          case ( ctrl[i][0][2:0] )
//            3'h0:
//              dout[i] <= 0;
//            3'h1:
//              dout[i] <= gains[i][0]*din0 + gains[i][1]*din1 + gains[i][2]*din2 + gains[i][3]*din3;
//            3'h2:
//              dout[i] <= gains[i][0][ ctrl[i][1][8:0] +: 8]*din0 + gains[i][1][ ctrl[i][1][8:0] +: 8]*din1 + 
//                gains[i][2][ ctrl[i][1][8:0] +: 8]*din2 + gains[i][3][ ctrl[i][1][8:0] +: 8]*din3;
//            3'h3:
//              dout[i] <= din0;
//            3'h4:
//              dout[i] <=  {OUT_WIDTH{1'b1}};
//            default:
//              dout[i] <=  {OUT_WIDTH{1'b1}};
//          endcase
//        end
//      end
//    endgenerate	

	//TODO figure out sane ctrl regs
	always @( posedge pix_clk )
	begin
	  case ( ctrl[0][0] )
        3'h0:
          dout[0] <= 0;
        3'h1:
          dout[0] <= gains[0][0]*din0 + gains[0][1]*din1 + gains[0][2]*din2 + gains[0][3]*din3; 
//            + gain_4*din4 + gain_5*din5 + gain_6*din6 + gain_7*din7;
        3'h2:
          dout[0] <= gains[0][0][ ctrl[0][1][8:0] +: 8]*din0 + gains[0][1][ ctrl[0][1][8:0] +: 8]*din1 + 
            gains[0][2][ ctrl[0][1][8:0] +: 8]*din2 + gains[0][3][ ctrl[0][1][8:0] +: 8]*din3; 
        3'h3:
          dout[0] <= din0;
        3'h4:
          dout[0] <=  {OUT_WIDTH{1'b1}};
        default:
          dout[0] <=  {OUT_WIDTH{1'b1}};
      endcase 
    end

	// User logic ends

	endmodule