
`timescale 1 ns / 1 ps

	module mixer_v1_0 #
	(
		// Users to add parameters here
        parameter integer OUT_WIDTH	= 16,
        parameter integer IN_WIDTH	= 16,
        parameter integer IN_NUM	= 4,
		// User parameters ends
		// Do not modify the parameters beyond this line


		// Parameters of Axi Slave Bus Interface S00_AXI
		parameter integer C_S00_AXI_DATA_WIDTH	= 32,
		parameter integer C_S00_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
		input wire pix_clk,
        output reg [OUT_WIDTH-1 : 0] dout,
        input wire [IN_WIDTH-1 : 0] din0,
        input wire [IN_WIDTH-1 : 0] din1,
        input wire [IN_WIDTH-1 : 0] din2,
        input wire [IN_WIDTH-1 : 0] din3,   
//        input wire [IN_WIDTH-1 : 0] din4,
//        input wire [IN_WIDTH-1 : 0] din5,
//        input wire [IN_WIDTH-1 : 0] din6,
//        input wire [IN_WIDTH-1 : 0] din7,

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
	
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_0, gain_1, gain_2, gain_3;
//    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain_4, gain_5, gain_6, gain_7;
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] ctrl_0, ctrl_1;
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
		.GAIN_0(gain_0),
		.GAIN_1(gain_1),
		.GAIN_2(gain_2),
		.GAIN_3(gain_3),
//		.GAIN_4(gain_4),
//		.GAIN_5(gain_5),
//		.GAIN_6(gain_6),
//		.GAIN_7(gain_7),
        .CTRL_0(ctrl_0),
        .CTRL_1(ctrl_1)
	);
 
	// Add user logic here
	//TODO figure out sane ctrl regs
	always @( posedge pix_clk )
	begin
	  case ( ctrl_0[2:0] )
        3'h0:
          dout <= 0;
        3'h1:
          dout <= gain_0*din0 + gain_1*din1 + gain_2*din2 + gain_3*din3; 
//            + gain_4*din4 + gain_5*din5 + gain_6*din6 + gain_7*din7;
        3'h2:
          dout <= gain_0[7:0]*din0 + gain_1[7:0]*din1 + gain_2[7:0]*din2 
            + gain_3[7:0]*din3; 
//            + gain_4[7:0]*din4 + gain_5[7:0]*din5 
//            + gain_6[7:0]*din6 + gain_7[7:0]*din7;
        3'h3:
          dout <= din0;
        default:
          dout <=  {OUT_WIDTH{1'b1}};
      endcase    
    end
	// User logic ends

	endmodule