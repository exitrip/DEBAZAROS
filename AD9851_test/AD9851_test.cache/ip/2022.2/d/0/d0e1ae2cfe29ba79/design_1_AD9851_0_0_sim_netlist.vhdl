-- Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
-- --------------------------------------------------------------------------------
-- Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
-- Date        : Fri Aug 18 13:14:18 2023
-- Host        : guido-Neptune-series-i9 running 64-bit Ubuntu 22.04.3 LTS
-- Command     : write_vhdl -force -mode funcsim -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
--               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ design_1_AD9851_0_0_sim_netlist.vhdl
-- Design      : design_1_AD9851_0_0
-- Purpose     : This VHDL netlist is a functional simulation representation of the design and should not be modified or
--               synthesized. This netlist cannot be used for SDF annotated simulation.
-- Device      : xc7z010clg400-1
-- --------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_AD9851 is
  port (
    serial_data_out : out STD_LOGIC;
    serial_clock_out : out STD_LOGIC;
    fq_ud_out : out STD_LOGIC;
    valid_in : in STD_LOGIC;
    serial_clock_in : in STD_LOGIC;
    resetn : in STD_LOGIC;
    data_in : in STD_LOGIC_VECTOR ( 39 downto 0 )
  );
end decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_AD9851;

architecture STRUCTURE of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_AD9851 is
  signal active : STD_LOGIC;
  signal active7_out : STD_LOGIC;
  signal fq_ud3_out : STD_LOGIC;
  signal \^fq_ud_out\ : STD_LOGIC;
  signal fq_ud_reg_i_1_n_0 : STD_LOGIC;
  signal serial_clock_out_reg_i_1_n_0 : STD_LOGIC;
  signal serial_clock_out_reg_i_2_n_0 : STD_LOGIC;
  signal serial_clock_out_reg_i_3_n_0 : STD_LOGIC;
  signal serial_data : STD_LOGIC_VECTOR ( 39 downto 0 );
  signal \serial_data__0\ : STD_LOGIC;
  signal \serial_data_out__0_n_0\ : STD_LOGIC;
  signal \serial_data_reg[0]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[10]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[11]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[13]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[14]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[15]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[16]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[17]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[18]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[19]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[1]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[20]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[21]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[22]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[23]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[24]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[25]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[26]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[27]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[28]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[29]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[2]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[30]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[31]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[32]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[33]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[34]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[35]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[36]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[37]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[38]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[39]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[3]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[5]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[6]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[7]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \serial_data_reg[9]_i_1_n_0\ : STD_LOGIC;
  signal shift_counter : STD_LOGIC_VECTOR ( 31 downto 0 );
  signal shift_counter0 : STD_LOGIC_VECTOR ( 31 downto 1 );
  signal \shift_counter0_carry__0_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__0_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__0_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__0_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__1_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__1_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__1_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__1_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__2_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__2_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__2_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__2_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__3_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__3_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__3_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__3_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__4_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__4_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__4_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__4_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__5_n_0\ : STD_LOGIC;
  signal \shift_counter0_carry__5_n_1\ : STD_LOGIC;
  signal \shift_counter0_carry__5_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__5_n_3\ : STD_LOGIC;
  signal \shift_counter0_carry__6_n_2\ : STD_LOGIC;
  signal \shift_counter0_carry__6_n_3\ : STD_LOGIC;
  signal shift_counter0_carry_n_0 : STD_LOGIC;
  signal shift_counter0_carry_n_1 : STD_LOGIC;
  signal shift_counter0_carry_n_2 : STD_LOGIC;
  signal shift_counter0_carry_n_3 : STD_LOGIC;
  signal shift_counter1 : STD_LOGIC;
  signal \shift_counter1_carry__0_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__0_i_2_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__0_i_3_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__0_i_4_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__0_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__0_n_1\ : STD_LOGIC;
  signal \shift_counter1_carry__0_n_2\ : STD_LOGIC;
  signal \shift_counter1_carry__0_n_3\ : STD_LOGIC;
  signal \shift_counter1_carry__1_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__1_i_2_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__1_i_3_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__1_i_4_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__1_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__1_n_1\ : STD_LOGIC;
  signal \shift_counter1_carry__1_n_2\ : STD_LOGIC;
  signal \shift_counter1_carry__1_n_3\ : STD_LOGIC;
  signal \shift_counter1_carry__2_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__2_i_2_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__2_i_3_n_0\ : STD_LOGIC;
  signal \shift_counter1_carry__2_n_2\ : STD_LOGIC;
  signal \shift_counter1_carry__2_n_3\ : STD_LOGIC;
  signal shift_counter1_carry_i_1_n_0 : STD_LOGIC;
  signal shift_counter1_carry_i_2_n_0 : STD_LOGIC;
  signal shift_counter1_carry_i_3_n_0 : STD_LOGIC;
  signal shift_counter1_carry_i_4_n_0 : STD_LOGIC;
  signal shift_counter1_carry_i_5_n_0 : STD_LOGIC;
  signal shift_counter1_carry_i_6_n_0 : STD_LOGIC;
  signal shift_counter1_carry_n_0 : STD_LOGIC;
  signal shift_counter1_carry_n_1 : STD_LOGIC;
  signal shift_counter1_carry_n_2 : STD_LOGIC;
  signal shift_counter1_carry_n_3 : STD_LOGIC;
  signal \shift_counter__0\ : STD_LOGIC;
  signal \shift_counter_reg[0]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[10]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[11]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[12]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[13]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[14]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[15]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[16]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[17]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[18]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[19]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[1]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[20]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[21]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[22]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[23]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[24]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[25]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[26]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[27]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[28]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[29]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[2]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[30]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[31]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[3]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[4]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[5]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[6]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[7]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[8]_i_1_n_0\ : STD_LOGIC;
  signal \shift_counter_reg[9]_i_1_n_0\ : STD_LOGIC;
  signal \NLW_shift_counter0_carry__6_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 2 );
  signal \NLW_shift_counter0_carry__6_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal NLW_shift_counter1_carry_O_UNCONNECTED : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_shift_counter1_carry__0_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_shift_counter1_carry__1_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  signal \NLW_shift_counter1_carry__2_CO_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 to 3 );
  signal \NLW_shift_counter1_carry__2_O_UNCONNECTED\ : STD_LOGIC_VECTOR ( 3 downto 0 );
  attribute XILINX_LEGACY_PRIM : string;
  attribute XILINX_LEGACY_PRIM of active_reg : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP : string;
  attribute XILINX_TRANSFORM_PINMAP of active_reg : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM : string;
  attribute SOFT_HLUTNM of active_reg_i_1 : label is "soft_lutpair0";
  attribute XILINX_LEGACY_PRIM of fq_ud_reg : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of fq_ud_reg : label is "VCC:GE";
  attribute SOFT_HLUTNM of fq_ud_reg_i_1 : label is "soft_lutpair2";
  attribute SOFT_HLUTNM of fq_ud_reg_i_2 : label is "soft_lutpair1";
  attribute XILINX_LEGACY_PRIM of serial_clock_out_reg : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of serial_clock_out_reg : label is "VCC:GE";
  attribute SOFT_HLUTNM of serial_clock_out_reg_i_2 : label is "soft_lutpair1";
  attribute SOFT_HLUTNM of \serial_data_out__0\ : label is "soft_lutpair0";
  attribute XILINX_LEGACY_PRIM of serial_data_out_reg : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of serial_data_out_reg : label is "VCC:GE GND:CLR";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[0]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[0]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[0]_i_1\ : label is "soft_lutpair3";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[10]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[10]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[10]_i_1\ : label is "soft_lutpair8";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[11]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[11]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[11]_i_1\ : label is "soft_lutpair8";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[12]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[12]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[12]_i_1\ : label is "soft_lutpair9";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[13]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[13]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[13]_i_1\ : label is "soft_lutpair9";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[14]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[14]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[14]_i_1\ : label is "soft_lutpair10";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[15]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[15]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[15]_i_1\ : label is "soft_lutpair10";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[16]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[16]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[16]_i_1\ : label is "soft_lutpair11";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[17]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[17]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[17]_i_1\ : label is "soft_lutpair11";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[18]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[18]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[18]_i_1\ : label is "soft_lutpair12";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[19]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[19]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[19]_i_1\ : label is "soft_lutpair12";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[1]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[1]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[1]_i_1\ : label is "soft_lutpair3";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[20]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[20]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[20]_i_1\ : label is "soft_lutpair13";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[21]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[21]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[21]_i_1\ : label is "soft_lutpair13";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[22]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[22]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[22]_i_1\ : label is "soft_lutpair14";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[23]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[23]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[23]_i_1\ : label is "soft_lutpair14";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[24]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[24]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[24]_i_1\ : label is "soft_lutpair15";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[25]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[25]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[25]_i_1\ : label is "soft_lutpair15";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[26]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[26]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[26]_i_1\ : label is "soft_lutpair16";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[27]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[27]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[27]_i_1\ : label is "soft_lutpair16";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[28]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[28]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[28]_i_1\ : label is "soft_lutpair17";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[29]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[29]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[29]_i_1\ : label is "soft_lutpair17";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[2]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[2]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[2]_i_1\ : label is "soft_lutpair4";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[30]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[30]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[30]_i_1\ : label is "soft_lutpair18";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[31]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[31]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[31]_i_1\ : label is "soft_lutpair18";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[32]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[32]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[32]_i_1\ : label is "soft_lutpair19";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[33]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[33]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[33]_i_1\ : label is "soft_lutpair19";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[34]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[34]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[34]_i_1\ : label is "soft_lutpair20";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[35]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[35]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[35]_i_1\ : label is "soft_lutpair20";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[36]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[36]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[36]_i_1\ : label is "soft_lutpair21";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[37]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[37]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[37]_i_1\ : label is "soft_lutpair21";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[38]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[38]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[38]_i_1\ : label is "soft_lutpair22";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[39]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[39]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[39]_i_1\ : label is "soft_lutpair22";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[3]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[3]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[3]_i_1\ : label is "soft_lutpair4";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[4]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[4]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[4]_i_1\ : label is "soft_lutpair5";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[5]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[5]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[5]_i_1\ : label is "soft_lutpair5";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[6]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[6]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[6]_i_1\ : label is "soft_lutpair6";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[7]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[7]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[7]_i_1\ : label is "soft_lutpair6";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[8]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[8]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[8]_i_1\ : label is "soft_lutpair7";
  attribute XILINX_LEGACY_PRIM of \serial_data_reg[9]\ : label is "LD";
  attribute XILINX_TRANSFORM_PINMAP of \serial_data_reg[9]\ : label is "VCC:GE GND:CLR";
  attribute SOFT_HLUTNM of \serial_data_reg[9]_i_1\ : label is "soft_lutpair7";
  attribute ADDER_THRESHOLD : integer;
  attribute ADDER_THRESHOLD of shift_counter0_carry : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__0\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__1\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__2\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__3\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__4\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__5\ : label is 35;
  attribute ADDER_THRESHOLD of \shift_counter0_carry__6\ : label is 35;
  attribute COMPARATOR_THRESHOLD : integer;
  attribute COMPARATOR_THRESHOLD of shift_counter1_carry : label is 11;
  attribute COMPARATOR_THRESHOLD of \shift_counter1_carry__0\ : label is 11;
  attribute COMPARATOR_THRESHOLD of \shift_counter1_carry__1\ : label is 11;
  attribute COMPARATOR_THRESHOLD of \shift_counter1_carry__2\ : label is 11;
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[0]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[0]\ : label is "VCC:GE";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[10]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[10]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[10]_i_1\ : label is "soft_lutpair27";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[11]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[11]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[11]_i_1\ : label is "soft_lutpair27";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[12]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[12]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[12]_i_1\ : label is "soft_lutpair28";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[13]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[13]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[13]_i_1\ : label is "soft_lutpair28";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[14]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[14]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[14]_i_1\ : label is "soft_lutpair29";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[15]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[15]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[15]_i_1\ : label is "soft_lutpair29";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[16]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[16]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[16]_i_1\ : label is "soft_lutpair30";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[17]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[17]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[17]_i_1\ : label is "soft_lutpair30";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[18]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[18]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[18]_i_1\ : label is "soft_lutpair31";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[19]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[19]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[19]_i_1\ : label is "soft_lutpair31";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[1]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[1]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[1]_i_1\ : label is "soft_lutpair2";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[20]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[20]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[20]_i_1\ : label is "soft_lutpair32";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[21]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[21]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[21]_i_1\ : label is "soft_lutpair32";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[22]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[22]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[22]_i_1\ : label is "soft_lutpair33";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[23]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[23]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[23]_i_1\ : label is "soft_lutpair33";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[24]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[24]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[24]_i_1\ : label is "soft_lutpair34";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[25]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[25]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[25]_i_1\ : label is "soft_lutpair34";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[26]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[26]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[26]_i_1\ : label is "soft_lutpair35";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[27]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[27]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[27]_i_1\ : label is "soft_lutpair35";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[28]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[28]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[28]_i_1\ : label is "soft_lutpair36";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[29]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[29]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[29]_i_1\ : label is "soft_lutpair36";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[2]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[2]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[2]_i_1\ : label is "soft_lutpair23";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[30]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[30]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[30]_i_1\ : label is "soft_lutpair37";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[31]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[31]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[31]_i_1\ : label is "soft_lutpair37";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[3]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[3]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[3]_i_1\ : label is "soft_lutpair23";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[4]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[4]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[4]_i_1\ : label is "soft_lutpair24";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[5]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[5]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[5]_i_1\ : label is "soft_lutpair24";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[6]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[6]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[6]_i_1\ : label is "soft_lutpair25";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[7]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[7]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[7]_i_1\ : label is "soft_lutpair25";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[8]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[8]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[8]_i_1\ : label is "soft_lutpair26";
  attribute XILINX_LEGACY_PRIM of \shift_counter_reg[9]\ : label is "LDC";
  attribute XILINX_TRANSFORM_PINMAP of \shift_counter_reg[9]\ : label is "VCC:GE";
  attribute SOFT_HLUTNM of \shift_counter_reg[9]_i_1\ : label is "soft_lutpair26";
