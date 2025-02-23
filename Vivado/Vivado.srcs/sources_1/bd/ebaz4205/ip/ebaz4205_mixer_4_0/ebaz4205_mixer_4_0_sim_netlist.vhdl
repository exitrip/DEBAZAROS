-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
-- Date        : Sat Feb 22 19:57:36 2025
-- Host        : antmicro-debug running 64-bit Ubuntu 24.04.2 LTS
-- Command     : write_vhdl -force -mode funcsim
--               /home/aescape/Documents/github/DEBAZAROS/Vivado/Vivado.gen/sources_1/bd/ebaz4205/ip/ebaz4205_mixer_4_0/ebaz4205_mixer_4_0_sim_netlist.vhdl
-- Design      : ebaz4205_mixer_4_0
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7z010clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ebaz4205_mixer_4_0_mixer_v1_0_S00_AXI is
  port (
    axi_awready_reg_0 : out STD_LOGIC;
    axi_wready_reg_0 : out STD_LOGIC;
    s00_axi_arready : out STD_LOGIC;
    s00_axi_bvalid : out STD_LOGIC;
    s00_axi_rvalid : out STD_LOGIC;
    Q : out STD_LOGIC_VECTOR ( 2 downto 0 );
    \GAIN_0_reg[15]_0\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \GAIN_3_reg[15]_0\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \GAIN_2_reg[15]_0\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \GAIN_1_reg[15]_0\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    s00_axi_aclk : in STD_LOGIC;
    s00_axi_arvalid : in STD_LOGIC;
    s00_axi_aresetn : in STD_LOGIC;
    s00_axi_awvalid : in STD_LOGIC;
    s00_axi_wvalid : in STD_LOGIC;
    s00_axi_bready : in STD_LOGIC;
    s00_axi_rready : in STD_LOGIC;
    s00_axi_awaddr : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s00_axi_wdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
    s00_axi_wstrb : in STD_LOGIC_VECTOR ( 1 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of ebaz4205_mixer_4_0_mixer_v1_0_S00_AXI : entity is "mixer_v1_0_S00_AXI";
end ebaz4205_mixer_4_0_mixer_v1_0_S00_AXI;

architecture STRUCTURE of ebaz4205_mixer_4_0_mixer_v1_0_S00_AXI is
  signal aw_en_i_1_n_0 : STD_LOGIC;
  signal aw_en_reg_n_0 : STD_LOGIC;
  signal axi_arready0 : STD_LOGIC;
  signal axi_awready0 : STD_LOGIC;
  signal axi_awready_i_1_n_0 : STD_LOGIC;
  signal \^axi_awready_reg_0\ : STD_LOGIC;
  signal axi_bvalid_i_1_n_0 : STD_LOGIC;
  signal axi_rvalid_i_1_n_0 : STD_LOGIC;
  signal axi_wready0 : STD_LOGIC;
  signal \^axi_wready_reg_0\ : STD_LOGIC;
  signal p_0_in : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal p_1_in : STD_LOGIC_VECTOR ( 15 downto 7 );
  signal \^s00_axi_arready\ : STD_LOGIC;
  signal \^s00_axi_bvalid\ : STD_LOGIC;
  signal \^s00_axi_rvalid\ : STD_LOGIC;
  signal slv_reg0 : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal slv_reg1 : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \slv_reg1[15]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg1[7]_i_1_n_0\ : STD_LOGIC;
  signal slv_reg2 : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \slv_reg2[15]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg2[7]_i_1_n_0\ : STD_LOGIC;
  signal slv_reg3 : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal \slv_reg3[15]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg3[7]_i_1_n_0\ : STD_LOGIC;
  signal slv_reg8 : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \slv_reg8[0]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg8[1]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg8[2]_i_1_n_0\ : STD_LOGIC;
  signal \slv_reg8[2]_i_2_n_0\ : STD_LOGIC;
  signal \slv_reg_wren__0\ : STD_LOGIC;
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of axi_arready_i_1 : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of axi_rvalid_i_1 : label is "soft_lutpair0";
  attribute SOFT_HLUTNM of axi_wready_i_1 : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \slv_reg0[15]_i_2\ : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \slv_reg8[1]_i_1\ : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of \slv_reg8[2]_i_1\ : label is "soft_lutpair2";
begin
  axi_awready_reg_0 <= \^axi_awready_reg_0\;
  axi_wready_reg_0 <= \^axi_wready_reg_0\;
  s00_axi_arready <= \^s00_axi_arready\;
  s00_axi_bvalid <= \^s00_axi_bvalid\;
  s00_axi_rvalid <= \^s00_axi_rvalid\;
\CTRL_0_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg8(0),
      Q => Q(0),
      R => '0'
    );
\CTRL_0_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg8(1),
      Q => Q(1),
      R => '0'
    );
\CTRL_0_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg8(2),
      Q => Q(2),
      R => '0'
    );
\GAIN_0_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(0),
      Q => \GAIN_0_reg[15]_0\(0),
      R => '0'
    );
\GAIN_0_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(10),
      Q => \GAIN_0_reg[15]_0\(10),
      R => '0'
    );
\GAIN_0_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(11),
      Q => \GAIN_0_reg[15]_0\(11),
      R => '0'
    );
\GAIN_0_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(12),
      Q => \GAIN_0_reg[15]_0\(12),
      R => '0'
    );
\GAIN_0_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(13),
      Q => \GAIN_0_reg[15]_0\(13),
      R => '0'
    );
\GAIN_0_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(14),
      Q => \GAIN_0_reg[15]_0\(14),
      R => '0'
    );
\GAIN_0_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(15),
      Q => \GAIN_0_reg[15]_0\(15),
      R => '0'
    );
\GAIN_0_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(1),
      Q => \GAIN_0_reg[15]_0\(1),
      R => '0'
    );
\GAIN_0_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(2),
      Q => \GAIN_0_reg[15]_0\(2),
      R => '0'
    );
\GAIN_0_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(3),
      Q => \GAIN_0_reg[15]_0\(3),
      R => '0'
    );
\GAIN_0_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(4),
      Q => \GAIN_0_reg[15]_0\(4),
      R => '0'
    );
\GAIN_0_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(5),
      Q => \GAIN_0_reg[15]_0\(5),
      R => '0'
    );
\GAIN_0_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(6),
      Q => \GAIN_0_reg[15]_0\(6),
      R => '0'
    );
\GAIN_0_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(7),
      Q => \GAIN_0_reg[15]_0\(7),
      R => '0'
    );
\GAIN_0_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(8),
      Q => \GAIN_0_reg[15]_0\(8),
      R => '0'
    );
\GAIN_0_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg0(9),
      Q => \GAIN_0_reg[15]_0\(9),
      R => '0'
    );
\GAIN_1_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(0),
      Q => \GAIN_1_reg[15]_0\(0),
      R => '0'
    );
\GAIN_1_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(10),
      Q => \GAIN_1_reg[15]_0\(10),
      R => '0'
    );
\GAIN_1_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(11),
      Q => \GAIN_1_reg[15]_0\(11),
      R => '0'
    );
\GAIN_1_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(12),
      Q => \GAIN_1_reg[15]_0\(12),
      R => '0'
    );
\GAIN_1_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(13),
      Q => \GAIN_1_reg[15]_0\(13),
      R => '0'
    );
\GAIN_1_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(14),
      Q => \GAIN_1_reg[15]_0\(14),
      R => '0'
    );
\GAIN_1_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(15),
      Q => \GAIN_1_reg[15]_0\(15),
      R => '0'
    );
\GAIN_1_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(1),
      Q => \GAIN_1_reg[15]_0\(1),
      R => '0'
    );
\GAIN_1_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(2),
      Q => \GAIN_1_reg[15]_0\(2),
      R => '0'
    );
\GAIN_1_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(3),
      Q => \GAIN_1_reg[15]_0\(3),
      R => '0'
    );
\GAIN_1_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(4),
      Q => \GAIN_1_reg[15]_0\(4),
      R => '0'
    );
\GAIN_1_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(5),
      Q => \GAIN_1_reg[15]_0\(5),
      R => '0'
    );
\GAIN_1_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(6),
      Q => \GAIN_1_reg[15]_0\(6),
      R => '0'
    );
\GAIN_1_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(7),
      Q => \GAIN_1_reg[15]_0\(7),
      R => '0'
    );
\GAIN_1_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(8),
      Q => \GAIN_1_reg[15]_0\(8),
      R => '0'
    );
\GAIN_1_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg1(9),
      Q => \GAIN_1_reg[15]_0\(9),
      R => '0'
    );
\GAIN_2_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(0),
      Q => \GAIN_2_reg[15]_0\(0),
      R => '0'
    );
\GAIN_2_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(10),
      Q => \GAIN_2_reg[15]_0\(10),
      R => '0'
    );
\GAIN_2_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(11),
      Q => \GAIN_2_reg[15]_0\(11),
      R => '0'
    );
\GAIN_2_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(12),
      Q => \GAIN_2_reg[15]_0\(12),
      R => '0'
    );
\GAIN_2_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(13),
      Q => \GAIN_2_reg[15]_0\(13),
      R => '0'
    );
\GAIN_2_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(14),
      Q => \GAIN_2_reg[15]_0\(14),
      R => '0'
    );
\GAIN_2_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(15),
      Q => \GAIN_2_reg[15]_0\(15),
      R => '0'
    );
\GAIN_2_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(1),
      Q => \GAIN_2_reg[15]_0\(1),
      R => '0'
    );
\GAIN_2_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(2),
      Q => \GAIN_2_reg[15]_0\(2),
      R => '0'
    );
\GAIN_2_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(3),
      Q => \GAIN_2_reg[15]_0\(3),
      R => '0'
    );
\GAIN_2_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(4),
      Q => \GAIN_2_reg[15]_0\(4),
      R => '0'
    );
\GAIN_2_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(5),
      Q => \GAIN_2_reg[15]_0\(5),
      R => '0'
    );
\GAIN_2_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(6),
      Q => \GAIN_2_reg[15]_0\(6),
      R => '0'
    );
\GAIN_2_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(7),
      Q => \GAIN_2_reg[15]_0\(7),
      R => '0'
    );
\GAIN_2_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(8),
      Q => \GAIN_2_reg[15]_0\(8),
      R => '0'
    );
\GAIN_2_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg2(9),
      Q => \GAIN_2_reg[15]_0\(9),
      R => '0'
    );
\GAIN_3_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(0),
      Q => \GAIN_3_reg[15]_0\(0),
      R => '0'
    );
\GAIN_3_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(10),
      Q => \GAIN_3_reg[15]_0\(10),
      R => '0'
    );
\GAIN_3_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(11),
      Q => \GAIN_3_reg[15]_0\(11),
      R => '0'
    );
\GAIN_3_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(12),
      Q => \GAIN_3_reg[15]_0\(12),
      R => '0'
    );
\GAIN_3_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(13),
      Q => \GAIN_3_reg[15]_0\(13),
      R => '0'
    );
\GAIN_3_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(14),
      Q => \GAIN_3_reg[15]_0\(14),
      R => '0'
    );
\GAIN_3_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(15),
      Q => \GAIN_3_reg[15]_0\(15),
      R => '0'
    );
\GAIN_3_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(1),
      Q => \GAIN_3_reg[15]_0\(1),
      R => '0'
    );
\GAIN_3_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(2),
      Q => \GAIN_3_reg[15]_0\(2),
      R => '0'
    );
\GAIN_3_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(3),
      Q => \GAIN_3_reg[15]_0\(3),
      R => '0'
    );
\GAIN_3_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(4),
      Q => \GAIN_3_reg[15]_0\(4),
      R => '0'
    );
\GAIN_3_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(5),
      Q => \GAIN_3_reg[15]_0\(5),
      R => '0'
    );
\GAIN_3_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(6),
      Q => \GAIN_3_reg[15]_0\(6),
      R => '0'
    );
\GAIN_3_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(7),
      Q => \GAIN_3_reg[15]_0\(7),
      R => '0'
    );
\GAIN_3_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(8),
      Q => \GAIN_3_reg[15]_0\(8),
      R => '0'
    );
\GAIN_3_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => s00_axi_aresetn,
      D => slv_reg3(9),
      Q => \GAIN_3_reg[15]_0\(9),
      R => '0'
    );
