--Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
--Date        : Wed Sep 20 11:08:34 2023
--Host        : guido-Neptune-series-i9 running 64-bit Ubuntu 22.04.3 LTS
--Command     : generate_target ad9851gfsk_ip_v1_0_bfm_1_wrapper.bd
--Design      : ad9851gfsk_ip_v1_0_bfm_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity ad9851gfsk_ip_v1_0_bfm_1_wrapper is
  port (
    ACLK : in STD_LOGIC;
    ARESETN : in STD_LOGIC;
    data_out_0 : out STD_LOGIC_VECTOR ( 39 downto 0 );
    pwm_am_out_0 : out STD_LOGIC;
    read_data_out_0 : out STD_LOGIC
  );
end ad9851gfsk_ip_v1_0_bfm_1_wrapper;

architecture STRUCTURE of ad9851gfsk_ip_v1_0_bfm_1_wrapper is
  component ad9851gfsk_ip_v1_0_bfm_1 is
  port (
    ACLK : in STD_LOGIC;
    ARESETN : in STD_LOGIC;
    read_data_out_0 : out STD_LOGIC;
    data_out_0 : out STD_LOGIC_VECTOR ( 39 downto 0 );
    pwm_am_out_0 : out STD_LOGIC
  );
  end component ad9851gfsk_ip_v1_0_bfm_1;
begin
ad9851gfsk_ip_v1_0_bfm_1_i: component ad9851gfsk_ip_v1_0_bfm_1
     port map (
      ACLK => ACLK,
      ARESETN => ARESETN,
      data_out_0(39 downto 0) => data_out_0(39 downto 0),
      pwm_am_out_0 => pwm_am_out_0,
      read_data_out_0 => read_data_out_0
    );
end STRUCTURE;