begin
  fq_ud_out <= \^fq_ud_out\;
\/i_\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"A8880000"
    )
        port map (
      I0 => resetn,
      I1 => valid_in,
      I2 => shift_counter1,
      I3 => active,
      I4 => serial_clock_in,
      O => \serial_data__0\
    );
active_reg: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => valid_in,
      G => active7_out,
      GE => '1',
      Q => active
    );
active_reg_i_1: unisim.vcomponents.LUT5
    generic map(
      INIT => X"88880080"
    )
        port map (
      I0 => resetn,
      I1 => serial_clock_in,
      I2 => active,
      I3 => shift_counter1,
      I4 => valid_in,
      O => active7_out
    );
fq_ud_reg: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => fq_ud_reg_i_1_n_0,
      G => fq_ud3_out,
      GE => '1',
      Q => \^fq_ud_out\
    );
fq_ud_reg_i_1: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => shift_counter1,
      I1 => active,
      I2 => valid_in,
      O => fq_ud_reg_i_1_n_0
    );
fq_ud_reg_i_2: unisim.vcomponents.LUT4
    generic map(
      INIT => X"AAA8"
    )
        port map (
      I0 => serial_clock_in,
      I1 => active,
      I2 => \^fq_ud_out\,
      I3 => valid_in,
      O => fq_ud3_out
    );