aw_en_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"F7FFC4CCC4CCC4CC"
    )
        port map (
      I0 => s00_axi_awvalid,
      I1 => aw_en_reg_n_0,
      I2 => \^axi_awready_reg_0\,
      I3 => s00_axi_wvalid,
      I4 => s00_axi_bready,
      I5 => \^s00_axi_bvalid\,
      O => aw_en_i_1_n_0
    );
aw_en_reg: unisim.vcomponents.FDSE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => aw_en_i_1_n_0,
      Q => aw_en_reg_n_0,
      S => axi_awready_i_1_n_0
    );
axi_arready_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => s00_axi_arvalid,
      I1 => \^s00_axi_arready\,
      O => axi_arready0
    );
axi_arready_reg: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => axi_arready0,
      Q => \^s00_axi_arready\,
      R => axi_awready_i_1_n_0
    );
\axi_awaddr_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => axi_awready0,
      D => s00_axi_awaddr(0),
      Q => p_0_in(0),
      R => axi_awready_i_1_n_0
    );
\axi_awaddr_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => axi_awready0,
      D => s00_axi_awaddr(1),
      Q => p_0_in(1),
      R => axi_awready_i_1_n_0
    );
\axi_awaddr_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => axi_awready0,
      D => s00_axi_awaddr(2),
      Q => p_0_in(2),
      R => axi_awready_i_1_n_0
    );
\axi_awaddr_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => axi_awready0,
      D => s00_axi_awaddr(3),
      Q => p_0_in(3),
      R => axi_awready_i_1_n_0
    );
axi_awready_i_1: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => s00_axi_aresetn,
      O => axi_awready_i_1_n_0
    );
axi_awready_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"2000"
    )
        port map (
      I0 => s00_axi_wvalid,
      I1 => \^axi_awready_reg_0\,
      I2 => aw_en_reg_n_0,
      I3 => s00_axi_awvalid,
      O => axi_awready0
    );
axi_awready_reg: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => axi_awready0,
      Q => \^axi_awready_reg_0\,
      R => axi_awready_i_1_n_0
    );
axi_bvalid_i_1: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000FFFF80008000"
    )
        port map (
      I0 => s00_axi_awvalid,
      I1 => s00_axi_wvalid,
      I2 => \^axi_awready_reg_0\,
      I3 => \^axi_wready_reg_0\,
      I4 => s00_axi_bready,
      I5 => \^s00_axi_bvalid\,
      O => axi_bvalid_i_1_n_0
    );
axi_bvalid_reg: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => axi_bvalid_i_1_n_0,
      Q => \^s00_axi_bvalid\,
      R => axi_awready_i_1_n_0
    );
axi_rvalid_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"08F8"
    )
        port map (
      I0 => \^s00_axi_arready\,
      I1 => s00_axi_arvalid,
      I2 => \^s00_axi_rvalid\,
      I3 => s00_axi_rready,
      O => axi_rvalid_i_1_n_0
    );
axi_rvalid_reg: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => axi_rvalid_i_1_n_0,
      Q => \^s00_axi_rvalid\,
      R => axi_awready_i_1_n_0
    );
axi_wready_i_1: unisim.vcomponents.LUT4
    generic map(
      INIT => X"0800"
    )
        port map (
      I0 => s00_axi_awvalid,
      I1 => s00_axi_wvalid,
      I2 => \^axi_wready_reg_0\,
      I3 => aw_en_reg_n_0,
      O => axi_wready0
    );
axi_wready_reg: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => axi_wready0,
      Q => \^axi_wready_reg_0\,
      R => axi_awready_i_1_n_0
    );
\slv_reg0[15]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000200000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => p_0_in(0),
      I2 => p_0_in(3),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => s00_axi_wstrb(1),
      O => p_1_in(15)
    );
\slv_reg0[15]_i_2\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"8000"
    )
        port map (
      I0 => \^axi_wready_reg_0\,
      I1 => \^axi_awready_reg_0\,
      I2 => s00_axi_awvalid,
      I3 => s00_axi_wvalid,
      O => \slv_reg_wren__0\
    );
\slv_reg0[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000200000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => p_0_in(0),
      I2 => p_0_in(3),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => s00_axi_wstrb(0),
      O => p_1_in(7)
    );
\slv_reg0_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(0),
      Q => slv_reg0(0),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(10),
      Q => slv_reg0(10),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(11),
      Q => slv_reg0(11),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(12),
      Q => slv_reg0(12),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(13),
      Q => slv_reg0(13),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(14),
      Q => slv_reg0(14),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(15),
      Q => slv_reg0(15),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(1),
      Q => slv_reg0(1),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(2),
      Q => slv_reg0(2),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(3),
      Q => slv_reg0(3),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(4),
      Q => slv_reg0(4),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(5),
      Q => slv_reg0(5),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(6),
      Q => slv_reg0(6),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(7),
      D => s00_axi_wdata(7),
      Q => slv_reg0(7),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(8),
      Q => slv_reg0(8),
      R => axi_awready_i_1_n_0
    );
\slv_reg0_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => p_1_in(15),
      D => s00_axi_wdata(9),
      Q => slv_reg0(9),
      R => axi_awready_i_1_n_0
    );
\slv_reg1[15]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000800000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(1),
      I2 => p_0_in(3),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => p_0_in(0),
      O => \slv_reg1[15]_i_1_n_0\
    );
\slv_reg1[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000800000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(0),
      I2 => p_0_in(3),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => p_0_in(0),
      O => \slv_reg1[7]_i_1_n_0\
    );
\slv_reg1_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(0),
      Q => slv_reg1(0),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(10),
      Q => slv_reg1(10),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(11),
      Q => slv_reg1(11),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(12),
      Q => slv_reg1(12),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(13),
      Q => slv_reg1(13),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(14),
      Q => slv_reg1(14),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(15),
      Q => slv_reg1(15),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(1),
      Q => slv_reg1(1),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(2),
      Q => slv_reg1(2),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(3),
      Q => slv_reg1(3),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(4),
      Q => slv_reg1(4),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(5),
      Q => slv_reg1(5),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(6),
      Q => slv_reg1(6),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[7]_i_1_n_0\,
      D => s00_axi_wdata(7),
      Q => slv_reg1(7),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(8),
      Q => slv_reg1(8),
      R => axi_awready_i_1_n_0
    );
\slv_reg1_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg1[15]_i_1_n_0\,
      D => s00_axi_wdata(9),
      Q => slv_reg1(9),
      R => axi_awready_i_1_n_0
    );
\slv_reg2[15]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000800000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(1),
      I2 => p_0_in(3),
      I3 => p_0_in(0),
      I4 => p_0_in(2),
      I5 => p_0_in(1),
      O => \slv_reg2[15]_i_1_n_0\
    );
\slv_reg2[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000800000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(0),
      I2 => p_0_in(3),
      I3 => p_0_in(0),
      I4 => p_0_in(2),
      I5 => p_0_in(1),
      O => \slv_reg2[7]_i_1_n_0\
    );
\slv_reg2_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(0),
      Q => slv_reg2(0),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(10),
      Q => slv_reg2(10),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(11),
      Q => slv_reg2(11),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(12),
      Q => slv_reg2(12),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(13),
      Q => slv_reg2(13),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(14),
      Q => slv_reg2(14),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(15),
      Q => slv_reg2(15),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(1),
      Q => slv_reg2(1),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(2),
      Q => slv_reg2(2),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(3),
      Q => slv_reg2(3),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(4),
      Q => slv_reg2(4),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(5),
      Q => slv_reg2(5),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(6),
      Q => slv_reg2(6),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[7]_i_1_n_0\,
      D => s00_axi_wdata(7),
      Q => slv_reg2(7),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(8),
      Q => slv_reg2(8),
      R => axi_awready_i_1_n_0
    );
\slv_reg2_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg2[15]_i_1_n_0\,
      D => s00_axi_wdata(9),
      Q => slv_reg2(9),
      R => axi_awready_i_1_n_0
    );
\slv_reg3[15]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000008000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(1),
      I2 => p_0_in(0),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => p_0_in(3),
      O => \slv_reg3[15]_i_1_n_0\
    );
\slv_reg3[7]_i_1\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000000008000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => s00_axi_wstrb(0),
      I2 => p_0_in(0),
      I3 => p_0_in(1),
      I4 => p_0_in(2),
      I5 => p_0_in(3),
      O => \slv_reg3[7]_i_1_n_0\
    );
\slv_reg3_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(0),
      Q => slv_reg3(0),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[10]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(10),
      Q => slv_reg3(10),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[11]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(11),
      Q => slv_reg3(11),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[12]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(12),
      Q => slv_reg3(12),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[13]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(13),
      Q => slv_reg3(13),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[14]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(14),
      Q => slv_reg3(14),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[15]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(15),
      Q => slv_reg3(15),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(1),
      Q => slv_reg3(1),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(2),
      Q => slv_reg3(2),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[3]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(3),
      Q => slv_reg3(3),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[4]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(4),
      Q => slv_reg3(4),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[5]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(5),
      Q => slv_reg3(5),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[6]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(6),
      Q => slv_reg3(6),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[7]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[7]_i_1_n_0\,
      D => s00_axi_wdata(7),
      Q => slv_reg3(7),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[8]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(8),
      Q => slv_reg3(8),
      R => axi_awready_i_1_n_0
    );
\slv_reg3_reg[9]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => \slv_reg3[15]_i_1_n_0\,
      D => s00_axi_wdata(9),
      Q => slv_reg3(9),
      R => axi_awready_i_1_n_0
    );
\slv_reg8[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => s00_axi_wdata(0),
      I1 => \slv_reg8[2]_i_2_n_0\,
      I2 => slv_reg8(0),
      O => \slv_reg8[0]_i_1_n_0\
    );
\slv_reg8[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => s00_axi_wdata(1),
      I1 => \slv_reg8[2]_i_2_n_0\,
      I2 => slv_reg8(1),
      O => \slv_reg8[1]_i_1_n_0\
    );
\slv_reg8[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => s00_axi_wdata(2),
      I1 => \slv_reg8[2]_i_2_n_0\,
      I2 => slv_reg8(2),
      O => \slv_reg8[2]_i_1_n_0\
    );
\slv_reg8[2]_i_2\: unisim.vcomponents.LUT6
    generic map(
      INIT => X"0000000800000000"
    )
        port map (
      I0 => \slv_reg_wren__0\,
      I1 => p_0_in(3),
      I2 => p_0_in(1),
      I3 => p_0_in(0),
      I4 => p_0_in(2),
      I5 => s00_axi_wstrb(0),
      O => \slv_reg8[2]_i_2_n_0\
    );
\slv_reg8_reg[0]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => \slv_reg8[0]_i_1_n_0\,
      Q => slv_reg8(0),
      R => axi_awready_i_1_n_0
    );
\slv_reg8_reg[1]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => \slv_reg8[1]_i_1_n_0\,
      Q => slv_reg8(1),
      R => axi_awready_i_1_n_0
    );
