
`timescale 1 ns / 1 ps

  	module mixer_v1_0 #
	(
		// Users to add parameters here
        parameter integer OUT_WIDTH	= 32,
        parameter integer IN_WIDTH	= 32,
        parameter integer IN_NUM	= 8,
        parameter integer OUT_NUM   = 9,
        // 1 = the colour matrix is computed here, pipelined (coreRevision
        // 26, global pixel clock): bg_in is not used; 0 = bg_in (the BD's
        // colorGainMatrix) as before
        parameter integer MATRIX_INT = 1,
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
    // colour key: HDMI_0 matrix result, HDMI_0 video before the effects,
    // keyed result (registered: 1 pixel clock later than bg_in)
    input wire [23 : 0] bg_in,
    input wire [23 : 0] vid_in,
    output wire [23 : 0] pix_out,

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
    // HDMI_0 video lanes in the same index order as din0/1/2 (bus lanes
    // [23:16], [15:8], [7:0])
    wire [IN_WIDTH-1:0] pix0 [0:2];
    assign pix0[0] = vid_in[23:16];  assign pix0[1] = vid_in[15:8];  assign pix0[2] = vid_in[7:0];

    // Colour key. Per channel, CTRL_1 [1] KEY: this channel's band test
    // (lo <= x <= hi; lo > hi = x outside hi..lo) joins the key mask, which
    // is the AND of all joined tests. CTRL_1 [2] SRC: compare HDMI_0's video
    // instead of HDMI_1's (also for modes 3, 0x10-0x13, 0x20-0x23). Global
    // bits in channel 0 CTRL_0 [15:8]: [8] invert the mask, [9] fill with
    // stream B. Key on = any channel has KEY. Keyed pixels show HDMI_1's
    // pixel instead of the matrix result. All new bits 0 = old behaviour.
    wire [OUT_NUM-1:0] key_join, key_band;

    reg [OUT_WIDTH-1 : 0] dout_r [0:OUT_NUM-1];

    // Mode 1 (coreRevision 26, 2026-11-02, global pixel clock): signed
    // operands, dout = (sum of gain_k x x_k) mod 2^24 as before: only gain
    // bits [23:0] count, so a gain word is a 24-bit two's complement number
    // and a negative gain subtracts. The colour matrix keeps the same mod
    // 2^24 sum: negative results wrap, as a row sum over 1.0 does.
    // Systolic MAC, one DSP48 per tap with its own registers (B = operand,
    // P = sum; A = the gain, quasi-static from the AXI clock): tap k takes
    // its operand k clocks later, so the shared inputs are delayed by k here.
    // Possible only with the global pixel clock (axi_dynclk revision 3): on
    // the regional BUFR clock a DSP48 with registers had to sit in clock
    // region X1Y1 (20 sites). Latency din -> dout: 8 pixel clocks (the other
    // modes: 1).
    // Operands, CTRL_1 per channel (all 0 = the old mode 1, bit for bit):
    //   taps 0-2 = R, B, G lane of stream A or B ([0]), or
    //     [3] DIFF   A - B (-255..255): with a delayed stream B = an edge /
    //                comb filter (the BRAM delay, 0x4121_0000 ch2 [29:16])
    //     [4] CENTRE the selected stream - 128 (-128..127; not with DIFF)
    //   taps 3, 4 = din3, din4 (DDS), [5] DSIGN = two's complement
    // Mode 5: dout = GAIN_chan_0 [23:0], a signed constant (Q8.16: 0x010000
    // = 1.0, 0xFF0000 = -1.0); mode 4 K stays unsigned 16 bit.
    localparam integer TAPS = 5;
    reg [7:0]        pa [0:2][0:TAPS-1];	// stream A lane l, delayed 1 + j clocks
    reg [7:0]        pb [0:2][0:TAPS-1];
    reg signed [8:0] pd [0:2][0:TAPS-1];	// A - B
    reg [15:0]       p3 [0:TAPS-1], p4 [0:TAPS-1];	// din3, din4
    integer l, j;
    always @(posedge pix_clk) begin
      for (l = 0; l < 3; l = l + 1) begin
        pa[l][0] <= pixA[l][7:0];
        pb[l][0] <= pixB[l][7:0];
        pd[l][0] <= $signed({1'b0, pixA[l][7:0]}) - $signed({1'b0, pixB[l][7:0]});
        for (j = 1; j < TAPS; j = j + 1) begin
          pa[l][j] <= pa[l][j-1];
          pb[l][j] <= pb[l][j-1];
          pd[l][j] <= pd[l][j-1];
        end
      end
      p3[0] <= din3[15:0];
      p4[0] <= din4[15:0];
      for (j = 1; j < TAPS; j = j + 1) begin
        p3[j] <= p3[j-1];
        p4[j] <= p4[j-1];
      end
    end

    genvar i;
    generate
      for (i = 0; i < OUT_NUM; i = i + 1) begin : gen_chan
        // stream select: 0 = A {din0,din1,din2}, 1 = B {din5,din6,din7}
        wire sel = ctrl[i][1][0];
        // comparison / passthrough source: chans 0-2 red, 3-5 blue, 6-8 green
        // (bus lane order); CTRL_1 [2] = HDMI_0's video instead of HDMI_1
        wire [IN_WIDTH-1:0] cmp = ctrl[i][1][2] ? pix0[i/3] : (sel ? pixB[i/3] : pixA[i/3]);
        wire [7:0] klo = ctrl[i][1][23:16];
        wire [7:0] khi = ctrl[i][1][31:24];
        assign key_join[i] = ctrl[i][1][1];
        assign key_band[i] = (klo <= khi) ? (cmp >= klo && cmp <= khi)
                                          : (cmp >= klo || cmp <= khi);

        // mode 1: operand of tap k from the inputs delayed k clocks
        // ("- 128" of an 8-bit value = its MSB inverted, signed), then the
        // systolic sum (DSP48 B register, P register, PCIN cascade)
        wire diff = ctrl[i][1][3], centre = ctrl[i][1][4], dsign = ctrl[i][1][5];
        reg signed [17:0] x [0:TAPS-1];
        reg signed [23:0] s [0:TAPS-1];	// signed: else x would be zero-extended
        integer t;
        always @(posedge pix_clk) begin
          for (t = 0; t < 3; t = t + 1)
            x[t] <= diff   ? {{9{pd[t][t][8]}}, pd[t][t]} :
                    centre ? {{10{~(sel ? pb[t][t][7] : pa[t][t][7])}}, ~(sel ? pb[t][t][7] : pa[t][t][7]),
                              (sel ? pb[t][t][6:0] : pa[t][t][6:0])} :
                             {10'd0, sel ? pb[t][t] : pa[t][t]};
          x[3] <= dsign ? {{2{p3[3][15]}}, p3[3]} : {2'b00, p3[3]};
          x[4] <= dsign ? {{2{p4[4][15]}}, p4[4]} : {2'b00, p4[4]};
          s[0] <= $signed(gains[i][0][24:0]) * x[0];
          for (t = 1; t < TAPS; t = t + 1)
            s[t] <= s[t-1] + $signed(gains[i][t][24:0]) * x[t];
        end

        always @(posedge pix_clk)
        begin
          case (ctrl[i][0][7:0])
            8'h0:
              dout_r[i] <= 0;
            8'h1:
              dout_r[i] <= s[TAPS-1];
            8'h5:
              dout_r[i] <= gains[i][0][23:0];
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

    // Key mux. The output register is always in the path, so the picture
    // does not move when the key turns on or off, and it breaks the
    // HDMI_1 -> HDMI_0 -> HDMI_1 feedback loop after the matrix.
    wire [23:0] fill = ctrl[0][0][9] ? {din5[7:0], din6[7:0], din7[7:0]}
                                     : {din0[7:0], din1[7:0], din2[7:0]};
    wire keyed = (|key_join) & ((&(key_band | ~key_join)) ^ ctrl[0][0][8]);
    reg [23:0] pix_r;
    generate
      if (MATRIX_INT) begin : g_matrix
        // The colour matrix (coreRevision 26): the BD's colorGainMatrix,
        // bit for bit. Per output lane the sum of 3 products (pixel lane, 8
        // bit unsigned, x gain dout, 24 bit) mod 2^24, the lane = [23:16]:
        //   [23:16] = R d0 + G d2 + B d1   [15:8] = R d3 + G d4 + B d5
        //   [7:0]   = R d6 + G d7 + B d8   (R = vid_in[23:16], G = [7:0], B = [15:8])
        // Systolic, 3 DSP48 per lane (A = gain, B = pixel, P cascade): tap k
        // (R, G, B) takes pixel and gain k clocks later. Latency 4: the key
        // (mask and fill) is delayed by 4 as well, so pix_out = 5 clocks
        // after vid_in / dout (bg_in path: 1). The BD's colorGainMatrix then
        // has no load and is removed by synthesis.
        reg [7:0]  r1, g1, g2, b1, b2, b3;
        reg [23:0] ga [0:2], gb1 [0:2], gb2 [0:2], gc1 [0:2], gc2 [0:2], gc3 [0:2];
        reg [23:0] q0 [0:2], q1 [0:2], q2 [0:2];
        reg [3:0]  kd;
        reg [23:0] fd [0:3];
        wire [23:0] dA [0:2], dB [0:2], dC [0:2];	// per lane: gains of R, G, B
        assign dA[0] = dout_r[0]; assign dB[0] = dout_r[2]; assign dC[0] = dout_r[1];
        assign dA[1] = dout_r[3]; assign dB[1] = dout_r[4]; assign dC[1] = dout_r[5];
        assign dA[2] = dout_r[6]; assign dB[2] = dout_r[7]; assign dC[2] = dout_r[8];
        integer m;
        always @(posedge pix_clk) begin
          r1 <= vid_in[23:16];
          g1 <= vid_in[7:0];  g2 <= g1;
          b1 <= vid_in[15:8]; b2 <= b1; b3 <= b2;
          for (m = 0; m < 3; m = m + 1) begin
            ga[m]  <= dA[m];
            gb1[m] <= dB[m]; gb2[m] <= gb1[m];
            gc1[m] <= dC[m]; gc2[m] <= gc1[m]; gc3[m] <= gc2[m];
            q0[m] <= ga[m] * r1;
            q1[m] <= q0[m] + gb2[m] * g2;
            q2[m] <= q1[m] + gc3[m] * b3;
          end
          kd <= {kd[2:0], keyed};
          fd[0] <= fill; fd[1] <= fd[0]; fd[2] <= fd[1]; fd[3] <= fd[2];
          pix_r <= kd[3] ? fd[3] : {q2[0][23:16], q2[1][23:16], q2[2][23:16]};
        end
      end else begin : g_bg
        always @(posedge pix_clk)
          pix_r <= keyed ? fill : bg_in;
      end
    endgenerate
    assign pix_out = pix_r;

  	// User logic ends
	endmodule