serial_clock_out_reg: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => serial_clock_out_reg_i_1_n_0,
      G => serial_clock_out_reg_i_2_n_0,
      GE => '1',
      Q => serial_clock_out
    );
serial_clock_out_reg_i_1: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => active,
      I1 => serial_clock_in,
      O => serial_clock_out_reg_i_1_n_0
    );
serial_clock_out_reg_i_2: unisim.vcomponents.LUT3
    generic map(
      INIT => X"4F"
    )
        port map (
      I0 => valid_in,
      I1 => active,
      I2 => serial_clock_in,
      O => serial_clock_out_reg_i_2_n_0
    );
serial_clock_out_reg_i_3: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => resetn,
      O => serial_clock_out_reg_i_3_n_0
    );
\serial_data_out__0\: unisim.vcomponents.LUT5
    generic map(
      INIT => X"40000000"
    )
        port map (
      I0 => valid_in,
      I1 => active,
      I2 => shift_counter1,
      I3 => serial_clock_in,
      I4 => resetn,
      O => \serial_data_out__0_n_0\
    );
serial_data_out_reg: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => serial_data(39),
      G => \serial_data_out__0_n_0\,
      GE => '1',
      Q => serial_data_out
    );
\serial_data_reg[0]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[0]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(0)
    );