\slv_reg8_reg[2]\: unisim.vcomponents.FDRE
     port map (
      C => s00_axi_aclk,
      CE => '1',
      D => \slv_reg8[2]_i_1_n_0\,
      Q => slv_reg8(2),
      R => axi_awready_i_1_n_0
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ebaz4205_mixer_4_0_mixer_v1_0 is
  port (
    s00_axi_awready : out STD_LOGIC;
    s00_axi_wready : out STD_LOGIC;
    s00_axi_arready : out STD_LOGIC;
    s00_axi_bvalid : out STD_LOGIC;
    s00_axi_rvalid : out STD_LOGIC;
    B : out STD_LOGIC_VECTOR ( 15 downto 0 );
    A : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \GAIN_2_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    \GAIN_1_reg[15]\ : out STD_LOGIC_VECTOR ( 15 downto 0 );
    dout : out STD_LOGIC_VECTOR ( 15 downto 0 );
    s00_axi_aclk : in STD_LOGIC;
    s00_axi_arvalid : in STD_LOGIC;
    s00_axi_aresetn : in STD_LOGIC;
    s00_axi_awvalid : in STD_LOGIC;
    s00_axi_wvalid : in STD_LOGIC;
    s00_axi_bready : in STD_LOGIC;
    s00_axi_rready : in STD_LOGIC;
    s00_axi_awaddr : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s00_axi_wdata : in STD_LOGIC_VECTOR ( 15 downto 0 );
    pix_clk : in STD_LOGIC;
    s00_axi_wstrb : in STD_LOGIC_VECTOR ( 1 downto 0 );
    din0 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    P : in STD_LOGIC_VECTOR ( 15 downto 0 )
  );
  attribute ORIG_REF_NAME : string;
  attribute ORIG_REF_NAME of ebaz4205_mixer_4_0_mixer_v1_0 : entity is "mixer_v1_0";
end ebaz4205_mixer_4_0_mixer_v1_0;

architecture STRUCTURE of ebaz4205_mixer_4_0_mixer_v1_0 is
  signal CTRL_0 : STD_LOGIC_VECTOR ( 2 downto 0 );
  signal \dout[0]_i_1_n_0\ : STD_LOGIC;
  signal \dout[10]_i_1_n_0\ : STD_LOGIC;
  signal \dout[11]_i_1_n_0\ : STD_LOGIC;
  signal \dout[12]_i_1_n_0\ : STD_LOGIC;
  signal \dout[13]_i_1_n_0\ : STD_LOGIC;
  signal \dout[14]_i_1_n_0\ : STD_LOGIC;
  signal \dout[15]_i_1_n_0\ : STD_LOGIC;
  signal \dout[1]_i_1_n_0\ : STD_LOGIC;
  signal \dout[2]_i_1_n_0\ : STD_LOGIC;
  signal \dout[3]_i_1_n_0\ : STD_LOGIC;
  signal \dout[4]_i_1_n_0\ : STD_LOGIC;
  signal \dout[5]_i_1_n_0\ : STD_LOGIC;
  signal \dout[6]_i_1_n_0\ : STD_LOGIC;
  signal \dout[7]_i_1_n_0\ : STD_LOGIC;
  signal \dout[8]_i_1_n_0\ : STD_LOGIC;
  signal \dout[9]_i_1_n_0\ : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_10 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_11 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_12 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_13 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_14 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_15 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_24 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_25 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_26 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_27 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_28 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_29 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_30 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_31 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_40 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_41 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_42 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_43 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_44 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_45 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_46 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_47 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_56 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_57 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_58 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_59 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_60 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_61 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_62 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_63 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_8 : STD_LOGIC;
  signal mixer_v1_0_S00_AXI_inst_n_9 : STD_LOGIC;
begin
\dout[0]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(0),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(0),
      O => \dout[0]_i_1_n_0\
    );
\dout[10]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(10),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(10),
      O => \dout[10]_i_1_n_0\
    );
\dout[11]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(11),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(11),
      O => \dout[11]_i_1_n_0\
    );
\dout[12]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(12),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(12),
      O => \dout[12]_i_1_n_0\
    );
\dout[13]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(13),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(13),
      O => \dout[13]_i_1_n_0\
    );
\dout[14]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(14),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(14),
      O => \dout[14]_i_1_n_0\
    );
\dout[15]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(15),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(15),
      O => \dout[15]_i_1_n_0\
    );
\dout[1]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(1),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(1),
      O => \dout[1]_i_1_n_0\
    );
\dout[2]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(2),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(2),
      O => \dout[2]_i_1_n_0\
    );
\dout[3]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(3),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(3),
      O => \dout[3]_i_1_n_0\
    );
\dout[4]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(4),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(4),
      O => \dout[4]_i_1_n_0\
    );
\dout[5]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(5),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(5),
      O => \dout[5]_i_1_n_0\
    );
\dout[6]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(6),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(6),
      O => \dout[6]_i_1_n_0\
    );
\dout[7]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(7),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(7),
      O => \dout[7]_i_1_n_0\
    );
\dout[8]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(8),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(8),
      O => \dout[8]_i_1_n_0\
    );
\dout[9]_i_1\: unisim.vcomponents.LUT4
    generic map(
      INIT => X"BC80"
    )
        port map (
      I0 => din0(9),
      I1 => CTRL_0(0),
      I2 => CTRL_0(1),
      I3 => P(9),
      O => \dout[9]_i_1_n_0\
    );
\dout_reg[0]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[0]_i_1_n_0\,
      Q => dout(0),
      S => CTRL_0(2)
    );
\dout_reg[10]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[10]_i_1_n_0\,
      Q => dout(10),
      S => CTRL_0(2)
    );
\dout_reg[11]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[11]_i_1_n_0\,
      Q => dout(11),
      S => CTRL_0(2)
    );
\dout_reg[12]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[12]_i_1_n_0\,
      Q => dout(12),
      S => CTRL_0(2)
    );
\dout_reg[13]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[13]_i_1_n_0\,
      Q => dout(13),
      S => CTRL_0(2)
    );
\dout_reg[14]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[14]_i_1_n_0\,
      Q => dout(14),
      S => CTRL_0(2)
    );
\dout_reg[15]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[15]_i_1_n_0\,
      Q => dout(15),
      S => CTRL_0(2)
    );
\dout_reg[1]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[1]_i_1_n_0\,
      Q => dout(1),
      S => CTRL_0(2)
    );
\dout_reg[2]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[2]_i_1_n_0\,
      Q => dout(2),
      S => CTRL_0(2)
    );
\dout_reg[3]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[3]_i_1_n_0\,
      Q => dout(3),
      S => CTRL_0(2)
    );
\dout_reg[4]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[4]_i_1_n_0\,
      Q => dout(4),
      S => CTRL_0(2)
    );
\dout_reg[5]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[5]_i_1_n_0\,
      Q => dout(5),
      S => CTRL_0(2)
    );
\dout_reg[6]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[6]_i_1_n_0\,
      Q => dout(6),
      S => CTRL_0(2)
    );
\dout_reg[7]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[7]_i_1_n_0\,
      Q => dout(7),
      S => CTRL_0(2)
    );
\dout_reg[8]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[8]_i_1_n_0\,
      Q => dout(8),
      S => CTRL_0(2)
    );
\dout_reg[9]\: unisim.vcomponents.FDSE
     port map (
      C => pix_clk,
      CE => '1',
      D => \dout[9]_i_1_n_0\,
      Q => dout(9),
      S => CTRL_0(2)
    );
mixer_v1_0_S00_AXI_inst: entity work.ebaz4205_mixer_4_0_mixer_v1_0_S00_AXI
     port map (
      \GAIN_0_reg[15]_0\(15) => mixer_v1_0_S00_AXI_inst_n_8,
      \GAIN_0_reg[15]_0\(14) => mixer_v1_0_S00_AXI_inst_n_9,
      \GAIN_0_reg[15]_0\(13) => mixer_v1_0_S00_AXI_inst_n_10,
      \GAIN_0_reg[15]_0\(12) => mixer_v1_0_S00_AXI_inst_n_11,
      \GAIN_0_reg[15]_0\(11) => mixer_v1_0_S00_AXI_inst_n_12,
      \GAIN_0_reg[15]_0\(10) => mixer_v1_0_S00_AXI_inst_n_13,
      \GAIN_0_reg[15]_0\(9) => mixer_v1_0_S00_AXI_inst_n_14,
      \GAIN_0_reg[15]_0\(8) => mixer_v1_0_S00_AXI_inst_n_15,
      \GAIN_0_reg[15]_0\(7 downto 0) => B(7 downto 0),
      \GAIN_1_reg[15]_0\(15) => mixer_v1_0_S00_AXI_inst_n_56,
      \GAIN_1_reg[15]_0\(14) => mixer_v1_0_S00_AXI_inst_n_57,
      \GAIN_1_reg[15]_0\(13) => mixer_v1_0_S00_AXI_inst_n_58,
      \GAIN_1_reg[15]_0\(12) => mixer_v1_0_S00_AXI_inst_n_59,
      \GAIN_1_reg[15]_0\(11) => mixer_v1_0_S00_AXI_inst_n_60,
      \GAIN_1_reg[15]_0\(10) => mixer_v1_0_S00_AXI_inst_n_61,
      \GAIN_1_reg[15]_0\(9) => mixer_v1_0_S00_AXI_inst_n_62,
      \GAIN_1_reg[15]_0\(8) => mixer_v1_0_S00_AXI_inst_n_63,
      \GAIN_1_reg[15]_0\(7 downto 0) => \GAIN_1_reg[15]\(7 downto 0),
      \GAIN_2_reg[15]_0\(15) => mixer_v1_0_S00_AXI_inst_n_40,
      \GAIN_2_reg[15]_0\(14) => mixer_v1_0_S00_AXI_inst_n_41,
      \GAIN_2_reg[15]_0\(13) => mixer_v1_0_S00_AXI_inst_n_42,
      \GAIN_2_reg[15]_0\(12) => mixer_v1_0_S00_AXI_inst_n_43,
      \GAIN_2_reg[15]_0\(11) => mixer_v1_0_S00_AXI_inst_n_44,
      \GAIN_2_reg[15]_0\(10) => mixer_v1_0_S00_AXI_inst_n_45,
      \GAIN_2_reg[15]_0\(9) => mixer_v1_0_S00_AXI_inst_n_46,
      \GAIN_2_reg[15]_0\(8) => mixer_v1_0_S00_AXI_inst_n_47,
      \GAIN_2_reg[15]_0\(7 downto 0) => \GAIN_2_reg[15]\(7 downto 0),
      \GAIN_3_reg[15]_0\(15) => mixer_v1_0_S00_AXI_inst_n_24,
      \GAIN_3_reg[15]_0\(14) => mixer_v1_0_S00_AXI_inst_n_25,
      \GAIN_3_reg[15]_0\(13) => mixer_v1_0_S00_AXI_inst_n_26,
      \GAIN_3_reg[15]_0\(12) => mixer_v1_0_S00_AXI_inst_n_27,
      \GAIN_3_reg[15]_0\(11) => mixer_v1_0_S00_AXI_inst_n_28,
      \GAIN_3_reg[15]_0\(10) => mixer_v1_0_S00_AXI_inst_n_29,
      \GAIN_3_reg[15]_0\(9) => mixer_v1_0_S00_AXI_inst_n_30,
      \GAIN_3_reg[15]_0\(8) => mixer_v1_0_S00_AXI_inst_n_31,
      \GAIN_3_reg[15]_0\(7 downto 0) => A(7 downto 0),
      Q(2 downto 0) => CTRL_0(2 downto 0),
      axi_awready_reg_0 => s00_axi_awready,
      axi_wready_reg_0 => s00_axi_wready,
      s00_axi_aclk => s00_axi_aclk,
      s00_axi_aresetn => s00_axi_aresetn,
      s00_axi_arready => s00_axi_arready,
      s00_axi_arvalid => s00_axi_arvalid,
      s00_axi_awaddr(3 downto 0) => s00_axi_awaddr(3 downto 0),
      s00_axi_awvalid => s00_axi_awvalid,
      s00_axi_bready => s00_axi_bready,
      s00_axi_bvalid => s00_axi_bvalid,
      s00_axi_rready => s00_axi_rready,
      s00_axi_rvalid => s00_axi_rvalid,
      s00_axi_wdata(15 downto 0) => s00_axi_wdata(15 downto 0),
      s00_axi_wstrb(1 downto 0) => s00_axi_wstrb(1 downto 0),
      s00_axi_wvalid => s00_axi_wvalid
    );
p_0_out_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_40,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(15)
    );
p_0_out_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_41,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(14)
    );
p_0_out_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_42,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(13)
    );
p_0_out_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_43,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(12)
    );
p_0_out_i_5: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_44,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(11)
    );
p_0_out_i_6: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_45,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(10)
    );
p_0_out_i_7: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_46,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(9)
    );
p_0_out_i_8: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_47,
      I1 => CTRL_0(1),
      O => \GAIN_2_reg[15]\(8)
    );
\p_1_out__0_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_24,
      I1 => CTRL_0(1),
      O => A(15)
    );
\p_1_out__0_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_25,
      I1 => CTRL_0(1),
      O => A(14)
    );
\p_1_out__0_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_26,
      I1 => CTRL_0(1),
      O => A(13)
    );
\p_1_out__0_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_27,
      I1 => CTRL_0(1),
      O => A(12)
    );
\p_1_out__0_i_5\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_28,
      I1 => CTRL_0(1),
      O => A(11)
    );
\p_1_out__0_i_6\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_29,
      I1 => CTRL_0(1),
      O => A(10)
    );
\p_1_out__0_i_7\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_30,
      I1 => CTRL_0(1),
      O => A(9)
    );
\p_1_out__0_i_8\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_31,
      I1 => CTRL_0(1),
      O => A(8)
    );
\p_1_out__1_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_8,
      I1 => CTRL_0(1),
      O => B(15)
    );
\p_1_out__1_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_9,
      I1 => CTRL_0(1),
      O => B(14)
    );
