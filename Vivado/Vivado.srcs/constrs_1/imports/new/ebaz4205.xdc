##
## @file        ebaz4205.xdc
## @brief       Xilinx Design Constraints for EBAZ4205
## @author      Keitetsu
## @date        2021/03/21
## @copyright   Copyright (c) 2021 Keitetsu
## @par         License
##              This software is released under the MIT License.
##

# Clock for Ethernet Transceiver
set_property IOSTANDARD LVCMOS33 [get_ports CLK25M]
set_property PACKAGE_PIN U18 [get_ports CLK25M]

# Ethernet Transceiver
set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_RX_CLK_0]
set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_TX_CLK_0]
set_property PACKAGE_PIN U14 [get_ports ENET0_GMII_RX_CLK_0]
set_property PACKAGE_PIN U15 [get_ports ENET0_GMII_TX_CLK_0]

#[Place 30-876] Port 'ENET0_GMII_TX_CLK_0'  is assigned to PACKAGE_PIN 'U15'  which can only be used as the N side of a differential clock input.
#Please use the following constraint(s) to pass this DRC check:
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets ENET0_GMII_TX_CLK_0_IBUF]

set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_rxd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[3]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[2]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[1]}]
set_property IOSTANDARD LVCMOS33 [get_ports {enet0_gmii_txd[0]}]
set_property IOSTANDARD LVCMOS33 [get_ports ENET0_GMII_RX_DV_0]
set_property IOSTANDARD LVCMOS33 [get_ports MDIO_ETHERNET_0_0_mdc]
set_property IOSTANDARD LVCMOS33 [get_ports MDIO_ETHERNET_0_0_mdio_io]
set_property PACKAGE_PIN Y17 [get_ports {enet0_gmii_rxd[3]}]
set_property PACKAGE_PIN V17 [get_ports {enet0_gmii_rxd[2]}]
set_property PACKAGE_PIN V16 [get_ports {enet0_gmii_rxd[1]}]
set_property PACKAGE_PIN Y16 [get_ports {enet0_gmii_rxd[0]}]
set_property PACKAGE_PIN W19 [get_ports {ENET0_GMII_TX_EN_0[0]}]
set_property PACKAGE_PIN Y19 [get_ports {enet0_gmii_txd[3]}]
set_property PACKAGE_PIN V18 [get_ports {enet0_gmii_txd[2]}]
set_property PACKAGE_PIN Y18 [get_ports {enet0_gmii_txd[1]}]
set_property PACKAGE_PIN W18 [get_ports {enet0_gmii_txd[0]}]
set_property PACKAGE_PIN W16 [get_ports ENET0_GMII_RX_DV_0]
set_property PACKAGE_PIN W15 [get_ports MDIO_ETHERNET_0_0_mdc]
set_property PACKAGE_PIN Y14 [get_ports MDIO_ETHERNET_0_0_mdio_io]

# Green LED
set_property IOSTANDARD LVCMOS33 [get_ports {LED_GREEN[0]}]
set_property PACKAGE_PIN W13 [get_ports {LED_GREEN[0]}]

# Red LED
#set_property IOSTANDARD LVCMOS33 [get_ports {LED_RED[0]}]
#set_property PACKAGE_PIN W14 [get_ports {LED_RED[0]}]



##MOD for LCDHaving extBoard
set_property -dict { PACKAGE_PIN A20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_0[2]}];
set_property -dict { PACKAGE_PIN F19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Clk_p_0   }]; 
set_property -dict { PACKAGE_PIN B19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_0[2]}];  
set_property -dict { PACKAGE_PIN B20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_0[1]}];  
set_property -dict { PACKAGE_PIN C20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_0[1]}]; 
set_property -dict { PACKAGE_PIN F20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Clk_n_0  }];  
set_property -dict { PACKAGE_PIN D20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_0[0]}]; 
set_property -dict { PACKAGE_PIN D18   IOSTANDARD LVCMOS33 } [get_ports { HDMI_HPD_0_tri_i[0]    }]; 
set_property -dict { PACKAGE_PIN H18   IOSTANDARD LVCMOS33 } [get_ports { HDMI_CEC_0 }]; 
set_property -dict { PACKAGE_PIN D19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_0[0]}];
#set_property -dict { PACKAGE_PIN H16   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SCL_0 }]; 
#set_property -dict { PACKAGE_PIN H17   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SDA_0 }]; 
#set_property -dict { PACKAGE_PIN K17   IOSTANDARD LVCMOS33 } [get_ports { AUDIO_L }]; 
#set_property -dict { PACKAGE_PIN E19   IOSTANDARD LVCMOS33 } [get_ports { AUDIO_R }]; 