\serial_data_reg[0]_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"8"
    )
        port map (
      I0 => valid_in,
      I1 => data_in(0),
      O => \serial_data_reg[0]_i_1_n_0\
    );
\serial_data_reg[10]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[10]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(10)
    );
\serial_data_reg[10]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(10),
      I1 => valid_in,
      I2 => serial_data(9),
      O => \serial_data_reg[10]_i_1_n_0\
    );
\serial_data_reg[11]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[11]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(11)
    );
\serial_data_reg[11]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(11),
      I1 => valid_in,
      I2 => serial_data(10),
      O => \serial_data_reg[11]_i_1_n_0\
    );
\serial_data_reg[12]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[12]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(12)
    );
\serial_data_reg[12]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(12),
      I1 => valid_in,
      I2 => serial_data(11),
      O => \serial_data_reg[12]_i_1_n_0\
    );
\serial_data_reg[13]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[13]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(13)
    );
\serial_data_reg[13]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(13),
      I1 => valid_in,
      I2 => serial_data(12),
      O => \serial_data_reg[13]_i_1_n_0\
    );
\serial_data_reg[14]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[14]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(14)
    );
\serial_data_reg[14]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(14),
      I1 => valid_in,
      I2 => serial_data(13),
      O => \serial_data_reg[14]_i_1_n_0\
    );
\serial_data_reg[15]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[15]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(15)
    );
\serial_data_reg[15]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(15),
      I1 => valid_in,
      I2 => serial_data(14),
      O => \serial_data_reg[15]_i_1_n_0\
    );
\serial_data_reg[16]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[16]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(16)
    );
\serial_data_reg[16]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(16),
      I1 => valid_in,
      I2 => serial_data(15),
      O => \serial_data_reg[16]_i_1_n_0\
    );
\serial_data_reg[17]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[17]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(17)
    );
\serial_data_reg[17]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(17),
      I1 => valid_in,
      I2 => serial_data(16),
      O => \serial_data_reg[17]_i_1_n_0\
    );
\serial_data_reg[18]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[18]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(18)
    );
\serial_data_reg[18]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(18),
      I1 => valid_in,
      I2 => serial_data(17),
      O => \serial_data_reg[18]_i_1_n_0\
    );
\serial_data_reg[19]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[19]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(19)
    );
\serial_data_reg[19]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(19),
      I1 => valid_in,
      I2 => serial_data(18),
      O => \serial_data_reg[19]_i_1_n_0\
    );
\serial_data_reg[1]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[1]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(1)
    );
\serial_data_reg[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(1),
      I1 => valid_in,
      I2 => serial_data(0),
      O => \serial_data_reg[1]_i_1_n_0\
    );
\serial_data_reg[20]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[20]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(20)
    );
\serial_data_reg[20]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(20),
      I1 => valid_in,
      I2 => serial_data(19),
      O => \serial_data_reg[20]_i_1_n_0\
    );
\serial_data_reg[21]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[21]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(21)
    );
\serial_data_reg[21]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(21),
      I1 => valid_in,
      I2 => serial_data(20),
      O => \serial_data_reg[21]_i_1_n_0\
    );
\serial_data_reg[22]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[22]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(22)
    );
\serial_data_reg[22]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(22),
      I1 => valid_in,
      I2 => serial_data(21),
      O => \serial_data_reg[22]_i_1_n_0\
    );
\serial_data_reg[23]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[23]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(23)
    );
\serial_data_reg[23]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(23),
      I1 => valid_in,
      I2 => serial_data(22),
      O => \serial_data_reg[23]_i_1_n_0\
    );
\serial_data_reg[24]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[24]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(24)
    );
\serial_data_reg[24]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(24),
      I1 => valid_in,
      I2 => serial_data(23),
      O => \serial_data_reg[24]_i_1_n_0\
    );
\serial_data_reg[25]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[25]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(25)
    );
\serial_data_reg[25]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(25),
      I1 => valid_in,
      I2 => serial_data(24),
      O => \serial_data_reg[25]_i_1_n_0\
    );
\serial_data_reg[26]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[26]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(26)
    );
\serial_data_reg[26]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(26),
      I1 => valid_in,
      I2 => serial_data(25),
      O => \serial_data_reg[26]_i_1_n_0\
    );
\serial_data_reg[27]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[27]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(27)
    );
\serial_data_reg[27]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(27),
      I1 => valid_in,
      I2 => serial_data(26),
      O => \serial_data_reg[27]_i_1_n_0\
    );