\p_1_out__1_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_10,
      I1 => CTRL_0(1),
      O => B(13)
    );
\p_1_out__1_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_11,
      I1 => CTRL_0(1),
      O => B(12)
    );
\p_1_out__1_i_5\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_12,
      I1 => CTRL_0(1),
      O => B(11)
    );
\p_1_out__1_i_6\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_13,
      I1 => CTRL_0(1),
      O => B(10)
    );
\p_1_out__1_i_7\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_14,
      I1 => CTRL_0(1),
      O => B(9)
    );
\p_1_out__1_i_8\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_15,
      I1 => CTRL_0(1),
      O => B(8)
    );
p_1_out_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_56,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(15)
    );
p_1_out_i_2: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_57,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(14)
    );
p_1_out_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_58,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(13)
    );
p_1_out_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_59,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(12)
    );
p_1_out_i_5: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_60,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(11)
    );
p_1_out_i_6: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_61,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(10)
    );
p_1_out_i_7: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_62,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(9)
    );
p_1_out_i_8: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => mixer_v1_0_S00_AXI_inst_n_63,
      I1 => CTRL_0(1),
      O => \GAIN_1_reg[15]\(8)
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ebaz4205_mixer_4_0 is
  port (
    pix_clk : in STD_LOGIC;
    dout : out STD_LOGIC_VECTOR ( 15 downto 0 );
    din0 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    din1 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    din2 : in STD_LOGIC_VECTOR ( 15 downto 0 );
    s00_axi_aclk : in STD_LOGIC;
    s00_axi_aresetn : in STD_LOGIC;
    s00_axi_awaddr : in STD_LOGIC_VECTOR ( 5 downto 0 );
    s00_axi_awprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s00_axi_awvalid : in STD_LOGIC;
    s00_axi_awready : out STD_LOGIC;
    s00_axi_wdata : in STD_LOGIC_VECTOR ( 31 downto 0 );
    s00_axi_wstrb : in STD_LOGIC_VECTOR ( 3 downto 0 );
    s00_axi_wvalid : in STD_LOGIC;
    s00_axi_wready : out STD_LOGIC;
    s00_axi_bresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s00_axi_bvalid : out STD_LOGIC;
    s00_axi_bready : in STD_LOGIC;
    s00_axi_araddr : in STD_LOGIC_VECTOR ( 5 downto 0 );
    s00_axi_arprot : in STD_LOGIC_VECTOR ( 2 downto 0 );
    s00_axi_arvalid : in STD_LOGIC;
    s00_axi_arready : out STD_LOGIC;
    s00_axi_rdata : out STD_LOGIC_VECTOR ( 31 downto 0 );
    s00_axi_rresp : out STD_LOGIC_VECTOR ( 1 downto 0 );
    s00_axi_rvalid : out STD_LOGIC;
    s00_axi_rready : in STD_LOGIC
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of ebaz4205_mixer_4_0 : entity is true;
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of ebaz4205_mixer_4_0 : entity is "ebaz4205_mixer_4_0,mixer_v1_0,{}";
  attribute DowngradeIPIdentifiedWarnings : string;
  attribute DowngradeIPIdentifiedWarnings of ebaz4205_mixer_4_0 : entity is "yes";
  attribute X_CORE_INFO : string;
  attribute X_CORE_INFO of ebaz4205_mixer_4_0 : entity is "mixer_v1_0,Vivado 2022.2";
end ebaz4205_mixer_4_0;

architecture STRUCTURE of ebaz4205_mixer_4_0 is
  signal \<const0>\ : STD_LOGIC;
  signal B : STD_LOGIC_VECTOR ( 15 downto 8 );
  signal inst_n_13 : STD_LOGIC;
  signal inst_n_14 : STD_LOGIC;
  signal inst_n_15 : STD_LOGIC;
  signal inst_n_16 : STD_LOGIC;
  signal inst_n_17 : STD_LOGIC;
  signal inst_n_18 : STD_LOGIC;
  signal inst_n_19 : STD_LOGIC;
  signal inst_n_20 : STD_LOGIC;
  signal inst_n_21 : STD_LOGIC;
  signal inst_n_22 : STD_LOGIC;
  signal inst_n_23 : STD_LOGIC;
  signal inst_n_24 : STD_LOGIC;
  signal inst_n_25 : STD_LOGIC;
  signal inst_n_26 : STD_LOGIC;
  signal inst_n_27 : STD_LOGIC;
  signal inst_n_28 : STD_LOGIC;
  signal inst_n_29 : STD_LOGIC;
  signal inst_n_30 : STD_LOGIC;
  signal inst_n_31 : STD_LOGIC;
  signal inst_n_32 : STD_LOGIC;
  signal inst_n_33 : STD_LOGIC;
  signal inst_n_34 : STD_LOGIC;
  signal inst_n_35 : STD_LOGIC;
  signal inst_n_36 : STD_LOGIC;
  signal inst_n_37 : STD_LOGIC;
  signal inst_n_38 : STD_LOGIC;
  signal inst_n_39 : STD_LOGIC;
  signal inst_n_40 : STD_LOGIC;
  signal inst_n_41 : STD_LOGIC;
  signal inst_n_42 : STD_LOGIC;
  signal inst_n_43 : STD_LOGIC;
  signal inst_n_44 : STD_LOGIC;
  signal inst_n_45 : STD_LOGIC;
  signal inst_n_46 : STD_LOGIC;
  signal inst_n_47 : STD_LOGIC;
  signal inst_n_48 : STD_LOGIC;
  signal inst_n_49 : STD_LOGIC;
  signal inst_n_50 : STD_LOGIC;
  signal inst_n_51 : STD_LOGIC;
  signal inst_n_52 : STD_LOGIC;
  signal inst_n_53 : STD_LOGIC;
  signal inst_n_54 : STD_LOGIC;
  signal inst_n_55 : STD_LOGIC;
  signal inst_n_56 : STD_LOGIC;
  signal inst_n_57 : STD_LOGIC;
  signal inst_n_58 : STD_LOGIC;
  signal inst_n_59 : STD_LOGIC;
  signal inst_n_60 : STD_LOGIC;
  signal inst_n_61 : STD_LOGIC;
  signal inst_n_62 : STD_LOGIC;
  signal inst_n_63 : STD_LOGIC;
  signal inst_n_64 : STD_LOGIC;
  signal inst_n_65 : STD_LOGIC;
  signal inst_n_66 : STD_LOGIC;
  signal inst_n_67 : STD_LOGIC;
  signal inst_n_68 : STD_LOGIC;
  signal \p_0_out__0\ : STD_LOGIC_VECTOR ( 15 downto 0 );
  signal p_0_out_n_74 : STD_LOGIC;
  signal p_0_out_n_75 : STD_LOGIC;
  signal p_0_out_n_76 : STD_LOGIC;
  signal p_0_out_n_77 : STD_LOGIC;
  signal p_0_out_n_78 : STD_LOGIC;
  signal p_0_out_n_79 : STD_LOGIC;
  signal p_0_out_n_80 : STD_LOGIC;
  signal p_0_out_n_81 : STD_LOGIC;
  signal p_0_out_n_82 : STD_LOGIC;
  signal p_0_out_n_83 : STD_LOGIC;
  signal p_0_out_n_84 : STD_LOGIC;
  signal p_0_out_n_85 : STD_LOGIC;
  signal p_0_out_n_86 : STD_LOGIC;
  signal p_0_out_n_87 : STD_LOGIC;
  signal p_0_out_n_88 : STD_LOGIC;
  signal p_0_out_n_89 : STD_LOGIC;
  signal \p_1_out__0_n_100\ : STD_LOGIC;
  signal \p_1_out__0_n_101\ : STD_LOGIC;
  signal \p_1_out__0_n_102\ : STD_LOGIC;
  signal \p_1_out__0_n_103\ : STD_LOGIC;
  signal \p_1_out__0_n_104\ : STD_LOGIC;
  signal \p_1_out__0_n_105\ : STD_LOGIC;
  signal \p_1_out__0_n_106\ : STD_LOGIC;
  signal \p_1_out__0_n_107\ : STD_LOGIC;
  signal \p_1_out__0_n_108\ : STD_LOGIC;
  signal \p_1_out__0_n_109\ : STD_LOGIC;
  signal \p_1_out__0_n_110\ : STD_LOGIC;
  signal \p_1_out__0_n_111\ : STD_LOGIC;
  signal \p_1_out__0_n_112\ : STD_LOGIC;
  signal \p_1_out__0_n_113\ : STD_LOGIC;
  signal \p_1_out__0_n_114\ : STD_LOGIC;
  signal \p_1_out__0_n_115\ : STD_LOGIC;
  signal \p_1_out__0_n_116\ : STD_LOGIC;
  signal \p_1_out__0_n_117\ : STD_LOGIC;
  signal \p_1_out__0_n_118\ : STD_LOGIC;
  signal \p_1_out__0_n_119\ : STD_LOGIC;
  signal \p_1_out__0_n_120\ : STD_LOGIC;
  signal \p_1_out__0_n_121\ : STD_LOGIC;
  signal \p_1_out__0_n_122\ : STD_LOGIC;
  signal \p_1_out__0_n_123\ : STD_LOGIC;
  signal \p_1_out__0_n_124\ : STD_LOGIC;
  signal \p_1_out__0_n_125\ : STD_LOGIC;
  signal \p_1_out__0_n_126\ : STD_LOGIC;
  signal \p_1_out__0_n_127\ : STD_LOGIC;
  signal \p_1_out__0_n_128\ : STD_LOGIC;
  signal \p_1_out__0_n_129\ : STD_LOGIC;
  signal \p_1_out__0_n_130\ : STD_LOGIC;
  signal \p_1_out__0_n_131\ : STD_LOGIC;
  signal \p_1_out__0_n_132\ : STD_LOGIC;
  signal \p_1_out__0_n_133\ : STD_LOGIC;
  signal \p_1_out__0_n_134\ : STD_LOGIC;
  signal \p_1_out__0_n_135\ : STD_LOGIC;
  signal \p_1_out__0_n_136\ : STD_LOGIC;
  signal \p_1_out__0_n_137\ : STD_LOGIC;
  signal \p_1_out__0_n_138\ : STD_LOGIC;
  signal \p_1_out__0_n_139\ : STD_LOGIC;
  signal \p_1_out__0_n_140\ : STD_LOGIC;
  signal \p_1_out__0_n_141\ : STD_LOGIC;
  signal \p_1_out__0_n_142\ : STD_LOGIC;
  signal \p_1_out__0_n_143\ : STD_LOGIC;
  signal \p_1_out__0_n_144\ : STD_LOGIC;
  signal \p_1_out__0_n_145\ : STD_LOGIC;
  signal \p_1_out__0_n_146\ : STD_LOGIC;
  signal \p_1_out__0_n_147\ : STD_LOGIC;
  signal \p_1_out__0_n_148\ : STD_LOGIC;
  signal \p_1_out__0_n_149\ : STD_LOGIC;
  signal \p_1_out__0_n_150\ : STD_LOGIC;
  signal \p_1_out__0_n_151\ : STD_LOGIC;
  signal \p_1_out__0_n_152\ : STD_LOGIC;
  signal \p_1_out__0_n_153\ : STD_LOGIC;
  signal \p_1_out__0_n_90\ : STD_LOGIC;
  signal \p_1_out__0_n_91\ : STD_LOGIC;
  signal \p_1_out__0_n_92\ : STD_LOGIC;
  signal \p_1_out__0_n_93\ : STD_LOGIC;
  signal \p_1_out__0_n_94\ : STD_LOGIC;
  signal \p_1_out__0_n_95\ : STD_LOGIC;
  signal \p_1_out__0_n_96\ : STD_LOGIC;
  signal \p_1_out__0_n_97\ : STD_LOGIC;
  signal \p_1_out__0_n_98\ : STD_LOGIC;
  signal \p_1_out__0_n_99\ : STD_LOGIC;
  signal \p_1_out__1_n_100\ : STD_LOGIC;
  signal \p_1_out__1_n_101\ : STD_LOGIC;
  signal \p_1_out__1_n_102\ : STD_LOGIC;
  signal \p_1_out__1_n_103\ : STD_LOGIC;
  signal \p_1_out__1_n_104\ : STD_LOGIC;
  signal \p_1_out__1_n_105\ : STD_LOGIC;
  signal \p_1_out__1_n_90\ : STD_LOGIC;
  signal \p_1_out__1_n_91\ : STD_LOGIC;
  signal \p_1_out__1_n_92\ : STD_LOGIC;
  signal \p_1_out__1_n_93\ : STD_LOGIC;
  signal \p_1_out__1_n_94\ : STD_LOGIC;
  signal \p_1_out__1_n_95\ : STD_LOGIC;
  signal \p_1_out__1_n_96\ : STD_LOGIC;
  signal \p_1_out__1_n_97\ : STD_LOGIC;
  signal \p_1_out__1_n_98\ : STD_LOGIC;
  signal \p_1_out__1_n_99\ : STD_LOGIC;
  signal p_1_out_n_100 : STD_LOGIC;
  signal p_1_out_n_101 : STD_LOGIC;
  signal p_1_out_n_102 : STD_LOGIC;
  signal p_1_out_n_103 : STD_LOGIC;
  signal p_1_out_n_104 : STD_LOGIC;
  signal p_1_out_n_105 : STD_LOGIC;
  signal p_1_out_n_106 : STD_LOGIC;
  signal p_1_out_n_107 : STD_LOGIC;
  signal p_1_out_n_108 : STD_LOGIC;
  signal p_1_out_n_109 : STD_LOGIC;
  signal p_1_out_n_110 : STD_LOGIC;
  signal p_1_out_n_111 : STD_LOGIC;
  signal p_1_out_n_112 : STD_LOGIC;
  signal p_1_out_n_113 : STD_LOGIC;
  signal p_1_out_n_114 : STD_LOGIC;
  signal p_1_out_n_115 : STD_LOGIC;
  signal p_1_out_n_116 : STD_LOGIC;
  signal p_1_out_n_117 : STD_LOGIC;
  signal p_1_out_n_118 : STD_LOGIC;
  signal p_1_out_n_119 : STD_LOGIC;
  signal p_1_out_n_120 : STD_LOGIC;
  signal p_1_out_n_121 : STD_LOGIC;
  signal p_1_out_n_122 : STD_LOGIC;
  signal p_1_out_n_123 : STD_LOGIC;
  signal p_1_out_n_124 : STD_LOGIC;
  signal p_1_out_n_125 : STD_LOGIC;
  signal p_1_out_n_126 : STD_LOGIC;
  signal p_1_out_n_127 : STD_LOGIC;
  signal p_1_out_n_128 : STD_LOGIC;
  signal p_1_out_n_129 : STD_LOGIC;
  signal p_1_out_n_130 : STD_LOGIC;
  signal p_1_out_n_131 : STD_LOGIC;
  signal p_1_out_n_132 : STD_LOGIC;
  signal p_1_out_n_133 : STD_LOGIC;
  signal p_1_out_n_134 : STD_LOGIC;
  signal p_1_out_n_135 : STD_LOGIC;
  signal p_1_out_n_136 : STD_LOGIC;
  signal p_1_out_n_137 : STD_LOGIC;
  signal p_1_out_n_138 : STD_LOGIC;
  signal p_1_out_n_139 : STD_LOGIC;
  signal p_1_out_n_140 : STD_LOGIC;
  signal p_1_out_n_141 : STD_LOGIC;
  signal p_1_out_n_142 : STD_LOGIC;
  signal p_1_out_n_143 : STD_LOGIC;
  signal p_1_out_n_144 : STD_LOGIC;
  signal p_1_out_n_145 : STD_LOGIC;
  signal p_1_out_n_146 : STD_LOGIC;
  signal p_1_out_n_147 : STD_LOGIC;
  signal p_1_out_n_148 : STD_LOGIC;
  signal p_1_out_n_149 : STD_LOGIC;
  signal p_1_out_n_150 : STD_LOGIC;
  signal p_1_out_n_151 : STD_LOGIC;
  signal p_1_out_n_152 : STD_LOGIC;
  signal p_1_out_n_153 : STD_LOGIC;
  signal p_1_out_n_90 : STD_LOGIC;
  signal p_1_out_n_91 : STD_LOGIC;
  signal p_1_out_n_92 : STD_LOGIC;
  signal p_1_out_n_93 : STD_LOGIC;
  signal p_1_out_n_94 : STD_LOGIC;
  signal p_1_out_n_95 : STD_LOGIC;
  signal p_1_out_n_96 : STD_LOGIC;
  signal p_1_out_n_97 : STD_LOGIC;
  signal p_1_out_n_98 : STD_LOGIC;
  signal p_1_out_n_99 : STD_LOGIC;
  signal NLW_p_0_out_CARRYCASCOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_MULTSIGNOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_OVERFLOW_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_PATTERNBDETECT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_PATTERNDETECT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_UNDERFLOW_UNCONNECTED : STD_LOGIC;
  signal NLW_p_0_out_ACOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 29 downto 0 );
  signal NLW_p_0_out_BCOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 17 downto 0 );
  signal NLW_p_0_out_CARRYOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_p_0_out_P_UNCONNECTED : STD_LOGIC_VECTOR ( 47 downto 32 );
  signal NLW_p_0_out_PCOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 47 downto 0 );
  signal NLW_p_1_out_CARRYCASCOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_MULTSIGNOUT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_OVERFLOW_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_PATTERNBDETECT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_PATTERNDETECT_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_UNDERFLOW_UNCONNECTED : STD_LOGIC;
  signal NLW_p_1_out_ACOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 29 downto 0 );
  signal NLW_p_1_out_BCOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 17 downto 0 );
  signal NLW_p_1_out_CARRYOUT_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal NLW_p_1_out_P_UNCONNECTED : STD_LOGIC_VECTOR ( 47 downto 16 );
  signal \NLW_p_1_out__0_CARRYCASCOUT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_MULTSIGNOUT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_OVERFLOW_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_PATTERNBDETECT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_PATTERNDETECT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_UNDERFLOW_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__0_ACOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 29 downto 0 );
  signal \NLW_p_1_out__0_BCOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 17 downto 0 );
  signal \NLW_p_1_out__0_CARRYOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_p_1_out__0_P_UNCONNECTED\ : STD_LOGIC_VECTOR ( 47 downto 16 );
  signal \NLW_p_1_out__1_CARRYCASCOUT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_MULTSIGNOUT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_OVERFLOW_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_PATTERNBDETECT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_PATTERNDETECT_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_UNDERFLOW_UNCONNECTED\ : STD_LOGIC;
  signal \NLW_p_1_out__1_ACOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 29 downto 0 );
  signal \NLW_p_1_out__1_BCOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 17 downto 0 );
  signal \NLW_p_1_out__1_CARRYOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_p_1_out__1_P_UNCONNECTED\ : STD_LOGIC_VECTOR ( 47 downto 16 );
  signal \NLW_p_1_out__1_PCOUT_UNCONNECTED\ : STD_LOGIC_VECTOR ( 47 downto 0 );
  attribute METHODOLOGY_DRC_VIOS : string;
  attribute METHODOLOGY_DRC_VIOS of p_0_out : label is "{SYNTH-13 {cell *THIS*}}";
  attribute METHODOLOGY_DRC_VIOS of p_1_out : label is "{SYNTH-13 {cell *THIS*}}";
  attribute METHODOLOGY_DRC_VIOS of \p_1_out__0\ : label is "{SYNTH-13 {cell *THIS*}}";
  attribute METHODOLOGY_DRC_VIOS of \p_1_out__1\ : label is "{SYNTH-13 {cell *THIS*}}";
  attribute X_INTERFACE_INFO : string;
  attribute X_INTERFACE_INFO of pix_clk : signal is "xilinx.com:signal:clock:1.0 pix_clk CLK";
  attribute X_INTERFACE_PARAMETER : string;
  attribute X_INTERFACE_PARAMETER of pix_clk : signal is "XIL_INTERFACENAME pix_clk, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN ebaz4205_axi_dynclk_0_0_PXL_CLK_O, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s00_axi_aclk : signal is "xilinx.com:signal:clock:1.0 S00_AXI_CLK CLK";
  attribute X_INTERFACE_PARAMETER of s00_axi_aclk : signal is "XIL_INTERFACENAME S00_AXI_CLK, ASSOCIATED_BUSIF S00_AXI, ASSOCIATED_RESET s00_axi_aresetn, FREQ_HZ 100000000, FREQ_TOLERANCE_HZ 0, PHASE 0.0, CLK_DOMAIN ebaz4205_processing_system7_0_0_FCLK_CLK0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s00_axi_aresetn : signal is "xilinx.com:signal:reset:1.0 S00_AXI_RST RST";
  attribute X_INTERFACE_PARAMETER of s00_axi_aresetn : signal is "XIL_INTERFACENAME S00_AXI_RST, POLARITY ACTIVE_LOW, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s00_axi_arready : signal is "xilinx.com:interface:aximm:1.0 S00_AXI ARREADY";
  attribute X_INTERFACE_INFO of s00_axi_arvalid : signal is "xilinx.com:interface:aximm:1.0 S00_AXI ARVALID";
  attribute X_INTERFACE_INFO of s00_axi_awready : signal is "xilinx.com:interface:aximm:1.0 S00_AXI AWREADY";
  attribute X_INTERFACE_INFO of s00_axi_awvalid : signal is "xilinx.com:interface:aximm:1.0 S00_AXI AWVALID";
  attribute X_INTERFACE_INFO of s00_axi_bready : signal is "xilinx.com:interface:aximm:1.0 S00_AXI BREADY";
  attribute X_INTERFACE_INFO of s00_axi_bvalid : signal is "xilinx.com:interface:aximm:1.0 S00_AXI BVALID";
  attribute X_INTERFACE_INFO of s00_axi_rready : signal is "xilinx.com:interface:aximm:1.0 S00_AXI RREADY";
  attribute X_INTERFACE_PARAMETER of s00_axi_rready : signal is "XIL_INTERFACENAME S00_AXI, WIZ_DATA_WIDTH 32, WIZ_NUM_REG 10, SUPPORTS_NARROW_BURST 0, DATA_WIDTH 32, PROTOCOL AXI4LITE, FREQ_HZ 100000000, ID_WIDTH 0, ADDR_WIDTH 6, AWUSER_WIDTH 0, ARUSER_WIDTH 0, WUSER_WIDTH 0, RUSER_WIDTH 0, BUSER_WIDTH 0, READ_WRITE_MODE READ_WRITE, HAS_BURST 0, HAS_LOCK 0, HAS_PROT 1, HAS_CACHE 0, HAS_QOS 0, HAS_REGION 0, HAS_WSTRB 1, HAS_BRESP 1, HAS_RRESP 1, NUM_READ_OUTSTANDING 2, NUM_WRITE_OUTSTANDING 2, MAX_BURST_LENGTH 1, PHASE 0.0, CLK_DOMAIN ebaz4205_processing_system7_0_0_FCLK_CLK0, NUM_READ_THREADS 1, NUM_WRITE_THREADS 1, RUSER_BITS_PER_BYTE 0, WUSER_BITS_PER_BYTE 0, INSERT_VIP 0";
  attribute X_INTERFACE_INFO of s00_axi_rvalid : signal is "xilinx.com:interface:aximm:1.0 S00_AXI RVALID";
  attribute X_INTERFACE_INFO of s00_axi_wready : signal is "xilinx.com:interface:aximm:1.0 S00_AXI WREADY";
  attribute X_INTERFACE_INFO of s00_axi_wvalid : signal is "xilinx.com:interface:aximm:1.0 S00_AXI WVALID";
  attribute X_INTERFACE_INFO of s00_axi_araddr : signal is "xilinx.com:interface:aximm:1.0 S00_AXI ARADDR";
  attribute X_INTERFACE_INFO of s00_axi_arprot : signal is "xilinx.com:interface:aximm:1.0 S00_AXI ARPROT";
  attribute X_INTERFACE_INFO of s00_axi_awaddr : signal is "xilinx.com:interface:aximm:1.0 S00_AXI AWADDR";
  attribute X_INTERFACE_INFO of s00_axi_awprot : signal is "xilinx.com:interface:aximm:1.0 S00_AXI AWPROT";
  attribute X_INTERFACE_INFO of s00_axi_bresp : signal is "xilinx.com:interface:aximm:1.0 S00_AXI BRESP";
  attribute X_INTERFACE_INFO of s00_axi_rdata : signal is "xilinx.com:interface:aximm:1.0 S00_AXI RDATA";
  attribute X_INTERFACE_INFO of s00_axi_rresp : signal is "xilinx.com:interface:aximm:1.0 S00_AXI RRESP";
  attribute X_INTERFACE_INFO of s00_axi_wdata : signal is "xilinx.com:interface:aximm:1.0 S00_AXI WDATA";
  attribute X_INTERFACE_INFO of s00_axi_wstrb : signal is "xilinx.com:interface:aximm:1.0 S00_AXI WSTRB";
