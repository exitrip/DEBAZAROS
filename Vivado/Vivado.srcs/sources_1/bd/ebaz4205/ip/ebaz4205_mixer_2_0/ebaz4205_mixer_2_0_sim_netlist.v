// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
// Date        : Sat Feb 22 19:57:40 2025
// Host        : antmicro-debug running 64-bit Ubuntu 24.04.2 LTS
// Command     : write_verilog -force -mode funcsim
//               /home/aescape/Documents/github/DEBAZAROS/Vivado/Vivado.gen/sources_1/bd/ebaz4205/ip/ebaz4205_mixer_2_0_1/ebaz4205_mixer_2_0_sim_netlist.v
// Design      : ebaz4205_mixer_2_0
// Purpose     : This verilog netlist is a functional simulation representation of the design and should not be modified
//               or synthesized. This netlist cannot be used for SDF annotated simulation.
// Device      : xc7z010clg400-1
// --------------------------------------------------------------------------------
`timescale 1 ps / 1 ps

(* CHECK_LICENSE_TYPE = "ebaz4205_mixer_2_0,mixer_v1_0,{}" *) (* DowngradeIPIdentifiedWarnings = "yes" *) (* X_CORE_INFO = "mixer_v1_0,Vivado 2022.2" *) 
(* NotValidForBitStream *)
module ebaz4205_mixer_2_0
   (pix_clk,
    dout,
    din0,
    din1,
    din2,
    s00_axi_aclk,
    s00_axi_aresetn,
    s00_axi_awaddr,
    s00_axi_awprot,
    s00_axi_awvalid,
    s00_axi_awready,
    s00_axi_wdata,
    s00_axi_wstrb,
    s00_axi_wvalid,
    s00_axi_wready,
    s00_axi_bresp,
    s00_axi_bvalid,
    s00_axi_bready,
    s00_axi_araddr,
    s00_axi_arprot,
    s00_axi_arvalid,
    s00_axi_arready,
    s00_axi_rdata,
    s00_axi_rresp,
    s00_axi_rvalid,
    s00_axi_rready);
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 pix_clk CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME pix_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN ebaz4205_axi_dynclk_0_0_PXL_CLK_O, INSERT_VIP 0" *) input pix_clk;
  output [15:0]dout;
  input [15:0]din0;
  input [15:0]din1;
  input [15:0]din2;
  (* X_INTERFACE_INFO = "xilinx.com:signal:clock:1.0 S00_AXI_CLK CLK" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S00_AXI_CLK, ASSOCIATED_BUSIF S00_AXI, ASSOCIATED_RESET s00_axi_aresetn, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN ebaz4205_processing_system7_0_0_FCLK_CLK0, INSERT_VIP 0" *) input s00_axi_aclk;
  (* X_INTERFACE_INFO = "xilinx.com:signal:reset:1.0 S00_AXI_RST RST" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S00_AXI_RST, POLARITY ACTIVE_LOW, INSERT_VIP 0" *) input s00_axi_aresetn;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWADDR" *) input [5:0]s00_axi_awaddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWPROT" *) input [2:0]s00_axi_awprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWVALID" *) input s00_axi_awvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI AWREADY" *) output s00_axi_awready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WDATA" *) input [31:0]s00_axi_wdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WSTRB" *) input [3:0]s00_axi_wstrb;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WVALID" *) input s00_axi_wvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI WREADY" *) output s00_axi_wready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BRESP" *) output [1:0]s00_axi_bresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BVALID" *) output s00_axi_bvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI BREADY" *) input s00_axi_bready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARADDR" *) input [5:0]s00_axi_araddr;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARPROT" *) input [2:0]s00_axi_arprot;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARVALID" *) input s00_axi_arvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI ARREADY" *) output s00_axi_arready;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RDATA" *) output [31:0]s00_axi_rdata;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RRESP" *) output [1:0]s00_axi_rresp;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RVALID" *) output s00_axi_rvalid;
  (* X_INTERFACE_INFO = "xilinx.com:interface:aximm:1.0 S00_AXI RREADY" *) (* X_INTERFACE_PARAMETER = "XIL_INTERFACENAME S00_AXI, WIZ_DATA_WIDTH 32, WIZ_NUM_REG 10, SUPPORTS_NARROW_BURST 0, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 6, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN ebaz4205_processing_system7_0_0_FCLK_CLK0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0" *) input s00_axi_rready;

  wire \<const0> ;
  wire [15:8]B;
  wire [15:0]din0;
  wire [15:0]din1;
  wire [15:0]din2;
  wire [15:0]dout;
  wire inst_n_13;
  wire inst_n_14;
  wire inst_n_15;
  wire inst_n_16;
  wire inst_n_17;
  wire inst_n_18;
  wire inst_n_19;
  wire inst_n_20;
  wire inst_n_21;
  wire inst_n_22;
  wire inst_n_23;
  wire inst_n_24;
  wire inst_n_25;
  wire inst_n_26;
  wire inst_n_27;
  wire inst_n_28;
  wire inst_n_29;
  wire inst_n_30;
  wire inst_n_31;
  wire inst_n_32;
  wire inst_n_33;
  wire inst_n_34;
  wire inst_n_35;
  wire inst_n_36;
  wire inst_n_37;
  wire inst_n_38;
  wire inst_n_39;
  wire inst_n_40;
  wire inst_n_41;
  wire inst_n_42;
  wire inst_n_43;
  wire inst_n_44;
  wire inst_n_45;
  wire inst_n_46;
  wire inst_n_47;
  wire inst_n_48;
  wire inst_n_49;
  wire inst_n_50;
  wire inst_n_51;
  wire inst_n_52;
  wire inst_n_53;
  wire inst_n_54;
  wire inst_n_55;
  wire inst_n_56;
  wire inst_n_57;
  wire inst_n_58;
  wire inst_n_59;
  wire inst_n_60;
  wire inst_n_61;
  wire inst_n_62;
  wire inst_n_63;
  wire inst_n_64;
  wire inst_n_65;
  wire inst_n_66;
  wire inst_n_67;
  wire inst_n_68;
  wire [15:0]p_0_out__0;
  wire p_0_out_n_74;
  wire p_0_out_n_75;
  wire p_0_out_n_76;
  wire p_0_out_n_77;
  wire p_0_out_n_78;
  wire p_0_out_n_79;
  wire p_0_out_n_80;
  wire p_0_out_n_81;
  wire p_0_out_n_82;
  wire p_0_out_n_83;
  wire p_0_out_n_84;
  wire p_0_out_n_85;
  wire p_0_out_n_86;
  wire p_0_out_n_87;
  wire p_0_out_n_88;
  wire p_0_out_n_89;
  wire p_1_out__0_n_100;
  wire p_1_out__0_n_101;
  wire p_1_out__0_n_102;
  wire p_1_out__0_n_103;
  wire p_1_out__0_n_104;
  wire p_1_out__0_n_105;
  wire p_1_out__0_n_106;
  wire p_1_out__0_n_107;
  wire p_1_out__0_n_108;
  wire p_1_out__0_n_109;
  wire p_1_out__0_n_110;
  wire p_1_out__0_n_111;
  wire p_1_out__0_n_112;
  wire p_1_out__0_n_113;
  wire p_1_out__0_n_114;
  wire p_1_out__0_n_115;
  wire p_1_out__0_n_116;
  wire p_1_out__0_n_117;
  wire p_1_out__0_n_118;
  wire p_1_out__0_n_119;
  wire p_1_out__0_n_120;
  wire p_1_out__0_n_121;
  wire p_1_out__0_n_122;
  wire p_1_out__0_n_123;
  wire p_1_out__0_n_124;
  wire p_1_out__0_n_125;
  wire p_1_out__0_n_126;
  wire p_1_out__0_n_127;
  wire p_1_out__0_n_128;
  wire p_1_out__0_n_129;
  wire p_1_out__0_n_130;
  wire p_1_out__0_n_131;
  wire p_1_out__0_n_132;
  wire p_1_out__0_n_133;
  wire p_1_out__0_n_134;
  wire p_1_out__0_n_135;
  wire p_1_out__0_n_136;
  wire p_1_out__0_n_137;
  wire p_1_out__0_n_138;
  wire p_1_out__0_n_139;
  wire p_1_out__0_n_140;
  wire p_1_out__0_n_141;
  wire p_1_out__0_n_142;
  wire p_1_out__0_n_143;
  wire p_1_out__0_n_144;
  wire p_1_out__0_n_145;
  wire p_1_out__0_n_146;
  wire p_1_out__0_n_147;
  wire p_1_out__0_n_148;
  wire p_1_out__0_n_149;
  wire p_1_out__0_n_150;
  wire p_1_out__0_n_151;
  wire p_1_out__0_n_152;
  wire p_1_out__0_n_153;
  wire p_1_out__0_n_90;
  wire p_1_out__0_n_91;
  wire p_1_out__0_n_92;
  wire p_1_out__0_n_93;
  wire p_1_out__0_n_94;
  wire p_1_out__0_n_95;
  wire p_1_out__0_n_96;
  wire p_1_out__0_n_97;
  wire p_1_out__0_n_98;
  wire p_1_out__0_n_99;
  wire p_1_out__1_n_100;
  wire p_1_out__1_n_101;
  wire p_1_out__1_n_102;
  wire p_1_out__1_n_103;
  wire p_1_out__1_n_104;
  wire p_1_out__1_n_105;
  wire p_1_out__1_n_90;
  wire p_1_out__1_n_91;
  wire p_1_out__1_n_92;
  wire p_1_out__1_n_93;
  wire p_1_out__1_n_94;
  wire p_1_out__1_n_95;
  wire p_1_out__1_n_96;
  wire p_1_out__1_n_97;
  wire p_1_out__1_n_98;
  wire p_1_out__1_n_99;
  wire p_1_out_n_100;
  wire p_1_out_n_101;
  wire p_1_out_n_102;
  wire p_1_out_n_103;
  wire p_1_out_n_104;
  wire p_1_out_n_105;
  wire p_1_out_n_106;
  wire p_1_out_n_107;
  wire p_1_out_n_108;
  wire p_1_out_n_109;
  wire p_1_out_n_110;
  wire p_1_out_n_111;
  wire p_1_out_n_112;
  wire p_1_out_n_113;
  wire p_1_out_n_114;
  wire p_1_out_n_115;
  wire p_1_out_n_116;
  wire p_1_out_n_117;
  wire p_1_out_n_118;
  wire p_1_out_n_119;
  wire p_1_out_n_120;
  wire p_1_out_n_121;
  wire p_1_out_n_122;
  wire p_1_out_n_123;
  wire p_1_out_n_124;
  wire p_1_out_n_125;
  wire p_1_out_n_126;
  wire p_1_out_n_127;
  wire p_1_out_n_128;
  wire p_1_out_n_129;
  wire p_1_out_n_130;
  wire p_1_out_n_131;
  wire p_1_out_n_132;
  wire p_1_out_n_133;
  wire p_1_out_n_134;
  wire p_1_out_n_135;
  wire p_1_out_n_136;
  wire p_1_out_n_137;
  wire p_1_out_n_138;
  wire p_1_out_n_139;
  wire p_1_out_n_140;
  wire p_1_out_n_141;
  wire p_1_out_n_142;
  wire p_1_out_n_143;
  wire p_1_out_n_144;
  wire p_1_out_n_145;
  wire p_1_out_n_146;
  wire p_1_out_n_147;
  wire p_1_out_n_148;
  wire p_1_out_n_149;
  wire p_1_out_n_150;
  wire p_1_out_n_151;
  wire p_1_out_n_152;
  wire p_1_out_n_153;
  wire p_1_out_n_90;
  wire p_1_out_n_91;
  wire p_1_out_n_92;
  wire p_1_out_n_93;
  wire p_1_out_n_94;
  wire p_1_out_n_95;
  wire p_1_out_n_96;
  wire p_1_out_n_97;
  wire p_1_out_n_98;
  wire p_1_out_n_99;
  wire pix_clk;
  wire s00_axi_aclk;
  wire s00_axi_aresetn;
  wire s00_axi_arready;
  wire s00_axi_arvalid;
  wire [5:0]s00_axi_awaddr;
  wire s00_axi_awready;
  wire s00_axi_awvalid;
  wire s00_axi_bready;
  wire s00_axi_bvalid;
  wire s00_axi_rready;
  wire s00_axi_rvalid;
  wire [31:0]s00_axi_wdata;
  wire s00_axi_wready;
  wire [3:0]s00_axi_wstrb;
  wire s00_axi_wvalid;
  wire NLW_p_0_out_CARRYCASCOUT_UNCONNECTED;
  wire NLW_p_0_out_MULTSIGNOUT_UNCONNECTED;
  wire NLW_p_0_out_OVERFLOW_UNCONNECTED;
  wire NLW_p_0_out_PATTERNBDETECT_UNCONNECTED;
  wire NLW_p_0_out_PATTERNDETECT_UNCONNECTED;
  wire NLW_p_0_out_UNDERFLOW_UNCONNECTED;
  wire [29:0]NLW_p_0_out_ACOUT_UNCONNECTED;
  wire [17:0]NLW_p_0_out_BCOUT_UNCONNECTED;
  wire [3:0]NLW_p_0_out_CARRYOUT_UNCONNECTED;
  wire [47:32]NLW_p_0_out_P_UNCONNECTED;
  wire [47:0]NLW_p_0_out_PCOUT_UNCONNECTED;
  wire NLW_p_1_out_CARRYCASCOUT_UNCONNECTED;
  wire NLW_p_1_out_MULTSIGNOUT_UNCONNECTED;
  wire NLW_p_1_out_OVERFLOW_UNCONNECTED;
  wire NLW_p_1_out_PATTERNBDETECT_UNCONNECTED;
  wire NLW_p_1_out_PATTERNDETECT_UNCONNECTED;
  wire NLW_p_1_out_UNDERFLOW_UNCONNECTED;
  wire [29:0]NLW_p_1_out_ACOUT_UNCONNECTED;
  wire [17:0]NLW_p_1_out_BCOUT_UNCONNECTED;
  wire [3:0]NLW_p_1_out_CARRYOUT_UNCONNECTED;
  wire [47:16]NLW_p_1_out_P_UNCONNECTED;
  wire NLW_p_1_out__0_CARRYCASCOUT_UNCONNECTED;
  wire NLW_p_1_out__0_MULTSIGNOUT_UNCONNECTED;
  wire NLW_p_1_out__0_OVERFLOW_UNCONNECTED;
  wire NLW_p_1_out__0_PATTERNBDETECT_UNCONNECTED;
  wire NLW_p_1_out__0_PATTERNDETECT_UNCONNECTED;
  wire NLW_p_1_out__0_UNDERFLOW_UNCONNECTED;
  wire [29:0]NLW_p_1_out__0_ACOUT_UNCONNECTED;
  wire [17:0]NLW_p_1_out__0_BCOUT_UNCONNECTED;
  wire [3:0]NLW_p_1_out__0_CARRYOUT_UNCONNECTED;
  wire [47:16]NLW_p_1_out__0_P_UNCONNECTED;
  wire NLW_p_1_out__1_CARRYCASCOUT_UNCONNECTED;
  wire NLW_p_1_out__1_MULTSIGNOUT_UNCONNECTED;
  wire NLW_p_1_out__1_OVERFLOW_UNCONNECTED;
  wire NLW_p_1_out__1_PATTERNBDETECT_UNCONNECTED;
  wire NLW_p_1_out__1_PATTERNDETECT_UNCONNECTED;
  wire NLW_p_1_out__1_UNDERFLOW_UNCONNECTED;
  wire [29:0]NLW_p_1_out__1_ACOUT_UNCONNECTED;
  wire [17:0]NLW_p_1_out__1_BCOUT_UNCONNECTED;
  wire [3:0]NLW_p_1_out__1_CARRYOUT_UNCONNECTED;
  wire [47:16]NLW_p_1_out__1_P_UNCONNECTED;
  wire [47:0]NLW_p_1_out__1_PCOUT_UNCONNECTED;

  assign s00_axi_bresp[1] = \<const0> ;
  assign s00_axi_bresp[0] = \<const0> ;
  assign s00_axi_rdata[31] = \<const0> ;
  assign s00_axi_rdata[30] = \<const0> ;
  assign s00_axi_rdata[29] = \<const0> ;
  assign s00_axi_rdata[28] = \<const0> ;
  assign s00_axi_rdata[27] = \<const0> ;
  assign s00_axi_rdata[26] = \<const0> ;
  assign s00_axi_rdata[25] = \<const0> ;
  assign s00_axi_rdata[24] = \<const0> ;
  assign s00_axi_rdata[23] = \<const0> ;
  assign s00_axi_rdata[22] = \<const0> ;
  assign s00_axi_rdata[21] = \<const0> ;
  assign s00_axi_rdata[20] = \<const0> ;
  assign s00_axi_rdata[19] = \<const0> ;
  assign s00_axi_rdata[18] = \<const0> ;
  assign s00_axi_rdata[17] = \<const0> ;
  assign s00_axi_rdata[16] = \<const0> ;
  assign s00_axi_rdata[15] = \<const0> ;
  assign s00_axi_rdata[14] = \<const0> ;
  assign s00_axi_rdata[13] = \<const0> ;
  assign s00_axi_rdata[12] = \<const0> ;
  assign s00_axi_rdata[11] = \<const0> ;
  assign s00_axi_rdata[10] = \<const0> ;
  assign s00_axi_rdata[9] = \<const0> ;
  assign s00_axi_rdata[8] = \<const0> ;
  assign s00_axi_rdata[7] = \<const0> ;
  assign s00_axi_rdata[6] = \<const0> ;
  assign s00_axi_rdata[5] = \<const0> ;
  assign s00_axi_rdata[4] = \<const0> ;
  assign s00_axi_rdata[3] = \<const0> ;
  assign s00_axi_rdata[2] = \<const0> ;
  assign s00_axi_rdata[1] = \<const0> ;
  assign s00_axi_rdata[0] = \<const0> ;
  assign s00_axi_rresp[1] = \<const0> ;
  assign s00_axi_rresp[0] = \<const0> ;
  GND GND
       (.G(\<const0> ));
  ebaz4205_mixer_2_0_mixer_v1_0 inst
       (.A({inst_n_21,inst_n_22,inst_n_23,inst_n_24,inst_n_25,inst_n_26,inst_n_27,inst_n_28,inst_n_29,inst_n_30,inst_n_31,inst_n_32,inst_n_33,inst_n_34,inst_n_35,inst_n_36}),
        .B({B,inst_n_13,inst_n_14,inst_n_15,inst_n_16,inst_n_17,inst_n_18,inst_n_19,inst_n_20}),
        .\GAIN_1_reg[15] ({inst_n_53,inst_n_54,inst_n_55,inst_n_56,inst_n_57,inst_n_58,inst_n_59,inst_n_60,inst_n_61,inst_n_62,inst_n_63,inst_n_64,inst_n_65,inst_n_66,inst_n_67,inst_n_68}),
        .\GAIN_2_reg[15] ({inst_n_37,inst_n_38,inst_n_39,inst_n_40,inst_n_41,inst_n_42,inst_n_43,inst_n_44,inst_n_45,inst_n_46,inst_n_47,inst_n_48,inst_n_49,inst_n_50,inst_n_51,inst_n_52}),
        .P({p_1_out__1_n_90,p_1_out__1_n_91,p_1_out__1_n_92,p_1_out__1_n_93,p_1_out__1_n_94,p_1_out__1_n_95,p_1_out__1_n_96,p_1_out__1_n_97,p_1_out__1_n_98,p_1_out__1_n_99,p_1_out__1_n_100,p_1_out__1_n_101,p_1_out__1_n_102,p_1_out__1_n_103,p_1_out__1_n_104,p_1_out__1_n_105}),
        .din0(din0),
        .dout(dout),
        .pix_clk(pix_clk),
        .s00_axi_aclk(s00_axi_aclk),
        .s00_axi_aresetn(s00_axi_aresetn),
        .s00_axi_arready(s00_axi_arready),
        .s00_axi_arvalid(s00_axi_arvalid),
        .s00_axi_awaddr(s00_axi_awaddr[5:2]),
        .s00_axi_awready(s00_axi_awready),
        .s00_axi_awvalid(s00_axi_awvalid),
        .s00_axi_bready(s00_axi_bready),
        .s00_axi_bvalid(s00_axi_bvalid),
        .s00_axi_rready(s00_axi_rready),
        .s00_axi_rvalid(s00_axi_rvalid),
        .s00_axi_wdata(s00_axi_wdata[15:0]),
        .s00_axi_wready(s00_axi_wready),
        .s00_axi_wstrb(s00_axi_wstrb[1:0]),
        .s00_axi_wvalid(s00_axi_wvalid));
  (* METHODOLOGY_DRC_VIOS = "{SYNTH-13 {cell *THIS*}}" *) 
  DSP48E1 #(
    .ACASCREG(0),
    .ADREG(1),
    .ALUMODEREG(0),
    .AREG(0),
    .AUTORESET_PATDET("NO_RESET"),
    .A_INPUT("DIRECT"),
    .BCASCREG(0),
    .BREG(0),
    .B_INPUT("DIRECT"),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .CREG(1),
    .DREG(1),
    .INMODEREG(0),
    .MASK(48'h3FFFFFFFFFFF),
    .MREG(0),
    .OPMODEREG(0),
    .PATTERN(48'h000000000000),
    .PREG(0),
    .SEL_MASK("MASK"),
    .SEL_PATTERN("PATTERN"),
    .USE_DPORT("FALSE"),
    .USE_MULT("MULTIPLY"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .USE_SIMD("ONE48")) 
    p_0_out
       (.A({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,din2}),
        .ACIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ACOUT(NLW_p_0_out_ACOUT_UNCONNECTED[29:0]),
        .ALUMODE({1'b0,1'b0,1'b0,1'b0}),
        .B({1'b0,1'b0,inst_n_37,inst_n_38,inst_n_39,inst_n_40,inst_n_41,inst_n_42,inst_n_43,inst_n_44,inst_n_45,inst_n_46,inst_n_47,inst_n_48,inst_n_49,inst_n_50,inst_n_51,inst_n_52}),
        .BCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .BCOUT(NLW_p_0_out_BCOUT_UNCONNECTED[17:0]),
        .C({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CARRYCASCIN(1'b0),
        .CARRYCASCOUT(NLW_p_0_out_CARRYCASCOUT_UNCONNECTED),
        .CARRYIN(1'b0),
        .CARRYINSEL({1'b0,1'b0,1'b0}),
        .CARRYOUT(NLW_p_0_out_CARRYOUT_UNCONNECTED[3:0]),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEAD(1'b0),
        .CEALUMODE(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b0),
        .CED(1'b0),
        .CEINMODE(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .CLK(1'b0),
        .D({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .INMODE({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .MULTSIGNIN(1'b0),
        .MULTSIGNOUT(NLW_p_0_out_MULTSIGNOUT_UNCONNECTED),
        .OPMODE({1'b0,1'b0,1'b0,1'b0,1'b1,1'b0,1'b1}),
        .OVERFLOW(NLW_p_0_out_OVERFLOW_UNCONNECTED),
        .P({NLW_p_0_out_P_UNCONNECTED[47:32],p_0_out_n_74,p_0_out_n_75,p_0_out_n_76,p_0_out_n_77,p_0_out_n_78,p_0_out_n_79,p_0_out_n_80,p_0_out_n_81,p_0_out_n_82,p_0_out_n_83,p_0_out_n_84,p_0_out_n_85,p_0_out_n_86,p_0_out_n_87,p_0_out_n_88,p_0_out_n_89,p_0_out__0}),
        .PATTERNBDETECT(NLW_p_0_out_PATTERNBDETECT_UNCONNECTED),
        .PATTERNDETECT(NLW_p_0_out_PATTERNDETECT_UNCONNECTED),
        .PCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PCOUT(NLW_p_0_out_PCOUT_UNCONNECTED[47:0]),
        .RSTA(1'b0),
        .RSTALLCARRYIN(1'b0),
        .RSTALUMODE(1'b0),
        .RSTB(1'b0),
        .RSTC(1'b0),
        .RSTCTRL(1'b0),
        .RSTD(1'b0),
        .RSTINMODE(1'b0),
        .RSTM(1'b0),
        .RSTP(1'b0),
        .UNDERFLOW(NLW_p_0_out_UNDERFLOW_UNCONNECTED));
  (* METHODOLOGY_DRC_VIOS = "{SYNTH-13 {cell *THIS*}}" *) 
  DSP48E1 #(
    .ACASCREG(0),
    .ADREG(1),
    .ALUMODEREG(0),
    .AREG(0),
    .AUTORESET_PATDET("NO_RESET"),
    .A_INPUT("DIRECT"),
    .BCASCREG(0),
    .BREG(0),
    .B_INPUT("DIRECT"),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .CREG(0),
    .DREG(1),
    .INMODEREG(0),
    .MASK(48'h3FFFFFFFFFFF),
    .MREG(0),
    .OPMODEREG(0),
    .PATTERN(48'h000000000000),
    .PREG(0),
    .SEL_MASK("MASK"),
    .SEL_PATTERN("PATTERN"),
    .USE_DPORT("FALSE"),
    .USE_MULT("MULTIPLY"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .USE_SIMD("ONE48")) 
    p_1_out
       (.A({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,din1}),
        .ACIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ACOUT(NLW_p_1_out_ACOUT_UNCONNECTED[29:0]),
        .ALUMODE({1'b0,1'b0,1'b0,1'b0}),
        .B({1'b0,1'b0,inst_n_53,inst_n_54,inst_n_55,inst_n_56,inst_n_57,inst_n_58,inst_n_59,inst_n_60,inst_n_61,inst_n_62,inst_n_63,inst_n_64,inst_n_65,inst_n_66,inst_n_67,inst_n_68}),
        .BCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .BCOUT(NLW_p_1_out_BCOUT_UNCONNECTED[17:0]),
        .C({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,p_0_out__0}),
        .CARRYCASCIN(1'b0),
        .CARRYCASCOUT(NLW_p_1_out_CARRYCASCOUT_UNCONNECTED),
        .CARRYIN(1'b0),
        .CARRYINSEL({1'b0,1'b0,1'b0}),
        .CARRYOUT(NLW_p_1_out_CARRYOUT_UNCONNECTED[3:0]),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEAD(1'b0),
        .CEALUMODE(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b0),
        .CED(1'b0),
        .CEINMODE(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .CLK(1'b0),
        .D({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .INMODE({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .MULTSIGNIN(1'b0),
        .MULTSIGNOUT(NLW_p_1_out_MULTSIGNOUT_UNCONNECTED),
        .OPMODE({1'b0,1'b1,1'b1,1'b0,1'b1,1'b0,1'b1}),
        .OVERFLOW(NLW_p_1_out_OVERFLOW_UNCONNECTED),
        .P({NLW_p_1_out_P_UNCONNECTED[47:16],p_1_out_n_90,p_1_out_n_91,p_1_out_n_92,p_1_out_n_93,p_1_out_n_94,p_1_out_n_95,p_1_out_n_96,p_1_out_n_97,p_1_out_n_98,p_1_out_n_99,p_1_out_n_100,p_1_out_n_101,p_1_out_n_102,p_1_out_n_103,p_1_out_n_104,p_1_out_n_105}),
        .PATTERNBDETECT(NLW_p_1_out_PATTERNBDETECT_UNCONNECTED),
        .PATTERNDETECT(NLW_p_1_out_PATTERNDETECT_UNCONNECTED),
        .PCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .PCOUT({p_1_out_n_106,p_1_out_n_107,p_1_out_n_108,p_1_out_n_109,p_1_out_n_110,p_1_out_n_111,p_1_out_n_112,p_1_out_n_113,p_1_out_n_114,p_1_out_n_115,p_1_out_n_116,p_1_out_n_117,p_1_out_n_118,p_1_out_n_119,p_1_out_n_120,p_1_out_n_121,p_1_out_n_122,p_1_out_n_123,p_1_out_n_124,p_1_out_n_125,p_1_out_n_126,p_1_out_n_127,p_1_out_n_128,p_1_out_n_129,p_1_out_n_130,p_1_out_n_131,p_1_out_n_132,p_1_out_n_133,p_1_out_n_134,p_1_out_n_135,p_1_out_n_136,p_1_out_n_137,p_1_out_n_138,p_1_out_n_139,p_1_out_n_140,p_1_out_n_141,p_1_out_n_142,p_1_out_n_143,p_1_out_n_144,p_1_out_n_145,p_1_out_n_146,p_1_out_n_147,p_1_out_n_148,p_1_out_n_149,p_1_out_n_150,p_1_out_n_151,p_1_out_n_152,p_1_out_n_153}),
        .RSTA(1'b0),
        .RSTALLCARRYIN(1'b0),
        .RSTALUMODE(1'b0),
        .RSTB(1'b0),
        .RSTC(1'b0),
        .RSTCTRL(1'b0),
        .RSTD(1'b0),
        .RSTINMODE(1'b0),
        .RSTM(1'b0),
        .RSTP(1'b0),
        .UNDERFLOW(NLW_p_1_out_UNDERFLOW_UNCONNECTED));
  (* METHODOLOGY_DRC_VIOS = "{SYNTH-13 {cell *THIS*}}" *) 
  DSP48E1 #(
    .ACASCREG(0),
    .ADREG(1),
    .ALUMODEREG(0),
    .AREG(0),
    .AUTORESET_PATDET("NO_RESET"),
    .A_INPUT("DIRECT"),
    .BCASCREG(0),
    .BREG(0),
    .B_INPUT("DIRECT"),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .CREG(1),
    .DREG(1),
    .INMODEREG(0),
    .MASK(48'h3FFFFFFFFFFF),
    .MREG(0),
    .OPMODEREG(0),
    .PATTERN(48'h000000000000),
    .PREG(0),
    .SEL_MASK("MASK"),
    .SEL_PATTERN("PATTERN"),
    .USE_DPORT("FALSE"),
    .USE_MULT("MULTIPLY"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .USE_SIMD("ONE48")) 
    p_1_out__0
       (.A({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,inst_n_21,inst_n_22,inst_n_23,inst_n_24,inst_n_25,inst_n_26,inst_n_27,inst_n_28,inst_n_29,inst_n_30,inst_n_31,inst_n_32,inst_n_33,inst_n_34,inst_n_35,inst_n_36}),
        .ACIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ACOUT(NLW_p_1_out__0_ACOUT_UNCONNECTED[29:0]),
        .ALUMODE({1'b0,1'b0,1'b0,1'b0}),
        .B({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .BCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .BCOUT(NLW_p_1_out__0_BCOUT_UNCONNECTED[17:0]),
        .C({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CARRYCASCIN(1'b0),
        .CARRYCASCOUT(NLW_p_1_out__0_CARRYCASCOUT_UNCONNECTED),
        .CARRYIN(1'b0),
        .CARRYINSEL({1'b0,1'b0,1'b0}),
        .CARRYOUT(NLW_p_1_out__0_CARRYOUT_UNCONNECTED[3:0]),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEAD(1'b0),
        .CEALUMODE(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b0),
        .CED(1'b0),
        .CEINMODE(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .CLK(1'b0),
        .D({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .INMODE({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .MULTSIGNIN(1'b0),
        .MULTSIGNOUT(NLW_p_1_out__0_MULTSIGNOUT_UNCONNECTED),
        .OPMODE({1'b0,1'b0,1'b1,1'b0,1'b1,1'b0,1'b1}),
        .OVERFLOW(NLW_p_1_out__0_OVERFLOW_UNCONNECTED),
        .P({NLW_p_1_out__0_P_UNCONNECTED[47:16],p_1_out__0_n_90,p_1_out__0_n_91,p_1_out__0_n_92,p_1_out__0_n_93,p_1_out__0_n_94,p_1_out__0_n_95,p_1_out__0_n_96,p_1_out__0_n_97,p_1_out__0_n_98,p_1_out__0_n_99,p_1_out__0_n_100,p_1_out__0_n_101,p_1_out__0_n_102,p_1_out__0_n_103,p_1_out__0_n_104,p_1_out__0_n_105}),
        .PATTERNBDETECT(NLW_p_1_out__0_PATTERNBDETECT_UNCONNECTED),
        .PATTERNDETECT(NLW_p_1_out__0_PATTERNDETECT_UNCONNECTED),
        .PCIN({p_1_out_n_106,p_1_out_n_107,p_1_out_n_108,p_1_out_n_109,p_1_out_n_110,p_1_out_n_111,p_1_out_n_112,p_1_out_n_113,p_1_out_n_114,p_1_out_n_115,p_1_out_n_116,p_1_out_n_117,p_1_out_n_118,p_1_out_n_119,p_1_out_n_120,p_1_out_n_121,p_1_out_n_122,p_1_out_n_123,p_1_out_n_124,p_1_out_n_125,p_1_out_n_126,p_1_out_n_127,p_1_out_n_128,p_1_out_n_129,p_1_out_n_130,p_1_out_n_131,p_1_out_n_132,p_1_out_n_133,p_1_out_n_134,p_1_out_n_135,p_1_out_n_136,p_1_out_n_137,p_1_out_n_138,p_1_out_n_139,p_1_out_n_140,p_1_out_n_141,p_1_out_n_142,p_1_out_n_143,p_1_out_n_144,p_1_out_n_145,p_1_out_n_146,p_1_out_n_147,p_1_out_n_148,p_1_out_n_149,p_1_out_n_150,p_1_out_n_151,p_1_out_n_152,p_1_out_n_153}),
        .PCOUT({p_1_out__0_n_106,p_1_out__0_n_107,p_1_out__0_n_108,p_1_out__0_n_109,p_1_out__0_n_110,p_1_out__0_n_111,p_1_out__0_n_112,p_1_out__0_n_113,p_1_out__0_n_114,p_1_out__0_n_115,p_1_out__0_n_116,p_1_out__0_n_117,p_1_out__0_n_118,p_1_out__0_n_119,p_1_out__0_n_120,p_1_out__0_n_121,p_1_out__0_n_122,p_1_out__0_n_123,p_1_out__0_n_124,p_1_out__0_n_125,p_1_out__0_n_126,p_1_out__0_n_127,p_1_out__0_n_128,p_1_out__0_n_129,p_1_out__0_n_130,p_1_out__0_n_131,p_1_out__0_n_132,p_1_out__0_n_133,p_1_out__0_n_134,p_1_out__0_n_135,p_1_out__0_n_136,p_1_out__0_n_137,p_1_out__0_n_138,p_1_out__0_n_139,p_1_out__0_n_140,p_1_out__0_n_141,p_1_out__0_n_142,p_1_out__0_n_143,p_1_out__0_n_144,p_1_out__0_n_145,p_1_out__0_n_146,p_1_out__0_n_147,p_1_out__0_n_148,p_1_out__0_n_149,p_1_out__0_n_150,p_1_out__0_n_151,p_1_out__0_n_152,p_1_out__0_n_153}),
        .RSTA(1'b0),
        .RSTALLCARRYIN(1'b0),
        .RSTALUMODE(1'b0),
        .RSTB(1'b0),
        .RSTC(1'b0),
        .RSTCTRL(1'b0),
        .RSTD(1'b0),
        .RSTINMODE(1'b0),
        .RSTM(1'b0),
        .RSTP(1'b0),
        .UNDERFLOW(NLW_p_1_out__0_UNDERFLOW_UNCONNECTED));
  (* METHODOLOGY_DRC_VIOS = "{SYNTH-13 {cell *THIS*}}" *) 
  DSP48E1 #(
    .ACASCREG(0),
    .ADREG(1),
    .ALUMODEREG(0),
    .AREG(0),
    .AUTORESET_PATDET("NO_RESET"),
    .A_INPUT("DIRECT"),
    .BCASCREG(0),
    .BREG(0),
    .B_INPUT("DIRECT"),
    .CARRYINREG(0),
    .CARRYINSELREG(0),
    .CREG(1),
    .DREG(1),
    .INMODEREG(0),
    .MASK(48'h3FFFFFFFFFFF),
    .MREG(0),
    .OPMODEREG(0),
    .PATTERN(48'h000000000000),
    .PREG(0),
    .SEL_MASK("MASK"),
    .SEL_PATTERN("PATTERN"),
    .USE_DPORT("FALSE"),
    .USE_MULT("MULTIPLY"),
    .USE_PATTERN_DETECT("NO_PATDET"),
    .USE_SIMD("ONE48")) 
    p_1_out__1
       (.A({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,din0}),
        .ACIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .ACOUT(NLW_p_1_out__1_ACOUT_UNCONNECTED[29:0]),
        .ALUMODE({1'b0,1'b0,1'b0,1'b0}),
        .B({1'b0,1'b0,B,inst_n_13,inst_n_14,inst_n_15,inst_n_16,inst_n_17,inst_n_18,inst_n_19,inst_n_20}),
        .BCIN({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .BCOUT(NLW_p_1_out__1_BCOUT_UNCONNECTED[17:0]),
        .C({1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1,1'b1}),
        .CARRYCASCIN(1'b0),
        .CARRYCASCOUT(NLW_p_1_out__1_CARRYCASCOUT_UNCONNECTED),
        .CARRYIN(1'b0),
        .CARRYINSEL({1'b0,1'b0,1'b0}),
        .CARRYOUT(NLW_p_1_out__1_CARRYOUT_UNCONNECTED[3:0]),
        .CEA1(1'b0),
        .CEA2(1'b0),
        .CEAD(1'b0),
        .CEALUMODE(1'b0),
        .CEB1(1'b0),
        .CEB2(1'b0),
        .CEC(1'b0),
        .CECARRYIN(1'b0),
        .CECTRL(1'b0),
        .CED(1'b0),
        .CEINMODE(1'b0),
        .CEM(1'b0),
        .CEP(1'b0),
        .CLK(1'b0),
        .D({1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0,1'b0}),
        .INMODE({1'b0,1'b0,1'b0,1'b0,1'b0}),
        .MULTSIGNIN(1'b0),
        .MULTSIGNOUT(NLW_p_1_out__1_MULTSIGNOUT_UNCONNECTED),
        .OPMODE({1'b0,1'b0,1'b1,1'b0,1'b1,1'b0,1'b1}),
        .OVERFLOW(NLW_p_1_out__1_OVERFLOW_UNCONNECTED),
        .P({NLW_p_1_out__1_P_UNCONNECTED[47:16],p_1_out__1_n_90,p_1_out__1_n_91,p_1_out__1_n_92,p_1_out__1_n_93,p_1_out__1_n_94,p_1_out__1_n_95,p_1_out__1_n_96,p_1_out__1_n_97,p_1_out__1_n_98,p_1_out__1_n_99,p_1_out__1_n_100,p_1_out__1_n_101,p_1_out__1_n_102,p_1_out__1_n_103,p_1_out__1_n_104,p_1_out__1_n_105}),
        .PATTERNBDETECT(NLW_p_1_out__1_PATTERNBDETECT_UNCONNECTED),
        .PATTERNDETECT(NLW_p_1_out__1_PATTERNDETECT_UNCONNECTED),
        .PCIN({p_1_out__0_n_106,p_1_out__0_n_107,p_1_out__0_n_108,p_1_out__0_n_109,p_1_out__0_n_110,p_1_out__0_n_111,p_1_out__0_n_112,p_1_out__0_n_113,p_1_out__0_n_114,p_1_out__0_n_115,p_1_out__0_n_116,p_1_out__0_n_117,p_1_out__0_n_118,p_1_out__0_n_119,p_1_out__0_n_120,p_1_out__0_n_121,p_1_out__0_n_122,p_1_out__0_n_123,p_1_out__0_n_124,p_1_out__0_n_125,p_1_out__0_n_126,p_1_out__0_n_127,p_1_out__0_n_128,p_1_out__0_n_129,p_1_out__0_n_130,p_1_out__0_n_131,p_1_out__0_n_132,p_1_out__0_n_133,p_1_out__0_n_134,p_1_out__0_n_135,p_1_out__0_n_136,p_1_out__0_n_137,p_1_out__0_n_138,p_1_out__0_n_139,p_1_out__0_n_140,p_1_out__0_n_141,p_1_out__0_n_142,p_1_out__0_n_143,p_1_out__0_n_144,p_1_out__0_n_145,p_1_out__0_n_146,p_1_out__0_n_147,p_1_out__0_n_148,p_1_out__0_n_149,p_1_out__0_n_150,p_1_out__0_n_151,p_1_out__0_n_152,p_1_out__0_n_153}),
        .PCOUT(NLW_p_1_out__1_PCOUT_UNCONNECTED[47:0]),
        .RSTA(1'b0),
        .RSTALLCARRYIN(1'b0),
        .RSTALUMODE(1'b0),
        .RSTB(1'b0),
        .RSTC(1'b0),
        .RSTCTRL(1'b0),
        .RSTD(1'b0),
        .RSTINMODE(1'b0),
        .RSTM(1'b0),
        .RSTP(1'b0),
        .UNDERFLOW(NLW_p_1_out__1_UNDERFLOW_UNCONNECTED));
endmodule

(* ORIG_REF_NAME = "mixer_v1_0" *) 
module ebaz4205_mixer_2_0_mixer_v1_0
   (s00_axi_awready,
    s00_axi_wready,
    s00_axi_arready,
    s00_axi_bvalid,
    s00_axi_rvalid,
    B,
    A,
    \GAIN_2_reg[15] ,
    \GAIN_1_reg[15] ,
    dout,
    s00_axi_aclk,
    s00_axi_arvalid,
    s00_axi_aresetn,
    s00_axi_awvalid,
    s00_axi_wvalid,
    s00_axi_bready,
    s00_axi_rready,
    s00_axi_awaddr,
    s00_axi_wdata,
    pix_clk,
    s00_axi_wstrb,
    din0,
    P);
  output s00_axi_awready;
  output s00_axi_wready;
  output s00_axi_arready;
  output s00_axi_bvalid;
  output s00_axi_rvalid;
  output [15:0]B;
  output [15:0]A;
  output [15:0]\GAIN_2_reg[15] ;
  output [15:0]\GAIN_1_reg[15] ;
  output [15:0]dout;
  input s00_axi_aclk;
  input s00_axi_arvalid;
  input s00_axi_aresetn;
  input s00_axi_awvalid;
  input s00_axi_wvalid;
  input s00_axi_bready;
  input s00_axi_rready;
  input [3:0]s00_axi_awaddr;
  input [15:0]s00_axi_wdata;
  input pix_clk;
  input [1:0]s00_axi_wstrb;
  input [15:0]din0;
  input [15:0]P;

  wire [15:0]A;
  wire [15:0]B;
  wire [2:0]CTRL_0;
  wire [15:0]\GAIN_1_reg[15] ;
  wire [15:0]\GAIN_2_reg[15] ;
  wire [15:0]P;
  wire [15:0]din0;
  wire [15:0]dout;
  wire \dout[0]_i_1_n_0 ;
  wire \dout[10]_i_1_n_0 ;
  wire \dout[11]_i_1_n_0 ;
  wire \dout[12]_i_1_n_0 ;
  wire \dout[13]_i_1_n_0 ;
  wire \dout[14]_i_1_n_0 ;
  wire \dout[15]_i_1_n_0 ;
  wire \dout[1]_i_1_n_0 ;
  wire \dout[2]_i_1_n_0 ;
  wire \dout[3]_i_1_n_0 ;
  wire \dout[4]_i_1_n_0 ;
  wire \dout[5]_i_1_n_0 ;
  wire \dout[6]_i_1_n_0 ;
  wire \dout[7]_i_1_n_0 ;
  wire \dout[8]_i_1_n_0 ;
  wire \dout[9]_i_1_n_0 ;
  wire mixer_v1_0_S00_AXI_inst_n_10;
  wire mixer_v1_0_S00_AXI_inst_n_11;
  wire mixer_v1_0_S00_AXI_inst_n_12;
  wire mixer_v1_0_S00_AXI_inst_n_13;
  wire mixer_v1_0_S00_AXI_inst_n_14;
  wire mixer_v1_0_S00_AXI_inst_n_15;
  wire mixer_v1_0_S00_AXI_inst_n_24;
  wire mixer_v1_0_S00_AXI_inst_n_25;
  wire mixer_v1_0_S00_AXI_inst_n_26;
  wire mixer_v1_0_S00_AXI_inst_n_27;
  wire mixer_v1_0_S00_AXI_inst_n_28;
  wire mixer_v1_0_S00_AXI_inst_n_29;
  wire mixer_v1_0_S00_AXI_inst_n_30;
  wire mixer_v1_0_S00_AXI_inst_n_31;
  wire mixer_v1_0_S00_AXI_inst_n_40;
  wire mixer_v1_0_S00_AXI_inst_n_41;
  wire mixer_v1_0_S00_AXI_inst_n_42;
  wire mixer_v1_0_S00_AXI_inst_n_43;
  wire mixer_v1_0_S00_AXI_inst_n_44;
  wire mixer_v1_0_S00_AXI_inst_n_45;
  wire mixer_v1_0_S00_AXI_inst_n_46;
  wire mixer_v1_0_S00_AXI_inst_n_47;
  wire mixer_v1_0_S00_AXI_inst_n_56;
  wire mixer_v1_0_S00_AXI_inst_n_57;
  wire mixer_v1_0_S00_AXI_inst_n_58;
  wire mixer_v1_0_S00_AXI_inst_n_59;
  wire mixer_v1_0_S00_AXI_inst_n_60;
  wire mixer_v1_0_S00_AXI_inst_n_61;
  wire mixer_v1_0_S00_AXI_inst_n_62;
  wire mixer_v1_0_S00_AXI_inst_n_63;
  wire mixer_v1_0_S00_AXI_inst_n_8;
  wire mixer_v1_0_S00_AXI_inst_n_9;
  wire pix_clk;
  wire s00_axi_aclk;
  wire s00_axi_aresetn;
  wire s00_axi_arready;
  wire s00_axi_arvalid;
  wire [3:0]s00_axi_awaddr;
  wire s00_axi_awready;
  wire s00_axi_awvalid;
  wire s00_axi_bready;
  wire s00_axi_bvalid;
  wire s00_axi_rready;
  wire s00_axi_rvalid;
  wire [15:0]s00_axi_wdata;
  wire s00_axi_wready;
  wire [1:0]s00_axi_wstrb;
  wire s00_axi_wvalid;

  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[0]_i_1 
       (.I0(din0[0]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[0]),
        .O(\dout[0]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[10]_i_1 
       (.I0(din0[10]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[10]),
        .O(\dout[10]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[11]_i_1 
       (.I0(din0[11]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[11]),
        .O(\dout[11]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[12]_i_1 
       (.I0(din0[12]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[12]),
        .O(\dout[12]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[13]_i_1 
       (.I0(din0[13]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[13]),
        .O(\dout[13]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[14]_i_1 
       (.I0(din0[14]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[14]),
        .O(\dout[14]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[15]_i_1 
       (.I0(din0[15]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[15]),
        .O(\dout[15]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[1]_i_1 
       (.I0(din0[1]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[1]),
        .O(\dout[1]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[2]_i_1 
       (.I0(din0[2]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[2]),
        .O(\dout[2]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[3]_i_1 
       (.I0(din0[3]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[3]),
        .O(\dout[3]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[4]_i_1 
       (.I0(din0[4]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[4]),
        .O(\dout[4]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[5]_i_1 
       (.I0(din0[5]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[5]),
        .O(\dout[5]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[6]_i_1 
       (.I0(din0[6]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[6]),
        .O(\dout[6]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[7]_i_1 
       (.I0(din0[7]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[7]),
        .O(\dout[7]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[8]_i_1 
       (.I0(din0[8]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[8]),
        .O(\dout[8]_i_1_n_0 ));
  LUT4 #(
    .INIT(16'hBC80)) 
    \dout[9]_i_1 
       (.I0(din0[9]),
        .I1(CTRL_0[0]),
        .I2(CTRL_0[1]),
        .I3(P[9]),
        .O(\dout[9]_i_1_n_0 ));
  FDSE \dout_reg[0] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[0]_i_1_n_0 ),
        .Q(dout[0]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[10] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[10]_i_1_n_0 ),
        .Q(dout[10]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[11] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[11]_i_1_n_0 ),
        .Q(dout[11]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[12] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[12]_i_1_n_0 ),
        .Q(dout[12]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[13] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[13]_i_1_n_0 ),
        .Q(dout[13]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[14] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[14]_i_1_n_0 ),
        .Q(dout[14]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[15] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[15]_i_1_n_0 ),
        .Q(dout[15]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[1] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[1]_i_1_n_0 ),
        .Q(dout[1]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[2] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[2]_i_1_n_0 ),
        .Q(dout[2]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[3] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[3]_i_1_n_0 ),
        .Q(dout[3]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[4] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[4]_i_1_n_0 ),
        .Q(dout[4]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[5] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[5]_i_1_n_0 ),
        .Q(dout[5]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[6] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[6]_i_1_n_0 ),
        .Q(dout[6]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[7] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[7]_i_1_n_0 ),
        .Q(dout[7]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[8] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[8]_i_1_n_0 ),
        .Q(dout[8]),
        .S(CTRL_0[2]));
  FDSE \dout_reg[9] 
       (.C(pix_clk),
        .CE(1'b1),
        .D(\dout[9]_i_1_n_0 ),
        .Q(dout[9]),
        .S(CTRL_0[2]));
  ebaz4205_mixer_2_0_mixer_v1_0_S00_AXI mixer_v1_0_S00_AXI_inst
       (.\GAIN_0_reg[15]_0 ({mixer_v1_0_S00_AXI_inst_n_8,mixer_v1_0_S00_AXI_inst_n_9,mixer_v1_0_S00_AXI_inst_n_10,mixer_v1_0_S00_AXI_inst_n_11,mixer_v1_0_S00_AXI_inst_n_12,mixer_v1_0_S00_AXI_inst_n_13,mixer_v1_0_S00_AXI_inst_n_14,mixer_v1_0_S00_AXI_inst_n_15,B[7:0]}),
        .\GAIN_1_reg[15]_0 ({mixer_v1_0_S00_AXI_inst_n_56,mixer_v1_0_S00_AXI_inst_n_57,mixer_v1_0_S00_AXI_inst_n_58,mixer_v1_0_S00_AXI_inst_n_59,mixer_v1_0_S00_AXI_inst_n_60,mixer_v1_0_S00_AXI_inst_n_61,mixer_v1_0_S00_AXI_inst_n_62,mixer_v1_0_S00_AXI_inst_n_63,\GAIN_1_reg[15] [7:0]}),
        .\GAIN_2_reg[15]_0 ({mixer_v1_0_S00_AXI_inst_n_40,mixer_v1_0_S00_AXI_inst_n_41,mixer_v1_0_S00_AXI_inst_n_42,mixer_v1_0_S00_AXI_inst_n_43,mixer_v1_0_S00_AXI_inst_n_44,mixer_v1_0_S00_AXI_inst_n_45,mixer_v1_0_S00_AXI_inst_n_46,mixer_v1_0_S00_AXI_inst_n_47,\GAIN_2_reg[15] [7:0]}),
        .\GAIN_3_reg[15]_0 ({mixer_v1_0_S00_AXI_inst_n_24,mixer_v1_0_S00_AXI_inst_n_25,mixer_v1_0_S00_AXI_inst_n_26,mixer_v1_0_S00_AXI_inst_n_27,mixer_v1_0_S00_AXI_inst_n_28,mixer_v1_0_S00_AXI_inst_n_29,mixer_v1_0_S00_AXI_inst_n_30,mixer_v1_0_S00_AXI_inst_n_31,A[7:0]}),
        .Q(CTRL_0),
        .axi_awready_reg_0(s00_axi_awready),
        .axi_wready_reg_0(s00_axi_wready),
        .s00_axi_aclk(s00_axi_aclk),
        .s00_axi_aresetn(s00_axi_aresetn),
        .s00_axi_arready(s00_axi_arready),
        .s00_axi_arvalid(s00_axi_arvalid),
        .s00_axi_awaddr(s00_axi_awaddr),
        .s00_axi_awvalid(s00_axi_awvalid),
        .s00_axi_bready(s00_axi_bready),
        .s00_axi_bvalid(s00_axi_bvalid),
        .s00_axi_rready(s00_axi_rready),
        .s00_axi_rvalid(s00_axi_rvalid),
        .s00_axi_wdata(s00_axi_wdata),
        .s00_axi_wstrb(s00_axi_wstrb),
        .s00_axi_wvalid(s00_axi_wvalid));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_1
       (.I0(mixer_v1_0_S00_AXI_inst_n_40),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [15]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_2
       (.I0(mixer_v1_0_S00_AXI_inst_n_41),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [14]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_3
       (.I0(mixer_v1_0_S00_AXI_inst_n_42),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [13]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_4
       (.I0(mixer_v1_0_S00_AXI_inst_n_43),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [12]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_5
       (.I0(mixer_v1_0_S00_AXI_inst_n_44),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [11]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_6
       (.I0(mixer_v1_0_S00_AXI_inst_n_45),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [10]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_7
       (.I0(mixer_v1_0_S00_AXI_inst_n_46),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [9]));
  LUT2 #(
    .INIT(4'h2)) 
    p_0_out_i_8
       (.I0(mixer_v1_0_S00_AXI_inst_n_47),
        .I1(CTRL_0[1]),
        .O(\GAIN_2_reg[15] [8]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_1
       (.I0(mixer_v1_0_S00_AXI_inst_n_24),
        .I1(CTRL_0[1]),
        .O(A[15]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_2
       (.I0(mixer_v1_0_S00_AXI_inst_n_25),
        .I1(CTRL_0[1]),
        .O(A[14]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_3
       (.I0(mixer_v1_0_S00_AXI_inst_n_26),
        .I1(CTRL_0[1]),
        .O(A[13]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_4
       (.I0(mixer_v1_0_S00_AXI_inst_n_27),
        .I1(CTRL_0[1]),
        .O(A[12]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_5
       (.I0(mixer_v1_0_S00_AXI_inst_n_28),
        .I1(CTRL_0[1]),
        .O(A[11]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_6
       (.I0(mixer_v1_0_S00_AXI_inst_n_29),
        .I1(CTRL_0[1]),
        .O(A[10]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_7
       (.I0(mixer_v1_0_S00_AXI_inst_n_30),
        .I1(CTRL_0[1]),
        .O(A[9]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__0_i_8
       (.I0(mixer_v1_0_S00_AXI_inst_n_31),
        .I1(CTRL_0[1]),
        .O(A[8]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_1
       (.I0(mixer_v1_0_S00_AXI_inst_n_8),
        .I1(CTRL_0[1]),
        .O(B[15]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_2
       (.I0(mixer_v1_0_S00_AXI_inst_n_9),
        .I1(CTRL_0[1]),
        .O(B[14]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_3
       (.I0(mixer_v1_0_S00_AXI_inst_n_10),
        .I1(CTRL_0[1]),
        .O(B[13]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_4
       (.I0(mixer_v1_0_S00_AXI_inst_n_11),
        .I1(CTRL_0[1]),
        .O(B[12]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_5
       (.I0(mixer_v1_0_S00_AXI_inst_n_12),
        .I1(CTRL_0[1]),
        .O(B[11]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_6
       (.I0(mixer_v1_0_S00_AXI_inst_n_13),
        .I1(CTRL_0[1]),
        .O(B[10]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_7
       (.I0(mixer_v1_0_S00_AXI_inst_n_14),
        .I1(CTRL_0[1]),
        .O(B[9]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out__1_i_8
       (.I0(mixer_v1_0_S00_AXI_inst_n_15),
        .I1(CTRL_0[1]),
        .O(B[8]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_1
       (.I0(mixer_v1_0_S00_AXI_inst_n_56),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [15]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_2
       (.I0(mixer_v1_0_S00_AXI_inst_n_57),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [14]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_3
       (.I0(mixer_v1_0_S00_AXI_inst_n_58),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [13]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_4
       (.I0(mixer_v1_0_S00_AXI_inst_n_59),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [12]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_5
       (.I0(mixer_v1_0_S00_AXI_inst_n_60),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [11]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_6
       (.I0(mixer_v1_0_S00_AXI_inst_n_61),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [10]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_7
       (.I0(mixer_v1_0_S00_AXI_inst_n_62),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [9]));
  LUT2 #(
    .INIT(4'h2)) 
    p_1_out_i_8
       (.I0(mixer_v1_0_S00_AXI_inst_n_63),
        .I1(CTRL_0[1]),
        .O(\GAIN_1_reg[15] [8]));
endmodule

(* ORIG_REF_NAME = "mixer_v1_0_S00_AXI" *) 
module ebaz4205_mixer_2_0_mixer_v1_0_S00_AXI
   (axi_awready_reg_0,
    axi_wready_reg_0,
    s00_axi_arready,
    s00_axi_bvalid,
    s00_axi_rvalid,
    Q,
    \GAIN_0_reg[15]_0 ,
    \GAIN_3_reg[15]_0 ,
    \GAIN_2_reg[15]_0 ,
    \GAIN_1_reg[15]_0 ,
    s00_axi_aclk,
    s00_axi_arvalid,
    s00_axi_aresetn,
    s00_axi_awvalid,
    s00_axi_wvalid,
    s00_axi_bready,
    s00_axi_rready,
    s00_axi_awaddr,
    s00_axi_wdata,
    s00_axi_wstrb);
  output axi_awready_reg_0;
  output axi_wready_reg_0;
  output s00_axi_arready;
  output s00_axi_bvalid;
  output s00_axi_rvalid;
  output [2:0]Q;
  output [15:0]\GAIN_0_reg[15]_0 ;
  output [15:0]\GAIN_3_reg[15]_0 ;
  output [15:0]\GAIN_2_reg[15]_0 ;
  output [15:0]\GAIN_1_reg[15]_0 ;
  input s00_axi_aclk;
  input s00_axi_arvalid;
  input s00_axi_aresetn;
  input s00_axi_awvalid;
  input s00_axi_wvalid;
  input s00_axi_bready;
  input s00_axi_rready;
  input [3:0]s00_axi_awaddr;
  input [15:0]s00_axi_wdata;
  input [1:0]s00_axi_wstrb;

  wire [15:0]\GAIN_0_reg[15]_0 ;
  wire [15:0]\GAIN_1_reg[15]_0 ;
  wire [15:0]\GAIN_2_reg[15]_0 ;
  wire [15:0]\GAIN_3_reg[15]_0 ;
  wire [2:0]Q;
  wire aw_en_i_1_n_0;
  wire aw_en_reg_n_0;
  wire axi_arready0;
  wire axi_awready0;
  wire axi_awready_i_1_n_0;
  wire axi_awready_reg_0;
  wire axi_bvalid_i_1_n_0;
  wire axi_rvalid_i_1_n_0;
  wire axi_wready0;
  wire axi_wready_reg_0;
  wire [3:0]p_0_in;
  wire [15:7]p_1_in;
  wire s00_axi_aclk;
  wire s00_axi_aresetn;
  wire s00_axi_arready;
  wire s00_axi_arvalid;
  wire [3:0]s00_axi_awaddr;
  wire s00_axi_awvalid;
  wire s00_axi_bready;
  wire s00_axi_bvalid;
  wire s00_axi_rready;
  wire s00_axi_rvalid;
  wire [15:0]s00_axi_wdata;
  wire [1:0]s00_axi_wstrb;
  wire s00_axi_wvalid;
  wire [15:0]slv_reg0;
  wire [15:0]slv_reg1;
  wire \slv_reg1[15]_i_1_n_0 ;
  wire \slv_reg1[7]_i_1_n_0 ;
  wire [15:0]slv_reg2;
  wire \slv_reg2[15]_i_1_n_0 ;
  wire \slv_reg2[7]_i_1_n_0 ;
  wire [15:0]slv_reg3;
  wire \slv_reg3[15]_i_1_n_0 ;
  wire \slv_reg3[7]_i_1_n_0 ;
  wire [2:0]slv_reg8;
  wire \slv_reg8[0]_i_1_n_0 ;
  wire \slv_reg8[1]_i_1_n_0 ;
  wire \slv_reg8[2]_i_1_n_0 ;
  wire \slv_reg8[2]_i_2_n_0 ;
  wire slv_reg_wren__0;

  FDRE \CTRL_0_reg[0] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg8[0]),
        .Q(Q[0]),
        .R(1'b0));
  FDRE \CTRL_0_reg[1] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg8[1]),
        .Q(Q[1]),
        .R(1'b0));
  FDRE \CTRL_0_reg[2] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg8[2]),
        .Q(Q[2]),
        .R(1'b0));
  FDRE \GAIN_0_reg[0] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[0]),
        .Q(\GAIN_0_reg[15]_0 [0]),
        .R(1'b0));
  FDRE \GAIN_0_reg[10] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[10]),
        .Q(\GAIN_0_reg[15]_0 [10]),
        .R(1'b0));
  FDRE \GAIN_0_reg[11] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[11]),
        .Q(\GAIN_0_reg[15]_0 [11]),
        .R(1'b0));
  FDRE \GAIN_0_reg[12] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[12]),
        .Q(\GAIN_0_reg[15]_0 [12]),
        .R(1'b0));
  FDRE \GAIN_0_reg[13] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[13]),
        .Q(\GAIN_0_reg[15]_0 [13]),
        .R(1'b0));
  FDRE \GAIN_0_reg[14] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[14]),
        .Q(\GAIN_0_reg[15]_0 [14]),
        .R(1'b0));
  FDRE \GAIN_0_reg[15] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[15]),
        .Q(\GAIN_0_reg[15]_0 [15]),
        .R(1'b0));
  FDRE \GAIN_0_reg[1] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[1]),
        .Q(\GAIN_0_reg[15]_0 [1]),
        .R(1'b0));
  FDRE \GAIN_0_reg[2] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[2]),
        .Q(\GAIN_0_reg[15]_0 [2]),
        .R(1'b0));
  FDRE \GAIN_0_reg[3] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[3]),
        .Q(\GAIN_0_reg[15]_0 [3]),
        .R(1'b0));
  FDRE \GAIN_0_reg[4] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[4]),
        .Q(\GAIN_0_reg[15]_0 [4]),
        .R(1'b0));
  FDRE \GAIN_0_reg[5] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[5]),
        .Q(\GAIN_0_reg[15]_0 [5]),
        .R(1'b0));
  FDRE \GAIN_0_reg[6] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[6]),
        .Q(\GAIN_0_reg[15]_0 [6]),
        .R(1'b0));
  FDRE \GAIN_0_reg[7] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[7]),
        .Q(\GAIN_0_reg[15]_0 [7]),
        .R(1'b0));
  FDRE \GAIN_0_reg[8] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[8]),
        .Q(\GAIN_0_reg[15]_0 [8]),
        .R(1'b0));
  FDRE \GAIN_0_reg[9] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg0[9]),
        .Q(\GAIN_0_reg[15]_0 [9]),
        .R(1'b0));
  FDRE \GAIN_1_reg[0] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[0]),
        .Q(\GAIN_1_reg[15]_0 [0]),
        .R(1'b0));
  FDRE \GAIN_1_reg[10] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[10]),
        .Q(\GAIN_1_reg[15]_0 [10]),
        .R(1'b0));
  FDRE \GAIN_1_reg[11] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[11]),
        .Q(\GAIN_1_reg[15]_0 [11]),
        .R(1'b0));
  FDRE \GAIN_1_reg[12] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[12]),
        .Q(\GAIN_1_reg[15]_0 [12]),
        .R(1'b0));
  FDRE \GAIN_1_reg[13] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[13]),
        .Q(\GAIN_1_reg[15]_0 [13]),
        .R(1'b0));
  FDRE \GAIN_1_reg[14] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[14]),
        .Q(\GAIN_1_reg[15]_0 [14]),
        .R(1'b0));
  FDRE \GAIN_1_reg[15] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[15]),
        .Q(\GAIN_1_reg[15]_0 [15]),
        .R(1'b0));
  FDRE \GAIN_1_reg[1] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[1]),
        .Q(\GAIN_1_reg[15]_0 [1]),
        .R(1'b0));
  FDRE \GAIN_1_reg[2] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[2]),
        .Q(\GAIN_1_reg[15]_0 [2]),
        .R(1'b0));
  FDRE \GAIN_1_reg[3] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[3]),
        .Q(\GAIN_1_reg[15]_0 [3]),
        .R(1'b0));
  FDRE \GAIN_1_reg[4] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[4]),
        .Q(\GAIN_1_reg[15]_0 [4]),
        .R(1'b0));
  FDRE \GAIN_1_reg[5] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[5]),
        .Q(\GAIN_1_reg[15]_0 [5]),
        .R(1'b0));
  FDRE \GAIN_1_reg[6] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[6]),
        .Q(\GAIN_1_reg[15]_0 [6]),
        .R(1'b0));
  FDRE \GAIN_1_reg[7] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[7]),
        .Q(\GAIN_1_reg[15]_0 [7]),
        .R(1'b0));
  FDRE \GAIN_1_reg[8] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[8]),
        .Q(\GAIN_1_reg[15]_0 [8]),
        .R(1'b0));
  FDRE \GAIN_1_reg[9] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg1[9]),
        .Q(\GAIN_1_reg[15]_0 [9]),
        .R(1'b0));
  FDRE \GAIN_2_reg[0] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[0]),
        .Q(\GAIN_2_reg[15]_0 [0]),
        .R(1'b0));
  FDRE \GAIN_2_reg[10] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[10]),
        .Q(\GAIN_2_reg[15]_0 [10]),
        .R(1'b0));
  FDRE \GAIN_2_reg[11] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[11]),
        .Q(\GAIN_2_reg[15]_0 [11]),
        .R(1'b0));
  FDRE \GAIN_2_reg[12] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[12]),
        .Q(\GAIN_2_reg[15]_0 [12]),
        .R(1'b0));
  FDRE \GAIN_2_reg[13] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[13]),
        .Q(\GAIN_2_reg[15]_0 [13]),
        .R(1'b0));
  FDRE \GAIN_2_reg[14] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[14]),
        .Q(\GAIN_2_reg[15]_0 [14]),
        .R(1'b0));
  FDRE \GAIN_2_reg[15] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[15]),
        .Q(\GAIN_2_reg[15]_0 [15]),
        .R(1'b0));
  FDRE \GAIN_2_reg[1] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[1]),
        .Q(\GAIN_2_reg[15]_0 [1]),
        .R(1'b0));
  FDRE \GAIN_2_reg[2] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[2]),
        .Q(\GAIN_2_reg[15]_0 [2]),
        .R(1'b0));
  FDRE \GAIN_2_reg[3] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[3]),
        .Q(\GAIN_2_reg[15]_0 [3]),
        .R(1'b0));
  FDRE \GAIN_2_reg[4] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[4]),
        .Q(\GAIN_2_reg[15]_0 [4]),
        .R(1'b0));
  FDRE \GAIN_2_reg[5] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[5]),
        .Q(\GAIN_2_reg[15]_0 [5]),
        .R(1'b0));
  FDRE \GAIN_2_reg[6] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[6]),
        .Q(\GAIN_2_reg[15]_0 [6]),
        .R(1'b0));
  FDRE \GAIN_2_reg[7] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[7]),
        .Q(\GAIN_2_reg[15]_0 [7]),
        .R(1'b0));
  FDRE \GAIN_2_reg[8] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[8]),
        .Q(\GAIN_2_reg[15]_0 [8]),
        .R(1'b0));
  FDRE \GAIN_2_reg[9] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg2[9]),
        .Q(\GAIN_2_reg[15]_0 [9]),
        .R(1'b0));
  FDRE \GAIN_3_reg[0] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[0]),
        .Q(\GAIN_3_reg[15]_0 [0]),
        .R(1'b0));
  FDRE \GAIN_3_reg[10] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[10]),
        .Q(\GAIN_3_reg[15]_0 [10]),
        .R(1'b0));
  FDRE \GAIN_3_reg[11] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[11]),
        .Q(\GAIN_3_reg[15]_0 [11]),
        .R(1'b0));
  FDRE \GAIN_3_reg[12] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[12]),
        .Q(\GAIN_3_reg[15]_0 [12]),
        .R(1'b0));
  FDRE \GAIN_3_reg[13] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[13]),
        .Q(\GAIN_3_reg[15]_0 [13]),
        .R(1'b0));
  FDRE \GAIN_3_reg[14] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[14]),
        .Q(\GAIN_3_reg[15]_0 [14]),
        .R(1'b0));
  FDRE \GAIN_3_reg[15] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[15]),
        .Q(\GAIN_3_reg[15]_0 [15]),
        .R(1'b0));
  FDRE \GAIN_3_reg[1] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[1]),
        .Q(\GAIN_3_reg[15]_0 [1]),
        .R(1'b0));
  FDRE \GAIN_3_reg[2] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[2]),
        .Q(\GAIN_3_reg[15]_0 [2]),
        .R(1'b0));
  FDRE \GAIN_3_reg[3] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[3]),
        .Q(\GAIN_3_reg[15]_0 [3]),
        .R(1'b0));
  FDRE \GAIN_3_reg[4] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[4]),
        .Q(\GAIN_3_reg[15]_0 [4]),
        .R(1'b0));
  FDRE \GAIN_3_reg[5] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[5]),
        .Q(\GAIN_3_reg[15]_0 [5]),
        .R(1'b0));
  FDRE \GAIN_3_reg[6] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[6]),
        .Q(\GAIN_3_reg[15]_0 [6]),
        .R(1'b0));
  FDRE \GAIN_3_reg[7] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[7]),
        .Q(\GAIN_3_reg[15]_0 [7]),
        .R(1'b0));
  FDRE \GAIN_3_reg[8] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[8]),
        .Q(\GAIN_3_reg[15]_0 [8]),
        .R(1'b0));
  FDRE \GAIN_3_reg[9] 
       (.C(s00_axi_aclk),
        .CE(s00_axi_aresetn),
        .D(slv_reg3[9]),
        .Q(\GAIN_3_reg[15]_0 [9]),
        .R(1'b0));
  LUT6 #(
    .INIT(64'hF7FFC4CCC4CCC4CC)) 
    aw_en_i_1
       (.I0(s00_axi_awvalid),
        .I1(aw_en_reg_n_0),
        .I2(axi_awready_reg_0),
        .I3(s00_axi_wvalid),
        .I4(s00_axi_bready),
        .I5(s00_axi_bvalid),
        .O(aw_en_i_1_n_0));
  FDSE aw_en_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(aw_en_i_1_n_0),
        .Q(aw_en_reg_n_0),
        .S(axi_awready_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT2 #(
    .INIT(4'h2)) 
    axi_arready_i_1
       (.I0(s00_axi_arvalid),
        .I1(s00_axi_arready),
        .O(axi_arready0));
  FDRE axi_arready_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(axi_arready0),
        .Q(s00_axi_arready),
        .R(axi_awready_i_1_n_0));
  FDRE \axi_awaddr_reg[2] 
       (.C(s00_axi_aclk),
        .CE(axi_awready0),
        .D(s00_axi_awaddr[0]),
        .Q(p_0_in[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \axi_awaddr_reg[3] 
       (.C(s00_axi_aclk),
        .CE(axi_awready0),
        .D(s00_axi_awaddr[1]),
        .Q(p_0_in[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \axi_awaddr_reg[4] 
       (.C(s00_axi_aclk),
        .CE(axi_awready0),
        .D(s00_axi_awaddr[2]),
        .Q(p_0_in[2]),
        .R(axi_awready_i_1_n_0));
  FDRE \axi_awaddr_reg[5] 
       (.C(s00_axi_aclk),
        .CE(axi_awready0),
        .D(s00_axi_awaddr[3]),
        .Q(p_0_in[3]),
        .R(axi_awready_i_1_n_0));
  LUT1 #(
    .INIT(2'h1)) 
    axi_awready_i_1
       (.I0(s00_axi_aresetn),
        .O(axi_awready_i_1_n_0));
  LUT4 #(
    .INIT(16'h2000)) 
    axi_awready_i_2
       (.I0(s00_axi_wvalid),
        .I1(axi_awready_reg_0),
        .I2(aw_en_reg_n_0),
        .I3(s00_axi_awvalid),
        .O(axi_awready0));
  FDRE axi_awready_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(axi_awready0),
        .Q(axi_awready_reg_0),
        .R(axi_awready_i_1_n_0));
  LUT6 #(
    .INIT(64'h0000FFFF80008000)) 
    axi_bvalid_i_1
       (.I0(s00_axi_awvalid),
        .I1(s00_axi_wvalid),
        .I2(axi_awready_reg_0),
        .I3(axi_wready_reg_0),
        .I4(s00_axi_bready),
        .I5(s00_axi_bvalid),
        .O(axi_bvalid_i_1_n_0));
  FDRE axi_bvalid_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(axi_bvalid_i_1_n_0),
        .Q(s00_axi_bvalid),
        .R(axi_awready_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair0" *) 
  LUT4 #(
    .INIT(16'h08F8)) 
    axi_rvalid_i_1
       (.I0(s00_axi_arready),
        .I1(s00_axi_arvalid),
        .I2(s00_axi_rvalid),
        .I3(s00_axi_rready),
        .O(axi_rvalid_i_1_n_0));
  FDRE axi_rvalid_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(axi_rvalid_i_1_n_0),
        .Q(s00_axi_rvalid),
        .R(axi_awready_i_1_n_0));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'h0800)) 
    axi_wready_i_1
       (.I0(s00_axi_awvalid),
        .I1(s00_axi_wvalid),
        .I2(axi_wready_reg_0),
        .I3(aw_en_reg_n_0),
        .O(axi_wready0));
  FDRE axi_wready_reg
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(axi_wready0),
        .Q(axi_wready_reg_0),
        .R(axi_awready_i_1_n_0));
  LUT6 #(
    .INIT(64'h0000000200000000)) 
    \slv_reg0[15]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(p_0_in[0]),
        .I2(p_0_in[3]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(s00_axi_wstrb[1]),
        .O(p_1_in[15]));
  (* SOFT_HLUTNM = "soft_lutpair1" *) 
  LUT4 #(
    .INIT(16'h8000)) 
    \slv_reg0[15]_i_2 
       (.I0(axi_wready_reg_0),
        .I1(axi_awready_reg_0),
        .I2(s00_axi_awvalid),
        .I3(s00_axi_wvalid),
        .O(slv_reg_wren__0));
  LUT6 #(
    .INIT(64'h0000000200000000)) 
    \slv_reg0[7]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(p_0_in[0]),
        .I2(p_0_in[3]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(s00_axi_wstrb[0]),
        .O(p_1_in[7]));
  FDRE \slv_reg0_reg[0] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[0]),
        .Q(slv_reg0[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[10] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[10]),
        .Q(slv_reg0[10]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[11] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[11]),
        .Q(slv_reg0[11]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[12] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[12]),
        .Q(slv_reg0[12]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[13] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[13]),
        .Q(slv_reg0[13]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[14] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[14]),
        .Q(slv_reg0[14]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[15] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[15]),
        .Q(slv_reg0[15]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[1] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[1]),
        .Q(slv_reg0[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[2] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[2]),
        .Q(slv_reg0[2]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[3] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[3]),
        .Q(slv_reg0[3]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[4] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[4]),
        .Q(slv_reg0[4]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[5] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[5]),
        .Q(slv_reg0[5]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[6] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[6]),
        .Q(slv_reg0[6]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[7] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[7]),
        .D(s00_axi_wdata[7]),
        .Q(slv_reg0[7]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[8] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[8]),
        .Q(slv_reg0[8]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg0_reg[9] 
       (.C(s00_axi_aclk),
        .CE(p_1_in[15]),
        .D(s00_axi_wdata[9]),
        .Q(slv_reg0[9]),
        .R(axi_awready_i_1_n_0));
  LUT6 #(
    .INIT(64'h0000000800000000)) 
    \slv_reg1[15]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[1]),
        .I2(p_0_in[3]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(p_0_in[0]),
        .O(\slv_reg1[15]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000800000000)) 
    \slv_reg1[7]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[0]),
        .I2(p_0_in[3]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(p_0_in[0]),
        .O(\slv_reg1[7]_i_1_n_0 ));
  FDRE \slv_reg1_reg[0] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[0]),
        .Q(slv_reg1[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[10] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[10]),
        .Q(slv_reg1[10]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[11] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[11]),
        .Q(slv_reg1[11]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[12] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[12]),
        .Q(slv_reg1[12]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[13] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[13]),
        .Q(slv_reg1[13]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[14] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[14]),
        .Q(slv_reg1[14]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[15] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[15]),
        .Q(slv_reg1[15]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[1] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[1]),
        .Q(slv_reg1[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[2] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[2]),
        .Q(slv_reg1[2]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[3] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[3]),
        .Q(slv_reg1[3]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[4] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[4]),
        .Q(slv_reg1[4]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[5] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[5]),
        .Q(slv_reg1[5]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[6] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[6]),
        .Q(slv_reg1[6]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[7] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[7]_i_1_n_0 ),
        .D(s00_axi_wdata[7]),
        .Q(slv_reg1[7]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[8] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[8]),
        .Q(slv_reg1[8]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg1_reg[9] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg1[15]_i_1_n_0 ),
        .D(s00_axi_wdata[9]),
        .Q(slv_reg1[9]),
        .R(axi_awready_i_1_n_0));
  LUT6 #(
    .INIT(64'h0000000800000000)) 
    \slv_reg2[15]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[1]),
        .I2(p_0_in[3]),
        .I3(p_0_in[0]),
        .I4(p_0_in[2]),
        .I5(p_0_in[1]),
        .O(\slv_reg2[15]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000800000000)) 
    \slv_reg2[7]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[0]),
        .I2(p_0_in[3]),
        .I3(p_0_in[0]),
        .I4(p_0_in[2]),
        .I5(p_0_in[1]),
        .O(\slv_reg2[7]_i_1_n_0 ));
  FDRE \slv_reg2_reg[0] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[0]),
        .Q(slv_reg2[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[10] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[10]),
        .Q(slv_reg2[10]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[11] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[11]),
        .Q(slv_reg2[11]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[12] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[12]),
        .Q(slv_reg2[12]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[13] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[13]),
        .Q(slv_reg2[13]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[14] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[14]),
        .Q(slv_reg2[14]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[15] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[15]),
        .Q(slv_reg2[15]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[1] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[1]),
        .Q(slv_reg2[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[2] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[2]),
        .Q(slv_reg2[2]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[3] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[3]),
        .Q(slv_reg2[3]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[4] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[4]),
        .Q(slv_reg2[4]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[5] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[5]),
        .Q(slv_reg2[5]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[6] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[6]),
        .Q(slv_reg2[6]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[7] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[7]_i_1_n_0 ),
        .D(s00_axi_wdata[7]),
        .Q(slv_reg2[7]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[8] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[8]),
        .Q(slv_reg2[8]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg2_reg[9] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg2[15]_i_1_n_0 ),
        .D(s00_axi_wdata[9]),
        .Q(slv_reg2[9]),
        .R(axi_awready_i_1_n_0));
  LUT6 #(
    .INIT(64'h0000000000008000)) 
    \slv_reg3[15]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[1]),
        .I2(p_0_in[0]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(p_0_in[3]),
        .O(\slv_reg3[15]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000000008000)) 
    \slv_reg3[7]_i_1 
       (.I0(slv_reg_wren__0),
        .I1(s00_axi_wstrb[0]),
        .I2(p_0_in[0]),
        .I3(p_0_in[1]),
        .I4(p_0_in[2]),
        .I5(p_0_in[3]),
        .O(\slv_reg3[7]_i_1_n_0 ));
  FDRE \slv_reg3_reg[0] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[0]),
        .Q(slv_reg3[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[10] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[10]),
        .Q(slv_reg3[10]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[11] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[11]),
        .Q(slv_reg3[11]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[12] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[12]),
        .Q(slv_reg3[12]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[13] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[13]),
        .Q(slv_reg3[13]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[14] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[14]),
        .Q(slv_reg3[14]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[15] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[15]),
        .Q(slv_reg3[15]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[1] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[1]),
        .Q(slv_reg3[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[2] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[2]),
        .Q(slv_reg3[2]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[3] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[3]),
        .Q(slv_reg3[3]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[4] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[4]),
        .Q(slv_reg3[4]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[5] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[5]),
        .Q(slv_reg3[5]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[6] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[6]),
        .Q(slv_reg3[6]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[7] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[7]_i_1_n_0 ),
        .D(s00_axi_wdata[7]),
        .Q(slv_reg3[7]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[8] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[8]),
        .Q(slv_reg3[8]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg3_reg[9] 
       (.C(s00_axi_aclk),
        .CE(\slv_reg3[15]_i_1_n_0 ),
        .D(s00_axi_wdata[9]),
        .Q(slv_reg3[9]),
        .R(axi_awready_i_1_n_0));
  LUT3 #(
    .INIT(8'hB8)) 
    \slv_reg8[0]_i_1 
       (.I0(s00_axi_wdata[0]),
        .I1(\slv_reg8[2]_i_2_n_0 ),
        .I2(slv_reg8[0]),
        .O(\slv_reg8[0]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \slv_reg8[1]_i_1 
       (.I0(s00_axi_wdata[1]),
        .I1(\slv_reg8[2]_i_2_n_0 ),
        .I2(slv_reg8[1]),
        .O(\slv_reg8[1]_i_1_n_0 ));
  (* SOFT_HLUTNM = "soft_lutpair2" *) 
  LUT3 #(
    .INIT(8'hB8)) 
    \slv_reg8[2]_i_1 
       (.I0(s00_axi_wdata[2]),
        .I1(\slv_reg8[2]_i_2_n_0 ),
        .I2(slv_reg8[2]),
        .O(\slv_reg8[2]_i_1_n_0 ));
  LUT6 #(
    .INIT(64'h0000000800000000)) 
    \slv_reg8[2]_i_2 
       (.I0(slv_reg_wren__0),
        .I1(p_0_in[3]),
        .I2(p_0_in[1]),
        .I3(p_0_in[0]),
        .I4(p_0_in[2]),
        .I5(s00_axi_wstrb[0]),
        .O(\slv_reg8[2]_i_2_n_0 ));
  FDRE \slv_reg8_reg[0] 
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(\slv_reg8[0]_i_1_n_0 ),
        .Q(slv_reg8[0]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg8_reg[1] 
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(\slv_reg8[1]_i_1_n_0 ),
        .Q(slv_reg8[1]),
        .R(axi_awready_i_1_n_0));
  FDRE \slv_reg8_reg[2] 
       (.C(s00_axi_aclk),
        .CE(1'b1),
        .D(\slv_reg8[2]_i_1_n_0 ),
        .Q(slv_reg8[2]),
        .R(axi_awready_i_1_n_0));
endmodule
`ifndef GLBL
`define GLBL
`timescale  1 ps / 1 ps