\serial_data_reg[28]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[28]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(28)
    );
\serial_data_reg[28]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(28),
      I1 => valid_in,
      I2 => serial_data(27),
      O => \serial_data_reg[28]_i_1_n_0\
    );
\serial_data_reg[29]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[29]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(29)
    );
\serial_data_reg[29]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(29),
      I1 => valid_in,
      I2 => serial_data(28),
      O => \serial_data_reg[29]_i_1_n_0\
    );
\serial_data_reg[2]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[2]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(2)
    );
\serial_data_reg[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(2),
      I1 => valid_in,
      I2 => serial_data(1),
      O => \serial_data_reg[2]_i_1_n_0\
    );
\serial_data_reg[30]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[30]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(30)
    );
\serial_data_reg[30]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(30),
      I1 => valid_in,
      I2 => serial_data(29),
      O => \serial_data_reg[30]_i_1_n_0\
    );
\serial_data_reg[31]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[31]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(31)
    );
\serial_data_reg[31]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(31),
      I1 => valid_in,
      I2 => serial_data(30),
      O => \serial_data_reg[31]_i_1_n_0\
    );
\serial_data_reg[32]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[32]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(32)
    );
\serial_data_reg[32]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(32),
      I1 => valid_in,
      I2 => serial_data(31),
      O => \serial_data_reg[32]_i_1_n_0\
    );
\serial_data_reg[33]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[33]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(33)
    );
\serial_data_reg[33]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(33),
      I1 => valid_in,
      I2 => serial_data(32),
      O => \serial_data_reg[33]_i_1_n_0\
    );
\serial_data_reg[34]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[34]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(34)
    );
\serial_data_reg[34]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(34),
      I1 => valid_in,
      I2 => serial_data(33),
      O => \serial_data_reg[34]_i_1_n_0\
    );
\serial_data_reg[35]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[35]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(35)
    );
\serial_data_reg[35]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(35),
      I1 => valid_in,
      I2 => serial_data(34),
      O => \serial_data_reg[35]_i_1_n_0\
    );
\serial_data_reg[36]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[36]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(36)
    );
\serial_data_reg[36]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(36),
      I1 => valid_in,
      I2 => serial_data(35),
      O => \serial_data_reg[36]_i_1_n_0\
    );
\serial_data_reg[37]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[37]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(37)
    );
\serial_data_reg[37]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(37),
      I1 => valid_in,
      I2 => serial_data(36),
      O => \serial_data_reg[37]_i_1_n_0\
    );
\serial_data_reg[38]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[38]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(38)
    );
\serial_data_reg[38]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(38),
      I1 => valid_in,
      I2 => serial_data(37),
      O => \serial_data_reg[38]_i_1_n_0\
    );
\serial_data_reg[39]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[39]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(39)
    );
\serial_data_reg[39]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(39),
      I1 => valid_in,
      I2 => serial_data(38),
      O => \serial_data_reg[39]_i_1_n_0\
    );
\serial_data_reg[3]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[3]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(3)
    );
\serial_data_reg[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(3),
      I1 => valid_in,
      I2 => serial_data(2),
      O => \serial_data_reg[3]_i_1_n_0\
    );
\serial_data_reg[4]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[4]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(4)
    );
\serial_data_reg[4]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(4),
      I1 => valid_in,
      I2 => serial_data(3),
      O => \serial_data_reg[4]_i_1_n_0\
    );
\serial_data_reg[5]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[5]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(5)
    );
\serial_data_reg[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(5),
      I1 => valid_in,
      I2 => serial_data(4),
      O => \serial_data_reg[5]_i_1_n_0\
    );
\serial_data_reg[6]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[6]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(6)
    );
\serial_data_reg[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(6),
      I1 => valid_in,
      I2 => serial_data(5),
      O => \serial_data_reg[6]_i_1_n_0\
    );
\serial_data_reg[7]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[7]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(7)
    );
\serial_data_reg[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(7),
      I1 => valid_in,
      I2 => serial_data(6),
      O => \serial_data_reg[7]_i_1_n_0\
    );
\serial_data_reg[8]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[8]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(8)
    );
\serial_data_reg[8]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(8),
      I1 => valid_in,
      I2 => serial_data(7),
      O => \serial_data_reg[8]_i_1_n_0\
    );
\serial_data_reg[9]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => '0',
      D => \serial_data_reg[9]_i_1_n_0\,
      G => \serial_data__0\,
      GE => '1',
      Q => serial_data(9)
    );
\serial_data_reg[9]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"B8"
    )
        port map (
      I0 => data_in(9),
      I1 => valid_in,
      I2 => serial_data(8),
      O => \serial_data_reg[9]_i_1_n_0\
    );
shift_counter0_carry: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => shift_counter0_carry_n_0,
      CO(2) => shift_counter0_carry_n_1,
      CO(1) => shift_counter0_carry_n_2,
      CO(0) => shift_counter0_carry_n_3,
      CYINIT => shift_counter(0),
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(4 downto 1),
      S(3 downto 0) => shift_counter(4 downto 1)
    );
\shift_counter0_carry__0\: unisim.vcomponents.CARRY4
     port map (
      CI => shift_counter0_carry_n_0,
      CO(3) => \shift_counter0_carry__0_n_0\,
      CO(2) => \shift_counter0_carry__0_n_1\,
      CO(1) => \shift_counter0_carry__0_n_2\,
      CO(0) => \shift_counter0_carry__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(8 downto 5),
      S(3 downto 0) => shift_counter(8 downto 5)
    );
