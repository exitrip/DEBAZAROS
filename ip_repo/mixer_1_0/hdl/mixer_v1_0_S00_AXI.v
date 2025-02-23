
`timescale 1 ns / 1 ps

	module mixer_v1_0_S00_AXI #
	(
		// Users to add parameters here

		// User parameters ends
		// Do not modify the parameters beyond this line

		// Width of S_AXI data bus
		parameter integer C_S_AXI_DATA_WIDTH	= 32,
		// Width of S_AXI address bus
		parameter integer C_S_AXI_ADDR_WIDTH	= 6
	)
	(
		// Users to add ports here
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_0_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_0_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_0_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_1_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_1_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_1_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_2_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_2_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_2_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_3_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_3_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_3_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_4_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_4_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_4_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_5_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_5_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_5_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_6_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_6_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_6_1,
		
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_7_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_7_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_7_1,

		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_1,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_2,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_3,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_4,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_5,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_6,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] GAIN_8_7,
        output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_8_0,
		output reg [C_S_AXI_DATA_WIDTH-1 : 0] CTRL_8_1,

		// User ports ends
		// Do not modify the ports beyond this line`

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by local)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the local is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by local) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the local
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by local)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the local is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by local)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY
	);

	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 3;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of local Registers 9*(8+2)
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg0_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg1_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg2_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg3_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg4_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg5_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg6_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg7_9;

	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_7;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_8;
	reg [C_S_AXI_DATA_WIDTH-1:0]	local_reg8_9;

	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // localis ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // localis ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       

	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of local registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// localregister write enable is asserted when valid address and data are available
	// and the local is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      local_reg0_0 <= 0;
	      local_reg0_1 <= 0;
	      local_reg0_2 <= 0;
	      local_reg0_3 <= 0;
	      local_reg0_4 <= 0;
	      local_reg0_5 <= 0;
	      local_reg0_6 <= 0;
	      local_reg0_7 <= 0;
	      local_reg0_8 <= 0;
	      local_reg0_9 <= 0;
		  
		  local_reg1_0 <= 0;
	      local_reg1_1 <= 0;
	      local_reg1_2 <= 0;
	      local_reg1_3 <= 0;
	      local_reg1_4 <= 0;
	      local_reg1_5 <= 0;
	      local_reg1_6 <= 0;
	      local_reg1_7 <= 0;
	      local_reg1_8 <= 0;
	      local_reg1_9 <= 0;
		  
		  local_reg2_0 <= 0;
	      local_reg2_1 <= 0;
	      local_reg2_2 <= 0;
	      local_reg2_3 <= 0;
	      local_reg2_4 <= 0;
	      local_reg2_5 <= 0;
	      local_reg2_6 <= 0;
	      local_reg2_7 <= 0;
	      local_reg2_8 <= 0;
	      local_reg2_9 <= 0;
		  
		  local_reg3_0 <= 0;
	      local_reg3_1 <= 0;
	      local_reg3_2 <= 0;
	      local_reg3_3 <= 0;
	      local_reg3_4 <= 0;
	      local_reg3_5 <= 0;
	      local_reg3_6 <= 0;
	      local_reg3_7 <= 0;
	      local_reg3_8 <= 0;
	      local_reg3_9 <= 0;
		  
		  local_reg4_0 <= 0;
	      local_reg4_1 <= 0;
	      local_reg4_2 <= 0;
	      local_reg4_3 <= 0;
	      local_reg4_4 <= 0;
	      local_reg4_5 <= 0;
	      local_reg4_6 <= 0;
	      local_reg4_7 <= 0;
	      local_reg4_8 <= 0;
	      local_reg4_9 <= 0;
		  
		  local_reg5_0 <= 0;
	      local_reg5_1 <= 0;
	      local_reg5_2 <= 0;
	      local_reg5_3 <= 0;
	      local_reg5_4 <= 0;
	      local_reg5_5 <= 0;
	      local_reg5_6 <= 0;
	      local_reg5_7 <= 0;
	      local_reg5_8 <= 0;
	      local_reg5_9 <= 0;
		  
		  local_reg6_0 <= 0;
	      local_reg6_1 <= 0;
	      local_reg6_2 <= 0;
	      local_reg6_3 <= 0;
	      local_reg6_4 <= 0;
	      local_reg6_5 <= 0;
	      local_reg6_6 <= 0;
	      local_reg6_7 <= 0;
	      local_reg6_8 <= 0;
	      local_reg6_9 <= 0;
		  
		  local_reg7_0 <= 0;
	      local_reg7_1 <= 0;
	      local_reg7_2 <= 0;
	      local_reg7_3 <= 0;
	      local_reg7_4 <= 0;
	      local_reg7_5 <= 0;
	      local_reg7_6 <= 0;
	      local_reg7_7 <= 0;
	      local_reg7_8 <= 0;
	      local_reg7_9 <= 0;

		  local_reg8_0 <= 0;
	      local_reg8_1 <= 0;
	      local_reg8_2 <= 0;
	      local_reg8_3 <= 0;
	      local_reg8_4 <= 0;
	      local_reg8_5 <= 0;
	      local_reg8_6 <= 0;
	      local_reg8_7 <= 0;
	      local_reg8_8 <= 0;
	      local_reg8_9 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
			7'h00:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 0
					local_reg0_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h01:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 1
					local_reg0_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h02:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 2
					local_reg0_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h03:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 3
					local_reg0_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h04:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 4
					local_reg0_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h05:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 5
					local_reg0_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h06:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 6
					local_reg0_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h07:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 7
					local_reg0_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h08:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 8
					local_reg0_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h09:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 9
					local_reg0_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0A:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 10
					local_reg1_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0B:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 11
					local_reg1_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0C:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 12
					local_reg1_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0D:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 13
					local_reg1_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0E:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 14
					local_reg1_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h0F:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 15
					local_reg1_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h10:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 16
					local_reg1_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h11:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 17
					local_reg1_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h12:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 18
					local_reg1_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h13:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 19
					local_reg1_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h14:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 20
					local_reg2_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h15:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 21
					local_reg2_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h16:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 22
					local_reg2_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h17:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 23
					local_reg2_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h18:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 24
					local_reg2_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h19:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 25
					local_reg2_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1A:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 26
					local_reg2_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1B:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
				// Respective byte enables are asserted as per write strobes 
				// Local register 27
				local_reg2_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1C:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 28
					local_reg2_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1D:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 29
					local_reg2_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1E:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 30
					local_reg3_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h1F:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 31
					local_reg3_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h20:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 32
					local_reg3_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h21:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 33
					local_reg3_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h22:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 34
					local_reg3_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h23:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 35
					local_reg3_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h24:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 36
					local_reg3_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h25:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 37
					local_reg3_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h26:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 38
					local_reg3_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h27:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 39
					local_reg3_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h28:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 40
					local_reg4_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h29:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 41
					local_reg4_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h2A:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 42
					local_reg4_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h2B:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 43
					local_reg4_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h2C:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 44
					local_reg4_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h2D:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 45
					local_reg4_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end
			7'h2E:
            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
                // Respective byte enables are asserted as per write strobes 
                // Local register 46
                local_reg4_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
              end  
			7'h2F:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 47
					local_reg4_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h30:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 48
					local_reg4_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h31:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 49
					local_reg4_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h32:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 50
					local_reg5_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h33:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 51
					local_reg5_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h34:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 52
					local_reg5_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h35:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 53
					local_reg5_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h36:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 54
					local_reg5_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h37:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 55
					local_reg5_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h38:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 56
					local_reg5_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h39:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 57
					local_reg5_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3A:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 58
					local_reg5_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3B:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 59
					local_reg5_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3C:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 60
					local_reg6_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3D:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 61
					local_reg6_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3E:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 62
					local_reg6_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h3F:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 63
					local_reg6_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h40:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 64
					local_reg6_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h41:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 65
					local_reg6_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h42:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 66
					local_reg6_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h43:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 67
					local_reg6_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h44:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 68
					local_reg6_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h45:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 69
					local_reg6_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h46:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 70
					local_reg7_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h47:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 71
					local_reg7_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h48:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 72
					local_reg7_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h49:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 73
					local_reg7_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4A:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 74
					local_reg7_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4B:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 75
					local_reg7_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4C:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 76
					local_reg7_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4D:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 77
					local_reg7_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4E:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 78
					local_reg7_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h4F:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 79
					local_reg7_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h50:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 80
					local_reg8_0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h51:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 81
					local_reg8_1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h52:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 82
					local_reg8_2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h53:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 83
					local_reg8_3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h54:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 84
					local_reg8_4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h55:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 85
					local_reg8_5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h56:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 86
					local_reg8_6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h57:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 87
					local_reg8_7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h58:
				for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 88
					local_reg8_8[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  
			7'h59:
            	for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
				if ( S_AXI_WSTRB[byte_index] == 1 ) begin
					// Respective byte enables are asserted as per write strobes 
					// Local register 89
					local_reg8_9[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
				end  

	        default : begin
				local_reg0_0 <= local_reg0_0;
				local_reg0_1 <= local_reg0_1;
				local_reg0_2 <= local_reg0_2;
				local_reg0_3 <= local_reg0_3;
				local_reg0_4 <= local_reg0_4;
				local_reg0_5 <= local_reg0_5;
				local_reg0_6 <= local_reg0_6;
				local_reg0_7 <= local_reg0_7;
				local_reg0_8 <= local_reg0_8;
				local_reg0_9 <= local_reg0_9;
				local_reg1_0 <= local_reg1_0;
				local_reg1_1 <= local_reg1_1;
				local_reg1_2 <= local_reg1_2;
				local_reg1_3 <= local_reg1_3;
				local_reg1_4 <= local_reg1_4;
				local_reg1_5 <= local_reg1_5;
				local_reg1_6 <= local_reg1_6;
				local_reg1_7 <= local_reg1_7;
				local_reg1_8 <= local_reg1_8;
				local_reg1_9 <= local_reg1_9;
				local_reg2_0 <= local_reg2_0;
				local_reg2_1 <= local_reg2_1;
				local_reg2_2 <= local_reg2_2;
				local_reg2_3 <= local_reg2_3;
				local_reg2_4 <= local_reg2_4;
				local_reg2_5 <= local_reg2_5;
				local_reg2_6 <= local_reg2_6;
				local_reg2_7 <= local_reg2_7;
				local_reg2_8 <= local_reg2_8;
				local_reg2_9 <= local_reg2_9;
				local_reg3_0 <= local_reg3_0;
				local_reg3_1 <= local_reg3_1;
				local_reg3_2 <= local_reg3_2;
				local_reg3_3 <= local_reg3_3;
				local_reg3_4 <= local_reg3_4;
				local_reg3_5 <= local_reg3_5;
				local_reg3_6 <= local_reg3_6;
				local_reg3_7 <= local_reg3_7;
				local_reg3_8 <= local_reg3_8;
				local_reg3_9 <= local_reg3_9;
				local_reg4_0 <= local_reg4_0;
				local_reg4_1 <= local_reg4_1;
				local_reg4_2 <= local_reg4_2;
				local_reg4_3 <= local_reg4_3;
				local_reg4_4 <= local_reg4_4;
				local_reg4_5 <= local_reg4_5;
				local_reg4_6 <= local_reg4_6;
				local_reg4_7 <= local_reg4_7;
				local_reg4_8 <= local_reg4_8;
				local_reg4_9 <= local_reg4_9;
				local_reg5_0 <= local_reg5_0;
				local_reg5_1 <= local_reg5_1;
				local_reg5_2 <= local_reg5_2;
				local_reg5_3 <= local_reg5_3;
				local_reg5_4 <= local_reg5_4;
				local_reg5_5 <= local_reg5_5;
				local_reg5_6 <= local_reg5_6;
				local_reg5_7 <= local_reg5_7;
				local_reg5_8 <= local_reg5_8;
				local_reg5_9 <= local_reg5_9;
				local_reg6_0 <= local_reg6_0;
				local_reg6_1 <= local_reg6_1;
				local_reg6_2 <= local_reg6_2;
				local_reg6_3 <= local_reg6_3;
				local_reg6_4 <= local_reg6_4;
				local_reg6_5 <= local_reg6_5;
				local_reg6_6 <= local_reg6_6;
				local_reg6_7 <= local_reg6_7;
				local_reg6_8 <= local_reg6_8;
				local_reg6_9 <= local_reg6_9;
				local_reg7_0 <= local_reg7_0;
				local_reg7_1 <= local_reg7_1;
				local_reg7_2 <= local_reg7_2;
				local_reg7_3 <= local_reg7_3;
				local_reg7_4 <= local_reg7_4;
				local_reg7_5 <= local_reg7_5;
				local_reg7_6 <= local_reg7_6;
				local_reg7_7 <= local_reg7_7;
				local_reg7_8 <= local_reg7_8;
				local_reg7_9 <= local_reg7_9;
				local_reg8_0 <= local_reg8_0;
				local_reg8_1 <= local_reg8_1;
				local_reg8_2 <= local_reg8_2;
				local_reg8_3 <= local_reg8_3;
				local_reg8_4 <= local_reg8_4;
				local_reg8_5 <= local_reg8_5;
				local_reg8_6 <= local_reg8_6;
				local_reg8_7 <= local_reg8_7;
				local_reg8_8 <= local_reg8_8;
				local_reg8_9 <= local_reg8_9;
			end
	        endcase
	      end
	  end
	end    

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the local 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the local has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The local registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// localregister read enable is asserted when valid address is available
	// and the local is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	// Address decoding for reading registers
      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
        7'h00   : reg_data_out <= local_reg0_0;
        7'h01   : reg_data_out <= local_reg0_1;
        7'h02   : reg_data_out <= local_reg0_2;
        7'h03   : reg_data_out <= local_reg0_3;
        7'h04   : reg_data_out <= local_reg0_4;
        7'h05   : reg_data_out <= local_reg0_5;
        7'h06   : reg_data_out <= local_reg0_6;
        7'h07   : reg_data_out <= local_reg0_7;
        7'h08   : reg_data_out <= local_reg0_8;
        7'h09   : reg_data_out <= local_reg0_9;
        7'h0A   : reg_data_out <= local_reg1_0;
        7'h0B   : reg_data_out <= local_reg1_1;
        7'h0C   : reg_data_out <= local_reg1_2;
        7'h0D   : reg_data_out <= local_reg1_3;
        7'h0E   : reg_data_out <= local_reg1_4;
        7'h0F   : reg_data_out <= local_reg1_5;
        7'h10   : reg_data_out <= local_reg1_6;
        7'h11   : reg_data_out <= local_reg1_7;
        7'h12   : reg_data_out <= local_reg1_8;
        7'h13   : reg_data_out <= local_reg1_9;
        7'h14   : reg_data_out <= local_reg2_0;
        7'h15   : reg_data_out <= local_reg2_1;
        7'h16   : reg_data_out <= local_reg2_2;
        7'h17   : reg_data_out <= local_reg2_3;
        7'h18   : reg_data_out <= local_reg2_4;
        7'h19   : reg_data_out <= local_reg2_5;
        7'h1A   : reg_data_out <= local_reg2_6;
        7'h1B   : reg_data_out <= local_reg2_7;
        7'h1C   : reg_data_out <= local_reg2_8;
        7'h1D   : reg_data_out <= local_reg2_9;
        7'h1E   : reg_data_out <= local_reg3_0;
        7'h1F   : reg_data_out <= local_reg3_1;
        7'h20   : reg_data_out <= local_reg3_2;
        7'h21   : reg_data_out <= local_reg3_3;
        7'h22   : reg_data_out <= local_reg3_4;
        7'h23   : reg_data_out <= local_reg3_5;
        7'h24   : reg_data_out <= local_reg3_6;
        7'h25   : reg_data_out <= local_reg3_7;
        7'h26   : reg_data_out <= local_reg3_8;
        7'h27   : reg_data_out <= local_reg3_9;
        7'h28   : reg_data_out <= local_reg4_0;
        7'h29   : reg_data_out <= local_reg4_1;
        7'h2A   : reg_data_out <= local_reg4_2;
        7'h2B   : reg_data_out <= local_reg4_3;
        7'h2C   : reg_data_out <= local_reg4_4;
        7'h2D   : reg_data_out <= local_reg4_5;
        7'h2E   : reg_data_out <= local_reg4_6;
        7'h2F   : reg_data_out <= local_reg4_7;
        7'h30   : reg_data_out <= local_reg4_8;
        7'h31   : reg_data_out <= local_reg4_9;
        7'h32   : reg_data_out <= local_reg5_0;
        7'h33   : reg_data_out <= local_reg5_1;
        7'h34   : reg_data_out <= local_reg5_2;
        7'h35   : reg_data_out <= local_reg5_3;
        7'h36   : reg_data_out <= local_reg5_4;
        7'h37   : reg_data_out <= local_reg5_5;
        7'h38   : reg_data_out <= local_reg5_6;
        7'h39   : reg_data_out <= local_reg5_7;
        7'h3A   : reg_data_out <= local_reg5_8;
        7'h3B   : reg_data_out <= local_reg5_9;
        7'h3C   : reg_data_out <= local_reg6_0;
        7'h3D   : reg_data_out <= local_reg6_1;
        7'h3E   : reg_data_out <= local_reg6_2;
        7'h3F   : reg_data_out <= local_reg6_3;
        7'h40   : reg_data_out <= local_reg6_4;
        7'h41   : reg_data_out <= local_reg6_5;
        7'h42   : reg_data_out <= local_reg6_6;
        7'h43   : reg_data_out <= local_reg6_7;
        7'h44   : reg_data_out <= local_reg6_8;
        7'h45   : reg_data_out <= local_reg6_9;
        7'h46   : reg_data_out <= local_reg7_0;
        7'h47   : reg_data_out <= local_reg7_1;
        7'h48   : reg_data_out <= local_reg7_2;
        7'h49   : reg_data_out <= local_reg7_3;
        7'h4A   : reg_data_out <= local_reg7_4;
        7'h4B   : reg_data_out <= local_reg7_5;
        7'h4C   : reg_data_out <= local_reg7_6;
        7'h4D   : reg_data_out <= local_reg7_7;
        7'h4E   : reg_data_out <= local_reg7_8;
        7'h4F   : reg_data_out <= local_reg7_9;
        7'h50   : reg_data_out <= local_reg8_0;
        7'h51   : reg_data_out <= local_reg8_1;
        7'h52   : reg_data_out <= local_reg8_2;
        7'h53   : reg_data_out <= local_reg8_3;
        7'h54   : reg_data_out <= local_reg8_4;
        7'h55   : reg_data_out <= local_reg8_5;
        7'h56   : reg_data_out <= local_reg8_6;
        7'h57   : reg_data_out <= local_reg8_7;
        7'h58   : reg_data_out <= local_reg8_8;
        7'h59   : reg_data_out <= local_reg8_9;
        default : reg_data_out <= 0;
      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the local (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

	// Add user logic here
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
		  GAIN_0_0 <= local_reg0_0;
          GAIN_0_1 <= local_reg0_1;
          GAIN_0_2 <= local_reg0_2;
          GAIN_0_3 <= local_reg0_3;
          GAIN_0_4 <= local_reg0_4;
          GAIN_0_5 <= local_reg0_5;
          GAIN_0_6 <= local_reg0_6;
          GAIN_0_7 <= local_reg0_7;
          CTRL_0_0 <= local_reg0_8;
          CTRL_0_1 <= local_reg0_9;
          GAIN_1_0 <= local_reg1_0;
          GAIN_1_1 <= local_reg1_1;
          GAIN_1_2 <= local_reg1_2;
          GAIN_1_3 <= local_reg1_3;
          GAIN_1_4 <= local_reg1_4;
          GAIN_1_5 <= local_reg1_5;
          GAIN_1_6 <= local_reg1_6;
          GAIN_1_7 <= local_reg1_7;
          CTRL_1_0 <= local_reg1_8;
          CTRL_1_1 <= local_reg1_9;
          GAIN_2_0 <= local_reg2_0;
          GAIN_2_1 <= local_reg2_1;
          GAIN_2_2 <= local_reg2_2;
          GAIN_2_3 <= local_reg2_3;
          GAIN_2_4 <= local_reg2_4;
          GAIN_2_5 <= local_reg2_5;
          GAIN_2_6 <= local_reg2_6;
          GAIN_2_7 <= local_reg2_7;
          CTRL_2_0 <= local_reg2_8;
          CTRL_2_1 <= local_reg2_9;
          GAIN_3_0 <= local_reg3_0;
          GAIN_3_1 <= local_reg3_1;
          GAIN_3_2 <= local_reg3_2;
          GAIN_3_3 <= local_reg3_3;
          GAIN_3_4 <= local_reg3_4;
          GAIN_3_5 <= local_reg3_5;
          GAIN_3_6 <= local_reg3_6;
          GAIN_3_7 <= local_reg3_7;
          CTRL_3_0 <= local_reg3_8;
          CTRL_3_1 <= local_reg3_9;
          GAIN_4_0 <= local_reg4_0;
          GAIN_4_1 <= local_reg4_1;
          GAIN_4_2 <= local_reg4_2;
          GAIN_4_3 <= local_reg4_3;
          GAIN_4_4 <= local_reg4_4;
          GAIN_4_5 <= local_reg4_5;
          GAIN_4_6 <= local_reg4_6;
          GAIN_4_7 <= local_reg4_7;
          CTRL_4_0 <= local_reg4_8;
          CTRL_4_1 <= local_reg4_9;
          GAIN_5_0 <= local_reg5_0;
          GAIN_5_1 <= local_reg5_1;
          GAIN_5_2 <= local_reg5_2;
          GAIN_5_3 <= local_reg5_3;
          GAIN_5_4 <= local_reg5_4;
          GAIN_5_5 <= local_reg5_5;
          GAIN_5_6 <= local_reg5_6;
          GAIN_5_7 <= local_reg5_7;
          CTRL_5_0 <= local_reg5_8;
          CTRL_5_1 <= local_reg5_9;
          GAIN_6_0 <= local_reg6_0;
          GAIN_6_1 <= local_reg6_1;
          GAIN_6_2 <= local_reg6_2;
          GAIN_6_3 <= local_reg6_3;
          GAIN_6_4 <= local_reg6_4;
          GAIN_6_5 <= local_reg6_5;
          GAIN_6_6 <= local_reg6_6;
          GAIN_6_7 <= local_reg6_7;
          CTRL_6_0 <= local_reg6_8;
          CTRL_6_1 <= local_reg6_9;
          GAIN_7_0 <= local_reg7_0;
          GAIN_7_1 <= local_reg7_1;
          GAIN_7_2 <= local_reg7_2;
          GAIN_7_3 <= local_reg7_3;
          GAIN_7_4 <= local_reg7_4;
          GAIN_7_5 <= local_reg7_5;
          GAIN_7_6 <= local_reg7_6;
          GAIN_7_7 <= local_reg7_7;
          CTRL_7_0 <= local_reg7_8;
          CTRL_7_1 <= local_reg7_9;
          GAIN_8_0 <= local_reg8_0;
          GAIN_8_1 <= local_reg8_1;
          GAIN_8_2 <= local_reg8_2;
          GAIN_8_3 <= local_reg8_3;
          GAIN_8_4 <= local_reg8_4;
          GAIN_8_5 <= local_reg8_5;
          GAIN_8_6 <= local_reg8_6;
          GAIN_8_7 <= local_reg8_7;
          CTRL_8_0 <= local_reg8_8;
          CTRL_8_1 <= local_reg8_9;   
	    end
	end 
	// User logic ends

	endmodule