begin
  s00_axi_bresp(1) <= \<const0>\;
  s00_axi_bresp(0) <= \<const0>\;
  s00_axi_rdata(31) <= \<const0>\;
  s00_axi_rdata(30) <= \<const0>\;
  s00_axi_rdata(29) <= \<const0>\;
  s00_axi_rdata(28) <= \<const0>\;
  s00_axi_rdata(27) <= \<const0>\;
  s00_axi_rdata(26) <= \<const0>\;
  s00_axi_rdata(25) <= \<const0>\;
  s00_axi_rdata(24) <= \<const0>\;
  s00_axi_rdata(23) <= \<const0>\;
  s00_axi_rdata(22) <= \<const0>\;
  s00_axi_rdata(21) <= \<const0>\;
  s00_axi_rdata(20) <= \<const0>\;
  s00_axi_rdata(19) <= \<const0>\;
  s00_axi_rdata(18) <= \<const0>\;
  s00_axi_rdata(17) <= \<const0>\;
  s00_axi_rdata(16) <= \<const0>\;
  s00_axi_rdata(15) <= \<const0>\;
  s00_axi_rdata(14) <= \<const0>\;
  s00_axi_rdata(13) <= \<const0>\;
  s00_axi_rdata(12) <= \<const0>\;
  s00_axi_rdata(11) <= \<const0>\;
  s00_axi_rdata(10) <= \<const0>\;
  s00_axi_rdata(9) <= \<const0>\;
  s00_axi_rdata(8) <= \<const0>\;
  s00_axi_rdata(7) <= \<const0>\;
  s00_axi_rdata(6) <= \<const0>\;
  s00_axi_rdata(5) <= \<const0>\;
  s00_axi_rdata(4) <= \<const0>\;
  s00_axi_rdata(3) <= \<const0>\;
  s00_axi_rdata(2) <= \<const0>\;
  s00_axi_rdata(1) <= \<const0>\;
  s00_axi_rdata(0) <= \<const0>\;
  s00_axi_rresp(1) <= \<const0>\;
  s00_axi_rresp(0) <= \<const0>\;