\shift_counter0_carry__1\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__0_n_0\,
      CO(3) => \shift_counter0_carry__1_n_0\,
      CO(2) => \shift_counter0_carry__1_n_1\,
      CO(1) => \shift_counter0_carry__1_n_2\,
      CO(0) => \shift_counter0_carry__1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(12 downto 9),
      S(3 downto 0) => shift_counter(12 downto 9)
    );
\shift_counter0_carry__2\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__1_n_0\,
      CO(3) => \shift_counter0_carry__2_n_0\,
      CO(2) => \shift_counter0_carry__2_n_1\,
      CO(1) => \shift_counter0_carry__2_n_2\,
      CO(0) => \shift_counter0_carry__2_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(16 downto 13),
      S(3 downto 0) => shift_counter(16 downto 13)
    );
\shift_counter0_carry__3\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__2_n_0\,
      CO(3) => \shift_counter0_carry__3_n_0\,
      CO(2) => \shift_counter0_carry__3_n_1\,
      CO(1) => \shift_counter0_carry__3_n_2\,
      CO(0) => \shift_counter0_carry__3_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(20 downto 17),
      S(3 downto 0) => shift_counter(20 downto 17)
    );
\shift_counter0_carry__4\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__3_n_0\,
      CO(3) => \shift_counter0_carry__4_n_0\,
      CO(2) => \shift_counter0_carry__4_n_1\,
      CO(1) => \shift_counter0_carry__4_n_2\,
      CO(0) => \shift_counter0_carry__4_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(24 downto 21),
      S(3 downto 0) => shift_counter(24 downto 21)
    );
\shift_counter0_carry__5\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__4_n_0\,
      CO(3) => \shift_counter0_carry__5_n_0\,
      CO(2) => \shift_counter0_carry__5_n_1\,
      CO(1) => \shift_counter0_carry__5_n_2\,
      CO(0) => \shift_counter0_carry__5_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => shift_counter0(28 downto 25),
      S(3 downto 0) => shift_counter(28 downto 25)
    );
\shift_counter0_carry__6\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter0_carry__5_n_0\,
      CO(3 downto 2) => \NLW_shift_counter0_carry__6_CO_UNCONNECTED\(3 downto 2),
      CO(1) => \shift_counter0_carry__6_n_2\,
      CO(0) => \shift_counter0_carry__6_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3) => \NLW_shift_counter0_carry__6_O_UNCONNECTED\(3),
      O(2 downto 0) => shift_counter0(31 downto 29),
      S(3) => '0',
      S(2 downto 0) => shift_counter(31 downto 29)
    );
shift_counter1_carry: unisim.vcomponents.CARRY4
     port map (
      CI => '0',
      CO(3) => shift_counter1_carry_n_0,
      CO(2) => shift_counter1_carry_n_1,
      CO(1) => shift_counter1_carry_n_2,
      CO(0) => shift_counter1_carry_n_3,
      CYINIT => '0',
      DI(3 downto 2) => B"00",
      DI(1) => shift_counter1_carry_i_1_n_0,
      DI(0) => shift_counter1_carry_i_2_n_0,
      O(3 downto 0) => NLW_shift_counter1_carry_O_UNCONNECTED(3 downto 0),
      S(3) => shift_counter1_carry_i_3_n_0,
      S(2) => shift_counter1_carry_i_4_n_0,
      S(1) => shift_counter1_carry_i_5_n_0,
      S(0) => shift_counter1_carry_i_6_n_0
    );
\shift_counter1_carry__0\: unisim.vcomponents.CARRY4
     port map (
      CI => shift_counter1_carry_n_0,
      CO(3) => \shift_counter1_carry__0_n_0\,
      CO(2) => \shift_counter1_carry__0_n_1\,
      CO(1) => \shift_counter1_carry__0_n_2\,
      CO(0) => \shift_counter1_carry__0_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_shift_counter1_carry__0_O_UNCONNECTED\(3 downto 0),
      S(3) => \shift_counter1_carry__0_i_1_n_0\,
      S(2) => \shift_counter1_carry__0_i_2_n_0\,
      S(1) => \shift_counter1_carry__0_i_3_n_0\,
      S(0) => \shift_counter1_carry__0_i_4_n_0\
    );
\shift_counter1_carry__0_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(16),
      I1 => shift_counter(17),
      O => \shift_counter1_carry__0_i_1_n_0\
    );
\shift_counter1_carry__0_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(14),
      I1 => shift_counter(15),
      O => \shift_counter1_carry__0_i_2_n_0\
    );
\shift_counter1_carry__0_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(12),
      I1 => shift_counter(13),
      O => \shift_counter1_carry__0_i_3_n_0\
    );
\shift_counter1_carry__0_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(10),
      I1 => shift_counter(11),
      O => \shift_counter1_carry__0_i_4_n_0\
    );
