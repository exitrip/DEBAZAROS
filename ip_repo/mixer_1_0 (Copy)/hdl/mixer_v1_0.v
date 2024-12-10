
`timescale 1 ns / 1 ps

	module mixer_v1_0 #
	(
		// Users to add parameters here
        parameter integer OUT_WIDTH	= 16,
        parameter integer IN_WIDTH	= 8,
        parameter integer IN_NUM	= 8,
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
	
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] gain [8];
    wire [C_S00_AXI_DATA_WIDTH-1 : 0] ctrl [2];
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
		.GAIN(gain),
        .CTRL(ctrl)
	);
 
	// Add user logic here
	//TODO figure out sane ctrl regs
	always @( posedge pix_clk )
	begin
	  case ( ctrl[0][2:0] )
        2'h0:
          dout <= 0;
        2'h1:
          dout <= gain[0]*din0 + gain[1]*din1 + gain[2]*din2 + gain[3]*din3 
            + gain[4]*din4 + gain[5]*din5 + gain[6]*din6 + gain[7]*din7;
        2'h2:
          dout <= gain[0][7:0]*din0 + gain[1][7:0]*din1 + gain[2][7:0]*din2 
            + gain[3][7:0]*din3 + gain[4][7:0]*din4 + gain[5][7:0]*din5 
            + gain[6][7:0]*din6 + gain[7][7:0]*din7;
        2'h3:
          dout <= din0;
        default:
            dout <=  {OUT_WIDTH{1'b1}};
      endcase    
    end
	// User logic ends

	endmodule