GND: unisim.vcomponents.GND
     port map (
      G => \<const0>\
    );
inst: entity work.ebaz4205_mixer_4_0_mixer_v1_0
     port map (
      A(15) => inst_n_21,
      A(14) => inst_n_22,
      A(13) => inst_n_23,
      A(12) => inst_n_24,
      A(11) => inst_n_25,
      A(10) => inst_n_26,
      A(9) => inst_n_27,
      A(8) => inst_n_28,
      A(7) => inst_n_29,
      A(6) => inst_n_30,
      A(5) => inst_n_31,
      A(4) => inst_n_32,
      A(3) => inst_n_33,
      A(2) => inst_n_34,
      A(1) => inst_n_35,
      A(0) => inst_n_36,
      B(15 downto 8) => B(15 downto 8),
      B(7) => inst_n_13,
      B(6) => inst_n_14,
      B(5) => inst_n_15,
      B(4) => inst_n_16,
      B(3) => inst_n_17,
      B(2) => inst_n_18,
      B(1) => inst_n_19,
      B(0) => inst_n_20,
      \GAIN_1_reg[15]\(15) => inst_n_53,
      \GAIN_1_reg[15]\(14) => inst_n_54,
      \GAIN_1_reg[15]\(13) => inst_n_55,
      \GAIN_1_reg[15]\(12) => inst_n_56,
      \GAIN_1_reg[15]\(11) => inst_n_57,
      \GAIN_1_reg[15]\(10) => inst_n_58,
      \GAIN_1_reg[15]\(9) => inst_n_59,
      \GAIN_1_reg[15]\(8) => inst_n_60,
      \GAIN_1_reg[15]\(7) => inst_n_61,
      \GAIN_1_reg[15]\(6) => inst_n_62,
      \GAIN_1_reg[15]\(5) => inst_n_63,
      \GAIN_1_reg[15]\(4) => inst_n_64,
      \GAIN_1_reg[15]\(3) => inst_n_65,
      \GAIN_1_reg[15]\(2) => inst_n_66,
      \GAIN_1_reg[15]\(1) => inst_n_67,
      \GAIN_1_reg[15]\(0) => inst_n_68,
      \GAIN_2_reg[15]\(15) => inst_n_37,
      \GAIN_2_reg[15]\(14) => inst_n_38,
      \GAIN_2_reg[15]\(13) => inst_n_39,
      \GAIN_2_reg[15]\(12) => inst_n_40,
      \GAIN_2_reg[15]\(11) => inst_n_41,
      \GAIN_2_reg[15]\(10) => inst_n_42,
      \GAIN_2_reg[15]\(9) => inst_n_43,
      \GAIN_2_reg[15]\(8) => inst_n_44,
      \GAIN_2_reg[15]\(7) => inst_n_45,
      \GAIN_2_reg[15]\(6) => inst_n_46,
      \GAIN_2_reg[15]\(5) => inst_n_47,
      \GAIN_2_reg[15]\(4) => inst_n_48,
      \GAIN_2_reg[15]\(3) => inst_n_49,
      \GAIN_2_reg[15]\(2) => inst_n_50,
      \GAIN_2_reg[15]\(1) => inst_n_51,
      \GAIN_2_reg[15]\(0) => inst_n_52,
      P(15) => \p_1_out__1_n_90\,
      P(14) => \p_1_out__1_n_91\,
      P(13) => \p_1_out__1_n_92\,
      P(12) => \p_1_out__1_n_93\,
      P(11) => \p_1_out__1_n_94\,
      P(10) => \p_1_out__1_n_95\,
      P(9) => \p_1_out__1_n_96\,
      P(8) => \p_1_out__1_n_97\,
      P(7) => \p_1_out__1_n_98\,
      P(6) => \p_1_out__1_n_99\,
      P(5) => \p_1_out__1_n_100\,
      P(4) => \p_1_out__1_n_101\,
      P(3) => \p_1_out__1_n_102\,
      P(2) => \p_1_out__1_n_103\,
      P(1) => \p_1_out__1_n_104\,
      P(0) => \p_1_out__1_n_105\,
      din0(15 downto 0) => din0(15 downto 0),
      dout(15 downto 0) => dout(15 downto 0),
      pix_clk => pix_clk,
      s00_axi_aclk => s00_axi_aclk,
      s00_axi_aresetn => s00_axi_aresetn,
      s00_axi_arready => s00_axi_arready,
      s00_axi_arvalid => s00_axi_arvalid,
      s00_axi_awaddr(3 downto 0) => s00_axi_awaddr(5 downto 2),
      s00_axi_awready => s00_axi_awready,
      s00_axi_awvalid => s00_axi_awvalid,
      s00_axi_bready => s00_axi_bready,
      s00_axi_bvalid => s00_axi_bvalid,
      s00_axi_rready => s00_axi_rready,
      s00_axi_rvalid => s00_axi_rvalid,
      s00_axi_wdata(15 downto 0) => s00_axi_wdata(15 downto 0),
      s00_axi_wready => s00_axi_wready,
      s00_axi_wstrb(1 downto 0) => s00_axi_wstrb(1 downto 0),
      s00_axi_wvalid => s00_axi_wvalid
    );
p_0_out: unisim.vcomponents.DSP48E1
    generic map(
      ACASCREG => 0,
      ADREG => 1,
      ALUMODEREG => 0,
      AREG => 0,
      AUTORESET_PATDET => "NO_RESET",
      A_INPUT => "DIRECT",
      BCASCREG => 0,
      BREG => 0,
      B_INPUT => "DIRECT",
      CARRYINREG => 0,
      CARRYINSELREG => 0,
      CREG => 1,
      DREG => 1,
      INMODEREG => 0,
      MASK => X"3FFFFFFFFFFF",
      MREG => 0,
      OPMODEREG => 0,
      PATTERN => X"000000000000",
      PREG => 0,
      SEL_MASK => "MASK",
      SEL_PATTERN => "PATTERN",
      USE_DPORT => false,
      USE_MULT => "MULTIPLY",
      USE_PATTERN_DETECT => "NO_PATDET",
      USE_SIMD => "ONE48"
    )
        port map (
      A(29 downto 16) => B"00000000000000",
      A(15 downto 0) => din2(15 downto 0),
      ACIN(29 downto 0) => B"000000000000000000000000000000",
      ACOUT(29 downto 0) => NLW_p_0_out_ACOUT_UNCONNECTED(29 downto 0),
      ALUMODE(3 downto 0) => B"0000",
      B(17 downto 16) => B"00",
      B(15) => inst_n_37,
      B(14) => inst_n_38,
      B(13) => inst_n_39,
      B(12) => inst_n_40,
      B(11) => inst_n_41,
      B(10) => inst_n_42,
      B(9) => inst_n_43,
      B(8) => inst_n_44,
      B(7) => inst_n_45,
      B(6) => inst_n_46,
      B(5) => inst_n_47,
      B(4) => inst_n_48,
      B(3) => inst_n_49,
      B(2) => inst_n_50,
      B(1) => inst_n_51,
      B(0) => inst_n_52,
      BCIN(17 downto 0) => B"000000000000000000",
      BCOUT(17 downto 0) => NLW_p_0_out_BCOUT_UNCONNECTED(17 downto 0),
      C(47 downto 0) => B"111111111111111111111111111111111111111111111111",
      CARRYCASCIN => '0',
      CARRYCASCOUT => NLW_p_0_out_CARRYCASCOUT_UNCONNECTED,
      CARRYIN => '0',
      CARRYINSEL(2 downto 0) => B"000",
      CARRYOUT(3 downto 0) => NLW_p_0_out_CARRYOUT_UNCONNECTED(3 downto 0),
      CEA1 => '0',
      CEA2 => '0',
      CEAD => '0',
      CEALUMODE => '0',
      CEB1 => '0',
      CEB2 => '0',
      CEC => '0',
      CECARRYIN => '0',
      CECTRL => '0',
      CED => '0',
      CEINMODE => '0',
      CEM => '0',
      CEP => '0',
      CLK => '0',
      D(24 downto 0) => B"0000000000000000000000000",
      INMODE(4 downto 0) => B"00000",
      MULTSIGNIN => '0',
      MULTSIGNOUT => NLW_p_0_out_MULTSIGNOUT_UNCONNECTED,
      OPMODE(6 downto 0) => B"0000101",
      OVERFLOW => NLW_p_0_out_OVERFLOW_UNCONNECTED,
      P(47 downto 32) => NLW_p_0_out_P_UNCONNECTED(47 downto 32),
      P(31) => p_0_out_n_74,
      P(30) => p_0_out_n_75,
      P(29) => p_0_out_n_76,
      P(28) => p_0_out_n_77,
      P(27) => p_0_out_n_78,
      P(26) => p_0_out_n_79,
      P(25) => p_0_out_n_80,
      P(24) => p_0_out_n_81,
      P(23) => p_0_out_n_82,
      P(22) => p_0_out_n_83,
      P(21) => p_0_out_n_84,
      P(20) => p_0_out_n_85,
      P(19) => p_0_out_n_86,
      P(18) => p_0_out_n_87,
      P(17) => p_0_out_n_88,
      P(16) => p_0_out_n_89,
      P(15 downto 0) => \p_0_out__0\(15 downto 0),
      PATTERNBDETECT => NLW_p_0_out_PATTERNBDETECT_UNCONNECTED,
      PATTERNDETECT => NLW_p_0_out_PATTERNDETECT_UNCONNECTED,
      PCIN(47 downto 0) => B"000000000000000000000000000000000000000000000000",
      PCOUT(47 downto 0) => NLW_p_0_out_PCOUT_UNCONNECTED(47 downto 0),
      RSTA => '0',
      RSTALLCARRYIN => '0',
      RSTALUMODE => '0',
      RSTB => '0',
      RSTC => '0',
      RSTCTRL => '0',
      RSTD => '0',
      RSTINMODE => '0',
      RSTM => '0',
      RSTP => '0',
      UNDERFLOW => NLW_p_0_out_UNDERFLOW_UNCONNECTED
    );