\shift_counter1_carry__1\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter1_carry__0_n_0\,
      CO(3) => \shift_counter1_carry__1_n_0\,
      CO(2) => \shift_counter1_carry__1_n_1\,
      CO(1) => \shift_counter1_carry__1_n_2\,
      CO(0) => \shift_counter1_carry__1_n_3\,
      CYINIT => '0',
      DI(3 downto 0) => B"0000",
      O(3 downto 0) => \NLW_shift_counter1_carry__1_O_UNCONNECTED\(3 downto 0),
      S(3) => \shift_counter1_carry__1_i_1_n_0\,
      S(2) => \shift_counter1_carry__1_i_2_n_0\,
      S(1) => \shift_counter1_carry__1_i_3_n_0\,
      S(0) => \shift_counter1_carry__1_i_4_n_0\
    );
\shift_counter1_carry__1_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(24),
      I1 => shift_counter(25),
      O => \shift_counter1_carry__1_i_1_n_0\
    );
\shift_counter1_carry__1_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(22),
      I1 => shift_counter(23),
      O => \shift_counter1_carry__1_i_2_n_0\
    );
\shift_counter1_carry__1_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(20),
      I1 => shift_counter(21),
      O => \shift_counter1_carry__1_i_3_n_0\
    );
\shift_counter1_carry__1_i_4\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(18),
      I1 => shift_counter(19),
      O => \shift_counter1_carry__1_i_4_n_0\
    );
\shift_counter1_carry__2\: unisim.vcomponents.CARRY4
     port map (
      CI => \shift_counter1_carry__1_n_0\,
      CO(3) => \NLW_shift_counter1_carry__2_CO_UNCONNECTED\(3),
      CO(2) => shift_counter1,
      CO(1) => \shift_counter1_carry__2_n_2\,
      CO(0) => \shift_counter1_carry__2_n_3\,
      CYINIT => '0',
      DI(3) => '0',
      DI(2) => shift_counter(31),
      DI(1 downto 0) => B"00",
      O(3 downto 0) => \NLW_shift_counter1_carry__2_O_UNCONNECTED\(3 downto 0),
      S(3) => '0',
      S(2) => \shift_counter1_carry__2_i_1_n_0\,
      S(1) => \shift_counter1_carry__2_i_2_n_0\,
      S(0) => \shift_counter1_carry__2_i_3_n_0\
    );
\shift_counter1_carry__2_i_1\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(30),
      I1 => shift_counter(31),
      O => \shift_counter1_carry__2_i_1_n_0\
    );
\shift_counter1_carry__2_i_2\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(28),
      I1 => shift_counter(29),
      O => \shift_counter1_carry__2_i_2_n_0\
    );
\shift_counter1_carry__2_i_3\: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(26),
      I1 => shift_counter(27),
      O => \shift_counter1_carry__2_i_3_n_0\
    );
shift_counter1_carry_i_1: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(5),
      O => shift_counter1_carry_i_1_n_0
    );
shift_counter1_carry_i_2: unisim.vcomponents.LUT1
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(3),
      O => shift_counter1_carry_i_2_n_0
    );
shift_counter1_carry_i_3: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(8),
      I1 => shift_counter(9),
      O => shift_counter1_carry_i_3_n_0
    );
shift_counter1_carry_i_4: unisim.vcomponents.LUT2
    generic map(
      INIT => X"1"
    )
        port map (
      I0 => shift_counter(6),
      I1 => shift_counter(7),
      O => shift_counter1_carry_i_4_n_0
    );
shift_counter1_carry_i_5: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => shift_counter(5),
      I1 => shift_counter(4),
      O => shift_counter1_carry_i_5_n_0
    );
shift_counter1_carry_i_6: unisim.vcomponents.LUT2
    generic map(
      INIT => X"2"
    )
        port map (
      I0 => shift_counter(3),
      I1 => shift_counter(2),
      O => shift_counter1_carry_i_6_n_0
    );
\shift_counter_reg[0]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[0]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(0)
    );
\shift_counter_reg[0]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"04"
    )
        port map (
      I0 => shift_counter(0),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[0]_i_1_n_0\
    );
\shift_counter_reg[10]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[10]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(10)
    );
\shift_counter_reg[10]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(10),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[10]_i_1_n_0\
    );
\shift_counter_reg[11]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[11]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(11)
    );
\shift_counter_reg[11]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(11),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[11]_i_1_n_0\
    );
\shift_counter_reg[12]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[12]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(12)
    );
\shift_counter_reg[12]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(12),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[12]_i_1_n_0\
    );
\shift_counter_reg[13]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[13]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(13)
    );
\shift_counter_reg[13]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(13),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[13]_i_1_n_0\
    );
\shift_counter_reg[14]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[14]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(14)
    );
\shift_counter_reg[14]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(14),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[14]_i_1_n_0\
    );
\shift_counter_reg[15]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[15]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(15)
    );
\shift_counter_reg[15]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(15),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[15]_i_1_n_0\
    );
\shift_counter_reg[16]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[16]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(16)
    );
\shift_counter_reg[16]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(16),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[16]_i_1_n_0\
    );
\shift_counter_reg[17]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[17]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(17)
    );
\shift_counter_reg[17]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(17),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[17]_i_1_n_0\
    );
\shift_counter_reg[18]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[18]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(18)
    );
\shift_counter_reg[18]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(18),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[18]_i_1_n_0\
    );
\shift_counter_reg[19]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[19]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(19)
    );
\shift_counter_reg[19]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(19),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[19]_i_1_n_0\
    );
\shift_counter_reg[1]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[1]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(1)
    );
\shift_counter_reg[1]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(1),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[1]_i_1_n_0\
    );
\shift_counter_reg[20]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[20]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(20)
    );