module glbl ();

    parameter ROC_WIDTH = 100000;
    parameter TOC_WIDTH = 0;
    parameter GRES_WIDTH = 10000;
    parameter GRES_START = 10000;

//--------   STARTUP Globals --------------
    wire GSR;
    wire GTS;
    wire GWE;
    wire PRLD;
    wire GRESTORE;
    tri1 p_up_tmp;
    tri (weak1, strong0) PLL_LOCKG = p_up_tmp;

    wire PROGB_GLBL;
    wire CCLKO_GLBL;
    wire FCSBO_GLBL;
    wire [3:0] DO_GLBL;
    wire [3:0] DI_GLBL;
   
    reg GSR_int;
    reg GTS_int;
    reg PRLD_int;
    reg GRESTORE_int;

//--------   JTAG Globals --------------
    wire JTAG_TDO_GLBL;
    wire JTAG_TCK_GLBL;
    wire JTAG_TDI_GLBL;
    wire JTAG_TMS_GLBL;
    wire JTAG_TRST_GLBL;

    reg JTAG_CAPTURE_GLBL;
    reg JTAG_RESET_GLBL;
    reg JTAG_SHIFT_GLBL;
    reg JTAG_UPDATE_GLBL;
    reg JTAG_RUNTEST_GLBL;

    reg JTAG_SEL1_GLBL = 0;
    reg JTAG_SEL2_GLBL = 0 ;
    reg JTAG_SEL3_GLBL = 0;
    reg JTAG_SEL4_GLBL = 0;

    reg JTAG_USER_TDO1_GLBL = 1'bz;
    reg JTAG_USER_TDO2_GLBL = 1'bz;
    reg JTAG_USER_TDO3_GLBL = 1'bz;
    reg JTAG_USER_TDO4_GLBL = 1'bz;

    assign (strong1, weak0) GSR = GSR_int;
    assign (strong1, weak0) GTS = GTS_int;
    assign (weak1, weak0) PRLD = PRLD_int;
    assign (strong1, weak0) GRESTORE = GRESTORE_int;

    initial begin
	GSR_int = 1'b1;
	PRLD_int = 1'b1;
	#(ROC_WIDTH)
	GSR_int = 1'b0;
	PRLD_int = 1'b0;
    end

    initial begin
	GTS_int = 1'b1;
	#(TOC_WIDTH)
	GTS_int = 1'b0;
    end

    initial begin 
	GRESTORE_int = 1'b0;
	#(GRES_START);
	GRESTORE_int = 1'b1;
	#(GRES_WIDTH);
	GRESTORE_int = 1'b0;
    end

endmodule
`endif