p_1_out: unisim.vcomponents.DSP48E1
    generic map(
      ACASCREG => 0,
      ADREG => 1,
      ALUMODEREG => 0,
      AREG => 0,
      AUTORESET_PATDET => "NO_RESET",
      A_INPUT => "DIRECT",
      BCASCREG => 0,
      BREG => 0,
      B_INPUT => "DIRECT",
      CARRYINREG => 0,
      CARRYINSELREG => 0,
      CREG => 0,
      DREG => 1,
      INMODEREG => 0,
      MASK => X"3FFFFFFFFFFF",
      MREG => 0,
      OPMODEREG => 0,
      PATTERN => X"000000000000",
      PREG => 0,
      SEL_MASK => "MASK",
      SEL_PATTERN => "PATTERN",
      USE_DPORT => false,
      USE_MULT => "MULTIPLY",
      USE_PATTERN_DETECT => "NO_PATDET",
      USE_SIMD => "ONE48"
    )
        port map (
      A(29 downto 16) => B"00000000000000",
      A(15 downto 0) => din1(15 downto 0),
      ACIN(29 downto 0) => B"000000000000000000000000000000",
      ACOUT(29 downto 0) => NLW_p_1_out_ACOUT_UNCONNECTED(29 downto 0),
      ALUMODE(3 downto 0) => B"0000",
      B(17 downto 16) => B"00",
      B(15) => inst_n_53,
      B(14) => inst_n_54,
      B(13) => inst_n_55,
      B(12) => inst_n_56,
      B(11) => inst_n_57,
      B(10) => inst_n_58,
      B(9) => inst_n_59,
      B(8) => inst_n_60,
      B(7) => inst_n_61,
      B(6) => inst_n_62,
      B(5) => inst_n_63,
      B(4) => inst_n_64,
      B(3) => inst_n_65,
      B(2) => inst_n_66,
      B(1) => inst_n_67,
      B(0) => inst_n_68,
      BCIN(17 downto 0) => B"000000000000000000",
      BCOUT(17 downto 0) => NLW_p_1_out_BCOUT_UNCONNECTED(17 downto 0),
      C(47 downto 16) => B"00000000000000000000000000000000",
      C(15 downto 0) => \p_0_out__0\(15 downto 0),
      CARRYCASCIN => '0',
      CARRYCASCOUT => NLW_p_1_out_CARRYCASCOUT_UNCONNECTED,
      CARRYIN => '0',
      CARRYINSEL(2 downto 0) => B"000",
      CARRYOUT(3 downto 0) => NLW_p_1_out_CARRYOUT_UNCONNECTED(3 downto 0),
      CEA1 => '0',
      CEA2 => '0',
      CEAD => '0',
      CEALUMODE => '0',
      CEB1 => '0',
      CEB2 => '0',
      CEC => '0',
      CECARRYIN => '0',
      CECTRL => '0',
      CED => '0',
      CEINMODE => '0',
      CEM => '0',
      CEP => '0',
      CLK => '0',
      D(24 downto 0) => B"0000000000000000000000000",
      INMODE(4 downto 0) => B"00000",
      MULTSIGNIN => '0',
      MULTSIGNOUT => NLW_p_1_out_MULTSIGNOUT_UNCONNECTED,
      OPMODE(6 downto 0) => B"0110101",
      OVERFLOW => NLW_p_1_out_OVERFLOW_UNCONNECTED,
      P(47 downto 16) => NLW_p_1_out_P_UNCONNECTED(47 downto 16),
      P(15) => p_1_out_n_90,
      P(14) => p_1_out_n_91,
      P(13) => p_1_out_n_92,
      P(12) => p_1_out_n_93,
      P(11) => p_1_out_n_94,
      P(10) => p_1_out_n_95,
      P(9) => p_1_out_n_96,
      P(8) => p_1_out_n_97,
      P(7) => p_1_out_n_98,
      P(6) => p_1_out_n_99,
      P(5) => p_1_out_n_100,
      P(4) => p_1_out_n_101,
      P(3) => p_1_out_n_102,
      P(2) => p_1_out_n_103,
      P(1) => p_1_out_n_104,
      P(0) => p_1_out_n_105,
      PATTERNBDETECT => NLW_p_1_out_PATTERNBDETECT_UNCONNECTED,
      PATTERNDETECT => NLW_p_1_out_PATTERNDETECT_UNCONNECTED,
      PCIN(47 downto 0) => B"000000000000000000000000000000000000000000000000",
      PCOUT(47) => p_1_out_n_106,
      PCOUT(46) => p_1_out_n_107,
      PCOUT(45) => p_1_out_n_108,
      PCOUT(44) => p_1_out_n_109,
      PCOUT(43) => p_1_out_n_110,
      PCOUT(42) => p_1_out_n_111,
      PCOUT(41) => p_1_out_n_112,
      PCOUT(40) => p_1_out_n_113,
      PCOUT(39) => p_1_out_n_114,
      PCOUT(38) => p_1_out_n_115,
      PCOUT(37) => p_1_out_n_116,
      PCOUT(36) => p_1_out_n_117,
      PCOUT(35) => p_1_out_n_118,
      PCOUT(34) => p_1_out_n_119,
      PCOUT(33) => p_1_out_n_120,
      PCOUT(32) => p_1_out_n_121,
      PCOUT(31) => p_1_out_n_122,
      PCOUT(30) => p_1_out_n_123,
      PCOUT(29) => p_1_out_n_124,
      PCOUT(28) => p_1_out_n_125,
      PCOUT(27) => p_1_out_n_126,
      PCOUT(26) => p_1_out_n_127,
      PCOUT(25) => p_1_out_n_128,
      PCOUT(24) => p_1_out_n_129,
      PCOUT(23) => p_1_out_n_130,
      PCOUT(22) => p_1_out_n_131,
      PCOUT(21) => p_1_out_n_132,
      PCOUT(20) => p_1_out_n_133,
      PCOUT(19) => p_1_out_n_134,
      PCOUT(18) => p_1_out_n_135,
      PCOUT(17) => p_1_out_n_136,
      PCOUT(16) => p_1_out_n_137,
      PCOUT(15) => p_1_out_n_138,
      PCOUT(14) => p_1_out_n_139,
      PCOUT(13) => p_1_out_n_140,
      PCOUT(12) => p_1_out_n_141,
      PCOUT(11) => p_1_out_n_142,
      PCOUT(10) => p_1_out_n_143,
      PCOUT(9) => p_1_out_n_144,
      PCOUT(8) => p_1_out_n_145,
      PCOUT(7) => p_1_out_n_146,
      PCOUT(6) => p_1_out_n_147,
      PCOUT(5) => p_1_out_n_148,
      PCOUT(4) => p_1_out_n_149,
      PCOUT(3) => p_1_out_n_150,
      PCOUT(2) => p_1_out_n_151,
      PCOUT(1) => p_1_out_n_152,
      PCOUT(0) => p_1_out_n_153,
      RSTA => '0',
      RSTALLCARRYIN => '0',
      RSTALUMODE => '0',
      RSTB => '0',
      RSTC => '0',
      RSTCTRL => '0',
      RSTD => '0',
      RSTINMODE => '0',
      RSTM => '0',
      RSTP => '0',
      UNDERFLOW => NLW_p_1_out_UNDERFLOW_UNCONNECTED
    );
\p_1_out__0\: unisim.vcomponents.DSP48E1
    generic map(
      ACASCREG => 0,
      ADREG => 1,
      ALUMODEREG => 0,
      AREG => 0,
      AUTORESET_PATDET => "NO_RESET",
      A_INPUT => "DIRECT",
      BCASCREG => 0,
      BREG => 0,
      B_INPUT => "DIRECT",
      CARRYINREG => 0,
      CARRYINSELREG => 0,
      CREG => 1,
      DREG => 1,
      INMODEREG => 0,
      MASK => X"3FFFFFFFFFFF",
      MREG => 0,
      OPMODEREG => 0,
      PATTERN => X"000000000000",
      PREG => 0,
      SEL_MASK => "MASK",
      SEL_PATTERN => "PATTERN",
      USE_DPORT => false,
      USE_MULT => "MULTIPLY",
      USE_PATTERN_DETECT => "NO_PATDET",
      USE_SIMD => "ONE48"
    )
        port map (
      A(29 downto 16) => B"00000000000000",
      A(15) => inst_n_21,
      A(14) => inst_n_22,
      A(13) => inst_n_23,
      A(12) => inst_n_24,
      A(11) => inst_n_25,
      A(10) => inst_n_26,
      A(9) => inst_n_27,
      A(8) => inst_n_28,
      A(7) => inst_n_29,
      A(6) => inst_n_30,
      A(5) => inst_n_31,
      A(4) => inst_n_32,
      A(3) => inst_n_33,
      A(2) => inst_n_34,
      A(1) => inst_n_35,
      A(0) => inst_n_36,
      ACIN(29 downto 0) => B"000000000000000000000000000000",
      ACOUT(29 downto 0) => \NLW_p_1_out__0_ACOUT_UNCONNECTED\(29 downto 0),
      ALUMODE(3 downto 0) => B"0000",
      B(17 downto 0) => B"000000000000000000",
      BCIN(17 downto 0) => B"000000000000000000",
      BCOUT(17 downto 0) => \NLW_p_1_out__0_BCOUT_UNCONNECTED\(17 downto 0),
      C(47 downto 0) => B"111111111111111111111111111111111111111111111111",
      CARRYCASCIN => '0',
      CARRYCASCOUT => \NLW_p_1_out__0_CARRYCASCOUT_UNCONNECTED\,
      CARRYIN => '0',
      CARRYINSEL(2 downto 0) => B"000",
      CARRYOUT(3 downto 0) => \NLW_p_1_out__0_CARRYOUT_UNCONNECTED\(3 downto 0),
      CEA1 => '0',
      CEA2 => '0',
      CEAD => '0',
      CEALUMODE => '0',
      CEB1 => '0',
      CEB2 => '0',
      CEC => '0',
      CECARRYIN => '0',
      CECTRL => '0',
      CED => '0',
      CEINMODE => '0',
      CEM => '0',
      CEP => '0',
      CLK => '0',
      D(24 downto 0) => B"0000000000000000000000000",
      INMODE(4 downto 0) => B"00000",
      MULTSIGNIN => '0',
      MULTSIGNOUT => \NLW_p_1_out__0_MULTSIGNOUT_UNCONNECTED\,
      OPMODE(6 downto 0) => B"0010101",
      OVERFLOW => \NLW_p_1_out__0_OVERFLOW_UNCONNECTED\,
      P(47 downto 16) => \NLW_p_1_out__0_P_UNCONNECTED\(47 downto 16),
      P(15) => \p_1_out__0_n_90\,
      P(14) => \p_1_out__0_n_91\,
      P(13) => \p_1_out__0_n_92\,
      P(12) => \p_1_out__0_n_93\,
      P(11) => \p_1_out__0_n_94\,
      P(10) => \p_1_out__0_n_95\,
      P(9) => \p_1_out__0_n_96\,
      P(8) => \p_1_out__0_n_97\,
      P(7) => \p_1_out__0_n_98\,
      P(6) => \p_1_out__0_n_99\,
      P(5) => \p_1_out__0_n_100\,
      P(4) => \p_1_out__0_n_101\,
      P(3) => \p_1_out__0_n_102\,
      P(2) => \p_1_out__0_n_103\,
      P(1) => \p_1_out__0_n_104\,
      P(0) => \p_1_out__0_n_105\,
      PATTERNBDETECT => \NLW_p_1_out__0_PATTERNBDETECT_UNCONNECTED\,
      PATTERNDETECT => \NLW_p_1_out__0_PATTERNDETECT_UNCONNECTED\,
      PCIN(47) => p_1_out_n_106,
      PCIN(46) => p_1_out_n_107,
      PCIN(45) => p_1_out_n_108,
      PCIN(44) => p_1_out_n_109,
      PCIN(43) => p_1_out_n_110,
      PCIN(42) => p_1_out_n_111,
      PCIN(41) => p_1_out_n_112,
      PCIN(40) => p_1_out_n_113,
      PCIN(39) => p_1_out_n_114,
      PCIN(38) => p_1_out_n_115,
      PCIN(37) => p_1_out_n_116,
      PCIN(36) => p_1_out_n_117,
      PCIN(35) => p_1_out_n_118,
      PCIN(34) => p_1_out_n_119,
      PCIN(33) => p_1_out_n_120,
      PCIN(32) => p_1_out_n_121,
      PCIN(31) => p_1_out_n_122,
      PCIN(30) => p_1_out_n_123,
      PCIN(29) => p_1_out_n_124,
      PCIN(28) => p_1_out_n_125,
      PCIN(27) => p_1_out_n_126,
      PCIN(26) => p_1_out_n_127,
      PCIN(25) => p_1_out_n_128,
      PCIN(24) => p_1_out_n_129,
      PCIN(23) => p_1_out_n_130,
      PCIN(22) => p_1_out_n_131,
      PCIN(21) => p_1_out_n_132,
      PCIN(20) => p_1_out_n_133,
      PCIN(19) => p_1_out_n_134,
      PCIN(18) => p_1_out_n_135,
      PCIN(17) => p_1_out_n_136,
      PCIN(16) => p_1_out_n_137,
      PCIN(15) => p_1_out_n_138,
      PCIN(14) => p_1_out_n_139,
      PCIN(13) => p_1_out_n_140,
      PCIN(12) => p_1_out_n_141,
      PCIN(11) => p_1_out_n_142,
      PCIN(10) => p_1_out_n_143,
      PCIN(9) => p_1_out_n_144,
      PCIN(8) => p_1_out_n_145,
      PCIN(7) => p_1_out_n_146,
      PCIN(6) => p_1_out_n_147,
      PCIN(5) => p_1_out_n_148,
      PCIN(4) => p_1_out_n_149,
      PCIN(3) => p_1_out_n_150,
      PCIN(2) => p_1_out_n_151,
      PCIN(1) => p_1_out_n_152,
      PCIN(0) => p_1_out_n_153,
      PCOUT(47) => \p_1_out__0_n_106\,
      PCOUT(46) => \p_1_out__0_n_107\,
      PCOUT(45) => \p_1_out__0_n_108\,
      PCOUT(44) => \p_1_out__0_n_109\,
      PCOUT(43) => \p_1_out__0_n_110\,
      PCOUT(42) => \p_1_out__0_n_111\,
      PCOUT(41) => \p_1_out__0_n_112\,
      PCOUT(40) => \p_1_out__0_n_113\,
      PCOUT(39) => \p_1_out__0_n_114\,
      PCOUT(38) => \p_1_out__0_n_115\,
      PCOUT(37) => \p_1_out__0_n_116\,
      PCOUT(36) => \p_1_out__0_n_117\,
      PCOUT(35) => \p_1_out__0_n_118\,
      PCOUT(34) => \p_1_out__0_n_119\,
      PCOUT(33) => \p_1_out__0_n_120\,
      PCOUT(32) => \p_1_out__0_n_121\,
      PCOUT(31) => \p_1_out__0_n_122\,
      PCOUT(30) => \p_1_out__0_n_123\,
      PCOUT(29) => \p_1_out__0_n_124\,
      PCOUT(28) => \p_1_out__0_n_125\,
      PCOUT(27) => \p_1_out__0_n_126\,
      PCOUT(26) => \p_1_out__0_n_127\,
      PCOUT(25) => \p_1_out__0_n_128\,
      PCOUT(24) => \p_1_out__0_n_129\,
      PCOUT(23) => \p_1_out__0_n_130\,
      PCOUT(22) => \p_1_out__0_n_131\,
      PCOUT(21) => \p_1_out__0_n_132\,
      PCOUT(20) => \p_1_out__0_n_133\,
      PCOUT(19) => \p_1_out__0_n_134\,
      PCOUT(18) => \p_1_out__0_n_135\,
      PCOUT(17) => \p_1_out__0_n_136\,
      PCOUT(16) => \p_1_out__0_n_137\,
      PCOUT(15) => \p_1_out__0_n_138\,
      PCOUT(14) => \p_1_out__0_n_139\,
      PCOUT(13) => \p_1_out__0_n_140\,
      PCOUT(12) => \p_1_out__0_n_141\,
      PCOUT(11) => \p_1_out__0_n_142\,
      PCOUT(10) => \p_1_out__0_n_143\,
      PCOUT(9) => \p_1_out__0_n_144\,
      PCOUT(8) => \p_1_out__0_n_145\,
      PCOUT(7) => \p_1_out__0_n_146\,
      PCOUT(6) => \p_1_out__0_n_147\,
      PCOUT(5) => \p_1_out__0_n_148\,
      PCOUT(4) => \p_1_out__0_n_149\,
      PCOUT(3) => \p_1_out__0_n_150\,
      PCOUT(2) => \p_1_out__0_n_151\,
      PCOUT(1) => \p_1_out__0_n_152\,
      PCOUT(0) => \p_1_out__0_n_153\,
      RSTA => '0',
      RSTALLCARRYIN => '0',
      RSTALUMODE => '0',
      RSTB => '0',
      RSTC => '0',
      RSTCTRL => '0',
      RSTD => '0',
      RSTINMODE => '0',
      RSTM => '0',
      RSTP => '0',
      UNDERFLOW => \NLW_p_1_out__0_UNDERFLOW_UNCONNECTED\
    );