\shift_counter_reg[20]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(20),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[20]_i_1_n_0\
    );
\shift_counter_reg[21]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[21]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(21)
    );
\shift_counter_reg[21]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(21),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[21]_i_1_n_0\
    );
\shift_counter_reg[22]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[22]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(22)
    );
\shift_counter_reg[22]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(22),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[22]_i_1_n_0\
    );
\shift_counter_reg[23]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[23]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(23)
    );
\shift_counter_reg[23]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(23),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[23]_i_1_n_0\
    );
\shift_counter_reg[24]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[24]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(24)
    );
\shift_counter_reg[24]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(24),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[24]_i_1_n_0\
    );
\shift_counter_reg[25]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[25]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(25)
    );
\shift_counter_reg[25]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(25),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[25]_i_1_n_0\
    );
\shift_counter_reg[26]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[26]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(26)
    );
\shift_counter_reg[26]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(26),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[26]_i_1_n_0\
    );
\shift_counter_reg[27]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[27]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(27)
    );
\shift_counter_reg[27]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(27),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[27]_i_1_n_0\
    );
\shift_counter_reg[28]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[28]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(28)
    );
\shift_counter_reg[28]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(28),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[28]_i_1_n_0\
    );
\shift_counter_reg[29]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[29]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(29)
    );
\shift_counter_reg[29]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(29),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[29]_i_1_n_0\
    );
\shift_counter_reg[2]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[2]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(2)
    );
\shift_counter_reg[2]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(2),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[2]_i_1_n_0\
    );
\shift_counter_reg[30]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[30]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(30)
    );
\shift_counter_reg[30]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(30),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[30]_i_1_n_0\
    );
\shift_counter_reg[31]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[31]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(31)
    );
\shift_counter_reg[31]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(31),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[31]_i_1_n_0\
    );
\shift_counter_reg[31]_i_2\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"A8"
    )
        port map (
      I0 => serial_clock_in,
      I1 => active,
      I2 => valid_in,
      O => \shift_counter__0\
    );
\shift_counter_reg[3]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[3]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(3)
    );
\shift_counter_reg[3]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(3),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[3]_i_1_n_0\
    );
\shift_counter_reg[4]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[4]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(4)
    );
\shift_counter_reg[4]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(4),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[4]_i_1_n_0\
    );
\shift_counter_reg[5]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[5]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(5)
    );
\shift_counter_reg[5]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(5),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[5]_i_1_n_0\
    );
\shift_counter_reg[6]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[6]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(6)
    );
\shift_counter_reg[6]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(6),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[6]_i_1_n_0\
    );
\shift_counter_reg[7]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[7]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(7)
    );
\shift_counter_reg[7]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(7),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[7]_i_1_n_0\
    );
\shift_counter_reg[8]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[8]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(8)
    );
\shift_counter_reg[8]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(8),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[8]_i_1_n_0\
    );
\shift_counter_reg[9]\: unisim.vcomponents.LDCE
    generic map(
      INIT => '0'
    )
        port map (
      CLR => serial_clock_out_reg_i_3_n_0,
      D => \shift_counter_reg[9]_i_1_n_0\,
      G => \shift_counter__0\,
      GE => '1',
      Q => shift_counter(9)
    );
\shift_counter_reg[9]_i_1\: unisim.vcomponents.LUT3
    generic map(
      INIT => X"08"
    )
        port map (
      I0 => shift_counter0(9),
      I1 => shift_counter1,
      I2 => valid_in,
      O => \shift_counter_reg[9]_i_1_n_0\
    );
end STRUCTURE;
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
  port (
    data_in : in STD_LOGIC_VECTOR ( 39 downto 0 );
    valid_in : in STD_LOGIC;
    resetn : in STD_LOGIC;
    serial_clock_in : in STD_LOGIC;
    serial_data_out : out STD_LOGIC;
    serial_clock_out : out STD_LOGIC;
    fq_ud_out : out STD_LOGIC
  );
  attribute NotValidForBitStream : boolean;
  attribute NotValidForBitStream of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix : entity is true;
  attribute CHECK_LICENSE_TYPE : string;
  attribute CHECK_LICENSE_TYPE of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix : entity is "design_1_AD9851_0_0,AD9851,{}";
  attribute downgradeipidentifiedwarnings : string;
  attribute downgradeipidentifiedwarnings of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix : entity is "yes";
  attribute ip_definition_source : string;
  attribute ip_definition_source of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix : entity is "module_ref";
  attribute x_core_info : string;
  attribute x_core_info of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix : entity is "AD9851,Vivado 2022.2";
end decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix;

architecture STRUCTURE of decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix is
  attribute x_interface_info : string;
  attribute x_interface_info of resetn : signal is "xilinx.com:signal:reset:1.0 resetn RST";
  attribute x_interface_parameter : string;
  attribute x_interface_parameter of resetn : signal is "XIL_INTERFACENAME resetn, POLARITY ACTIVE_LOW, INSERT_VIP 0";
begin
U0: entity work.decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_AD9851
     port map (
      data_in(39 downto 0) => data_in(39 downto 0),
      fq_ud_out => fq_ud_out,
      resetn => resetn,
      serial_clock_in => serial_clock_in,
      serial_clock_out => serial_clock_out,
      serial_data_out => serial_data_out,
      valid_in => valid_in
    );
end STRUCTURE;