##DATA2
#HDMI1
set_property -dict { PACKAGE_PIN J16   IOSTANDARD TMDS_33 } [get_ports { TMDS_Clk_p_1 }];
set_property -dict { PACKAGE_PIN H17   IOSTANDARD TMDS_33 } [get_ports { TMDS_Clk_n_1 }];
set_property -dict { PACKAGE_PIN G19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_1[2]}]; 
set_property -dict { PACKAGE_PIN G20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_1[2]}]; 
set_property -dict { PACKAGE_PIN J20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_1[1]}]; 
set_property -dict { PACKAGE_PIN H20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_1[1]}]; 
set_property -dict { PACKAGE_PIN L19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_1[0]}]; 
set_property -dict { PACKAGE_PIN L20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_1[0]}]; 
set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { HDMI_HPD_1_tri_i[0]    }]; 
set_property -dict { PACKAGE_PIN J19   IOSTANDARD LVCMOS33 } [get_ports { HDMI_CEC_1[0] }]; 
#set_property -dict { PACKAGE_PIN K19   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SCL_1 }]; 
#set_property -dict { PACKAGE_PIN K18   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SDA_1 }]; 

#HDMI2
#set_property -dict { PACKAGE_PIN M18   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_2[2]}]; 
#set_property -dict { PACKAGE_PIN M20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_2[1]}]; 

#DATA3
#HDMI2
#set_property -dict { PACKAGE_PIN N20   IOSTANDARD TMDS_33 } [get_ports { TMDS_Clk_p_2 }];
#set_property -dict { PACKAGE_PIN P20   IOSTANDARD TMDS_33 } [get_ports { TMDS_Clk_n_2 }];
#set_property -dict { PACKAGE_PIN M17   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_2[2]}]; 
##set_property -dict { PACKAGE_PIN M18   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_2[2]}]; 
#set_property -dict { PACKAGE_PIN M19   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_2[1]}]; 
##set_property -dict { PACKAGE_PIN M20   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_2[1]}]; 
#set_property -dict { PACKAGE_PIN N17   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_p_2[0]}]; 
#set_property -dict { PACKAGE_PIN P18   IOSTANDARD TMDS_33 } [get_ports {TMDS_Data_n_2[0]}]; 
#set_property -dict { PACKAGE_PIN R18   IOSTANDARD LVCMOS33 } [get_ports { HDMI_HPD_2_tri_i[0]    }]; 
#set_property -dict { PACKAGE_PIN R19   IOSTANDARD LVCMOS33 } [get_ports { HDMI_CEC_2[0] }]; 
#set_property -dict { PACKAGE_PIN T20   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SCL_2 }]; 
#set_property -dict { PACKAGE_PIN P19   IOSTANDARD LVCMOS33 } [get_ports { HDMI_SDA_2 }]; 
##buttons
#set_property -dict { PACKAGE_PIN U19   IOSTANDARD LVCMOS33 } [get_ports { PL_KEY[0] }];
#set_property -dict { PACKAGE_PIN V20   IOSTANDARD LVCMOS33 } [get_ports { PL_KEY[1] }];
#set_property -dict { PACKAGE_PIN T19   IOSTANDARD LVCMOS33 } [get_ports { PL_KEY[2] }];
#set_property -dict { PACKAGE_PIN U20   IOSTANDARD LVCMOS33 } [get_ports { PL_KEY[3] }]; 




#create_pblock pblock_AD9851
#add_cells_to_pblock [get_pblocks pblock_AD9851] [get_cells -quiet [list ebaz4205_i/AD9851]]
#resize_pblock [get_pblocks pblock_AD9851] -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y0}