\p_1_out__1\: unisim.vcomponents.DSP48E1
    generic map(
      ACASCREG => 0,
      ADREG => 1,
      ALUMODEREG => 0,
      AREG => 0,
      AUTORESET_PATDET => "NO_RESET",
      A_INPUT => "DIRECT",
      BCASCREG => 0,
      BREG => 0,
      B_INPUT => "DIRECT",
      CARRYINREG => 0,
      CARRYINSELREG => 0,
      CREG => 1,
      DREG => 1,
      INMODEREG => 0,
      MASK => X"3FFFFFFFFFFF",
      MREG => 0,
      OPMODEREG => 0,
      PATTERN => X"000000000000",
      PREG => 0,
      SEL_MASK => "MASK",
      SEL_PATTERN => "PATTERN",
      USE_DPORT => false,
      USE_MULT => "MULTIPLY",
      USE_PATTERN_DETECT => "NO_PATDET",
      USE_SIMD => "ONE48"
    )
        port map (
      A(29 downto 16) => B"00000000000000",
      A(15 downto 0) => din0(15 downto 0),
      ACIN(29 downto 0) => B"000000000000000000000000000000",
      ACOUT(29 downto 0) => \NLW_p_1_out__1_ACOUT_UNCONNECTED\(29 downto 0),
      ALUMODE(3 downto 0) => B"0000",
      B(17 downto 16) => B"00",
      B(15 downto 8) => B(15 downto 8),
      B(7) => inst_n_13,
      B(6) => inst_n_14,
      B(5) => inst_n_15,
      B(4) => inst_n_16,
      B(3) => inst_n_17,
      B(2) => inst_n_18,
      B(1) => inst_n_19,
      B(0) => inst_n_20,
      BCIN(17 downto 0) => B"000000000000000000",
      BCOUT(17 downto 0) => \NLW_p_1_out__1_BCOUT_UNCONNECTED\(17 downto 0),
      C(47 downto 0) => B"111111111111111111111111111111111111111111111111",
      CARRYCASCIN => '0',
      CARRYCASCOUT => \NLW_p_1_out__1_CARRYCASCOUT_UNCONNECTED\,
      CARRYIN => '0',
      CARRYINSEL(2 downto 0) => B"000",
      CARRYOUT(3 downto 0) => \NLW_p_1_out__1_CARRYOUT_UNCONNECTED\(3 downto 0),
      CEA1 => '0',
      CEA2 => '0',
      CEAD => '0',
      CEALUMODE => '0',
      CEB1 => '0',
      CEB2 => '0',
      CEC => '0',
      CECARRYIN => '0',
      CECTRL => '0',
      CED => '0',
      CEINMODE => '0',
      CEM => '0',
      CEP => '0',
      CLK => '0',
      D(24 downto 0) => B"0000000000000000000000000",
      INMODE(4 downto 0) => B"00000",
      MULTSIGNIN => '0',
      MULTSIGNOUT => \NLW_p_1_out__1_MULTSIGNOUT_UNCONNECTED\,
      OPMODE(6 downto 0) => B"0010101",
      OVERFLOW => \NLW_p_1_out__1_OVERFLOW_UNCONNECTED\,
      P(47 downto 16) => \NLW_p_1_out__1_P_UNCONNECTED\(47 downto 16),
      P(15) => \p_1_out__1_n_90\,
      P(14) => \p_1_out__1_n_91\,
      P(13) => \p_1_out__1_n_92\,
      P(12) => \p_1_out__1_n_93\,
      P(11) => \p_1_out__1_n_94\,
      P(10) => \p_1_out__1_n_95\,
      P(9) => \p_1_out__1_n_96\,
      P(8) => \p_1_out__1_n_97\,
      P(7) => \p_1_out__1_n_98\,
      P(6) => \p_1_out__1_n_99\,
      P(5) => \p_1_out__1_n_100\,
      P(4) => \p_1_out__1_n_101\,
      P(3) => \p_1_out__1_n_102\,
      P(2) => \p_1_out__1_n_103\,
      P(1) => \p_1_out__1_n_104\,
      P(0) => \p_1_out__1_n_105\,
      PATTERNBDETECT => \NLW_p_1_out__1_PATTERNBDETECT_UNCONNECTED\,
      PATTERNDETECT => \NLW_p_1_out__1_PATTERNDETECT_UNCONNECTED\,
      PCIN(47) => \p_1_out__0_n_106\,
      PCIN(46) => \p_1_out__0_n_107\,
      PCIN(45) => \p_1_out__0_n_108\,
      PCIN(44) => \p_1_out__0_n_109\,
      PCIN(43) => \p_1_out__0_n_110\,
      PCIN(42) => \p_1_out__0_n_111\,
      PCIN(41) => \p_1_out__0_n_112\,
      PCIN(40) => \p_1_out__0_n_113\,
      PCIN(39) => \p_1_out__0_n_114\,
      PCIN(38) => \p_1_out__0_n_115\,
      PCIN(37) => \p_1_out__0_n_116\,
      PCIN(36) => \p_1_out__0_n_117\,
      PCIN(35) => \p_1_out__0_n_118\,
      PCIN(34) => \p_1_out__0_n_119\,
      PCIN(33) => \p_1_out__0_n_120\,
      PCIN(32) => \p_1_out__0_n_121\,
      PCIN(31) => \p_1_out__0_n_122\,
      PCIN(30) => \p_1_out__0_n_123\,
      PCIN(29) => \p_1_out__0_n_124\,
      PCIN(28) => \p_1_out__0_n_125\,
      PCIN(27) => \p_1_out__0_n_126\,
      PCIN(26) => \p_1_out__0_n_127\,
      PCIN(25) => \p_1_out__0_n_128\,
      PCIN(24) => \p_1_out__0_n_129\,
      PCIN(23) => \p_1_out__0_n_130\,
      PCIN(22) => \p_1_out__0_n_131\,
      PCIN(21) => \p_1_out__0_n_132\,
      PCIN(20) => \p_1_out__0_n_133\,
      PCIN(19) => \p_1_out__0_n_134\,
      PCIN(18) => \p_1_out__0_n_135\,
      PCIN(17) => \p_1_out__0_n_136\,
      PCIN(16) => \p_1_out__0_n_137\,
      PCIN(15) => \p_1_out__0_n_138\,
      PCIN(14) => \p_1_out__0_n_139\,
      PCIN(13) => \p_1_out__0_n_140\,
      PCIN(12) => \p_1_out__0_n_141\,
      PCIN(11) => \p_1_out__0_n_142\,
      PCIN(10) => \p_1_out__0_n_143\,
      PCIN(9) => \p_1_out__0_n_144\,
      PCIN(8) => \p_1_out__0_n_145\,
      PCIN(7) => \p_1_out__0_n_146\,
      PCIN(6) => \p_1_out__0_n_147\,
      PCIN(5) => \p_1_out__0_n_148\,
      PCIN(4) => \p_1_out__0_n_149\,
      PCIN(3) => \p_1_out__0_n_150\,
      PCIN(2) => \p_1_out__0_n_151\,
      PCIN(1) => \p_1_out__0_n_152\,
      PCIN(0) => \p_1_out__0_n_153\,
      PCOUT(47 downto 0) => \NLW_p_1_out__1_PCOUT_UNCONNECTED\(47 downto 0),
      RSTA => '0',
      RSTALLCARRYIN => '0',
      RSTALUMODE => '0',
      RSTB => '0',
      RSTC => '0',
      RSTCTRL => '0',
      RSTD => '0',
      RSTINMODE => '0',
      RSTM => '0',
      RSTP => '0',
      UNDERFLOW => \NLW_p_1_out__1_UNDERFLOW_UNCONNECTED\
    );
end STRUCTURE;
