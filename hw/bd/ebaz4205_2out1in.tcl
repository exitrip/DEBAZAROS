
################################################################
# This is a generated script based on design: ebaz4205
#
# Though there are limitations about the generated script,
# the main purpose of this utility is to make learning
# IP Integrator Tcl commands easier.
################################################################

namespace eval _tcl {
proc get_script_folder {} {
   set script_path [file normalize [info script]]
   set script_folder [file dirname $script_path]
   return $script_folder
}
}
variable script_folder
set script_folder [_tcl::get_script_folder]

################################################################
# Check if script is running in correct Vivado version.
################################################################
set scripts_vivado_version 2022.2
set current_vivado_version [version -short]

if { [string first $scripts_vivado_version $current_vivado_version] == -1 } {
   puts ""
   catch {common::send_gid_msg -ssname BD::TCL -id 2041 -severity "ERROR" "This script was generated using Vivado <$scripts_vivado_version> and is being run in <$current_vivado_version> of Vivado. Please run the script in Vivado <$scripts_vivado_version> then open the design in Vivado <$current_vivado_version>. Upgrade the design by running \"Tools => Report => Report IP Status...\", then run write_bd_tcl to create an updated script."}

   return 1
}

################################################################
# START
################################################################

# To test this script, run the following commands from Vivado Tcl console:
# source ebaz4205_script.tcl


# The design that will be created by this Tcl script contains the following 
# module references:
# dz_osc2, dz_regs, fsync_gen, hdmi_audio_regs, pl_io, div16_8_recip, div16_8_recip, hdmi_tx, div16_8_recip, div16_8_recip, hdmi_tx, hdmi_rx, DivideBy2N

# Please add the sources of those modules before sourcing this Tcl script.

# If there is no project opened, this script will create a
# project, but make sure you do not have an existing project
# <./myproj/project_1.xpr> in the current working folder.

set list_projs [get_projects -quiet]
if { $list_projs eq "" } {
   create_project project_1 myproj -part xc7z010clg400-1
}


# CHANGE DESIGN NAME HERE
variable design_name
set design_name ebaz4205

# If you do not already have an existing IP Integrator design open,
# you can create a design using the following command:
#    create_bd_design $design_name

# Creating design if needed
set errMsg ""
set nRet 0

set cur_design [current_bd_design -quiet]
set list_cells [get_bd_cells -quiet]

if { ${design_name} eq "" } {
   # USE CASES:
   #    1) Design_name not set

   set errMsg "Please set the variable <design_name> to a non-empty value."
   set nRet 1

} elseif { ${cur_design} ne "" && ${list_cells} eq "" } {
   # USE CASES:
   #    2): Current design opened AND is empty AND names same.
   #    3): Current design opened AND is empty AND names diff; design_name NOT in project.
   #    4): Current design opened AND is empty AND names diff; design_name exists in project.

   if { $cur_design ne $design_name } {
      common::send_gid_msg -ssname BD::TCL -id 2001 -severity "INFO" "Changing value of <design_name> from <$design_name> to <$cur_design> since current design is empty."
      set design_name [get_property NAME $cur_design]
   }
   common::send_gid_msg -ssname BD::TCL -id 2002 -severity "INFO" "Constructing design in IPI design <$cur_design>..."

} elseif { ${cur_design} ne "" && $list_cells ne "" && $cur_design eq $design_name } {
   # USE CASES:
   #    5) Current design opened AND has components AND same names.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 1
} elseif { [get_files -quiet ${design_name}.bd] ne "" } {
   # USE CASES: 
   #    6) Current opened design, has components, but diff names, design_name exists in project.
   #    7) No opened design, design_name exists in project.

   set errMsg "Design <$design_name> already exists in your project, please set the variable <design_name> to another value."
   set nRet 2

} else {
   # USE CASES:
   #    8) No opened design, design_name not in project.
   #    9) Current opened design, has components, but diff names, design_name not in project.

   common::send_gid_msg -ssname BD::TCL -id 2003 -severity "INFO" "Currently there is no design <$design_name> in project, so creating one..."

   create_bd_design $design_name

   common::send_gid_msg -ssname BD::TCL -id 2004 -severity "INFO" "Making design <$design_name> as current_bd_design."
   current_bd_design $design_name

}

  # Add USER_COMMENTS on $design_name
  set_property USER_COMMENTS.comment_0 "PS groups:
- Programmable System(CPU)
- Reset
- AXI control
- Ethernet" [get_bd_designs $design_name]

common::send_gid_msg -ssname BD::TCL -id 2005 -severity "INFO" "Currently the variable <design_name> is equal to \"$design_name\"."

if { $nRet != 0 } {
   catch {common::send_gid_msg -ssname BD::TCL -id 2006 -severity "ERROR" $errMsg}
   return $nRet
}

set bCheckIPsPassed 1
##################################################################
# CHECK IPs
##################################################################
set bCheckIPs 1
if { $bCheckIPs == 1 } {
   set list_check_ips "\ 
digilentinc.com:ip:axi_dynclk:1.2\
xilinx.com:ip:xlconstant:1.1\
xilinx.com:ip:xlconcat:2.1\
xilinx.com:ip:xlslice:1.0\
xilinx.com:ip:axi_vdma:6.3\
xilinx.com:ip:axis_subset_converter:1.1\
xilinx.com:ip:blk_mem_gen:8.4\
xilinx.com:ip:c_addsub:12.0\
xilinx.com:ip:c_counter_binary:12.0\
xilinx.com:ip:v_axi4s_vid_out:4.0\
xilinx.com:ip:v_tc:6.2\
digilentinc.com:ip:dvi2rgb:2.0\
xilinx.com:ip:v_vid_in_axi4s:5.0\
xilinx.com:ip:proc_sys_reset:5.0\
xilinx.com:ip:processing_system7:5.5\
xilinx.com:ip:mult_gen:12.0\
user.org:user:mixer:2.0\
xilinx.com:ip:xbip_multadd:3.0\
"

   set list_ips_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2011 -severity "INFO" "Checking if the following IPs exist in the project's IP catalog: $list_check_ips ."

   foreach ip_vlnv $list_check_ips {
      set ip_obj [get_ipdefs -all $ip_vlnv]
      if { $ip_obj eq "" } {
         lappend list_ips_missing $ip_vlnv
      }
   }

   if { $list_ips_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2012 -severity "ERROR" "The following IPs are not found in the IP Catalog:\n  $list_ips_missing\n\nResolution: Please add the repository containing the IP(s) to the project." }
      set bCheckIPsPassed 0
   }

}

##################################################################
# CHECK Modules
##################################################################
set bCheckModules 1
if { $bCheckModules == 1 } {
   set list_check_mods "\ 
dz_osc2\
dz_regs\
fsync_gen\
hdmi_audio_regs\
pl_io\
div16_8_recip\
div16_8_recip\
hdmi_tx\
div16_8_recip\
div16_8_recip\
hdmi_tx\
hdmi_rx\
DivideBy2N\
"

   set list_mods_missing ""
   common::send_gid_msg -ssname BD::TCL -id 2020 -severity "INFO" "Checking if the following modules exist in the project's sources: $list_check_mods ."

   foreach mod_vlnv $list_check_mods {
      if { [can_resolve_reference $mod_vlnv] == 0 } {
         lappend list_mods_missing $mod_vlnv
      }
   }

   if { $list_mods_missing ne "" } {
      catch {common::send_gid_msg -ssname BD::TCL -id 2021 -severity "ERROR" "The following module(s) are not found in the project: $list_mods_missing" }
      common::send_gid_msg -ssname BD::TCL -id 2022 -severity "INFO" "Please add source files for the missing module(s) above."
      set bCheckIPsPassed 0
   }
}

if { $bCheckIPsPassed != 1 } {
  common::send_gid_msg -ssname BD::TCL -id 2023 -severity "WARNING" "Will not continue with creation of design due to the error(s) above."
  return 3
}

##################################################################
# DESIGN PROCs
##################################################################


# Hierarchical cell: colorGainMatrix
proc create_hier_cell_colorGainMatrix { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_colorGainMatrix() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 23 -to 0 Din
  create_bd_pin -dir O -from 23 -to 0 dout
  create_bd_pin -dir I -from 23 -to 0 g_bb
  create_bd_pin -dir I -from 23 -to 0 g_bg
  create_bd_pin -dir I -from 23 -to 0 g_br
  create_bd_pin -dir I -from 23 -to 0 g_gb
  create_bd_pin -dir I -from 23 -to 0 g_gg
  create_bd_pin -dir I -from 23 -to 0 g_gr
  create_bd_pin -dir I -from 23 -to 0 g_rb
  create_bd_pin -dir I -from 23 -to 0 g_rg
  create_bd_pin -dir I -from 23 -to 0 g_rr

  # Create instance: b_xlslice_0, and set properties
  set b_xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 b_xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $b_xlslice_0


  # Create instance: g_xlslice_0, and set properties
  set g_xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 g_xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $g_xlslice_0


  # Create instance: r_xlslice_0, and set properties
  set r_xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 r_xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $r_xlslice_0


  # Create instance: xbip_multadd_0, and set properties
  set xbip_multadd_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_0 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {1} \
    CONFIG.c_c_width {16} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
    CONFIG.c_use_pcin {false} \
  ] $xbip_multadd_0


  # Create instance: xbip_multadd_1, and set properties
  set xbip_multadd_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_1 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
  ] $xbip_multadd_1


  # Create instance: xbip_multadd_2, and set properties
  set xbip_multadd_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_2 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {16} \
  ] $xbip_multadd_2


  # Create instance: xbip_multadd_3, and set properties
  set xbip_multadd_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_3 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {1} \
    CONFIG.c_c_width {16} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
  ] $xbip_multadd_3


  # Create instance: xbip_multadd_4, and set properties
  set xbip_multadd_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_4 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
  ] $xbip_multadd_4


  # Create instance: xbip_multadd_5, and set properties
  set xbip_multadd_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_5 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {16} \
  ] $xbip_multadd_5


  # Create instance: xbip_multadd_6, and set properties
  set xbip_multadd_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_6 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {1} \
    CONFIG.c_c_width {16} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
  ] $xbip_multadd_6


  # Create instance: xbip_multadd_7, and set properties
  set xbip_multadd_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_7 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {0} \
  ] $xbip_multadd_7


  # Create instance: xbip_multadd_8, and set properties
  set xbip_multadd_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xbip_multadd:3.0 xbip_multadd_8 ]
  set_property -dict [list \
    CONFIG.c_a_type {1} \
    CONFIG.c_a_width {8} \
    CONFIG.c_ab_latency {0} \
    CONFIG.c_b_type {1} \
    CONFIG.c_b_width {24} \
    CONFIG.c_c_latency {0} \
    CONFIG.c_c_type {0} \
    CONFIG.c_c_width {24} \
    CONFIG.c_out_high {23} \
    CONFIG.c_out_low {16} \
  ] $xbip_multadd_8


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_0


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {16} \
  ] $xlconstant_0


  # Create port connections
  connect_bd_net -net g_bb_1 [get_bd_pins g_bb] [get_bd_pins xbip_multadd_8/B]
  connect_bd_net -net g_bg_1 [get_bd_pins g_bg] [get_bd_pins xbip_multadd_5/B]
  connect_bd_net -net g_br_1 [get_bd_pins g_br] [get_bd_pins xbip_multadd_2/B]
  connect_bd_net -net g_gb_1 [get_bd_pins g_gb] [get_bd_pins xbip_multadd_7/B]
  connect_bd_net -net g_gg_1 [get_bd_pins g_gg] [get_bd_pins xbip_multadd_4/B]
  connect_bd_net -net g_gr_1 [get_bd_pins g_gr] [get_bd_pins xbip_multadd_1/B]
  connect_bd_net -net g_rb_1 [get_bd_pins g_rb] [get_bd_pins xbip_multadd_6/B]
  connect_bd_net -net g_rg_1 [get_bd_pins g_rg] [get_bd_pins xbip_multadd_3/B]
  connect_bd_net -net g_rr_1 [get_bd_pins g_rr] [get_bd_pins xbip_multadd_0/B]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data [get_bd_pins Din] [get_bd_pins b_xlslice_0/Din] [get_bd_pins g_xlslice_0/Din] [get_bd_pins r_xlslice_0/Din]
  connect_bd_net -net xbip_multadd_0_P [get_bd_pins xbip_multadd_0/P] [get_bd_pins xbip_multadd_1/C]
  connect_bd_net -net xbip_multadd_0_P1 [get_bd_pins xbip_multadd_3/P] [get_bd_pins xbip_multadd_4/C]
  connect_bd_net -net xbip_multadd_0_P2 [get_bd_pins xbip_multadd_6/P] [get_bd_pins xbip_multadd_7/C]
  connect_bd_net -net xbip_multadd_1_P [get_bd_pins xbip_multadd_1/P] [get_bd_pins xbip_multadd_2/C]
  connect_bd_net -net xbip_multadd_1_P1 [get_bd_pins xbip_multadd_4/P] [get_bd_pins xbip_multadd_5/C]
  connect_bd_net -net xbip_multadd_1_P2 [get_bd_pins xbip_multadd_7/P] [get_bd_pins xbip_multadd_8/C]
  connect_bd_net -net xbip_multadd_2_P [get_bd_pins xbip_multadd_2/P] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net xbip_multadd_5_P [get_bd_pins xbip_multadd_5/P] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net xbip_multadd_8_P [get_bd_pins xbip_multadd_8/P] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins dout] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins xbip_multadd_0/C] [get_bd_pins xbip_multadd_3/C] [get_bd_pins xbip_multadd_6/C] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins b_xlslice_0/Dout] [get_bd_pins xbip_multadd_2/A] [get_bd_pins xbip_multadd_5/A] [get_bd_pins xbip_multadd_8/A]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins g_xlslice_0/Dout] [get_bd_pins xbip_multadd_1/A] [get_bd_pins xbip_multadd_4/A] [get_bd_pins xbip_multadd_7/A]
  connect_bd_net -net xlslice_4_Dout [get_bd_pins r_xlslice_0/Dout] [get_bd_pins xbip_multadd_0/A] [get_bd_pins xbip_multadd_3/A] [get_bd_pins xbip_multadd_6/A]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: colorGainOscSin
proc create_hier_cell_colorGainOscSin { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_colorGainOscSin() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 23 -to 0 Din0
  create_bd_pin -dir I -from 15 -to 0 Din1
  create_bd_pin -dir O -from 23 -to 0 dout0
  create_bd_pin -dir I pixClk_in

  # Create instance: mult_gen_3, and set properties
  set mult_gen_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_3 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_3


  # Create instance: mult_gen_4, and set properties
  set mult_gen_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_4 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_4


  # Create instance: mult_gen_5, and set properties
  set mult_gen_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_5 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_5


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_1


  # Create instance: xlslice_7, and set properties
  set xlslice_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_7 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_7


  # Create instance: xlslice_9, and set properties
  set xlslice_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_9 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_9


  # Create instance: xlslice_11, and set properties
  set xlslice_11 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_11 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_11


  # Create port connections
  connect_bd_net -net Din1_1 [get_bd_pins Din1] [get_bd_pins mult_gen_3/A] [get_bd_pins mult_gen_4/A] [get_bd_pins mult_gen_5/A]
  connect_bd_net -net axi_gain_1_gpio2_io_o [get_bd_pins Din0] [get_bd_pins xlslice_11/Din] [get_bd_pins xlslice_7/Din] [get_bd_pins xlslice_9/Din]
  connect_bd_net -net mult_gen_0_P1 [get_bd_pins mult_gen_3/P] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net mult_gen_1_P1 [get_bd_pins mult_gen_4/P] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net mult_gen_2_P1 [get_bd_pins mult_gen_5/P] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net pixClk_in_1 [get_bd_pins pixClk_in] [get_bd_pins mult_gen_3/CLK] [get_bd_pins mult_gen_4/CLK] [get_bd_pins mult_gen_5/CLK]
  connect_bd_net -net xlconcat_0_dout1 [get_bd_pins dout0] [get_bd_pins xlconcat_1/dout]
  connect_bd_net -net xlslice_1_Dout1 [get_bd_pins mult_gen_3/B] [get_bd_pins xlslice_7/Dout]
  connect_bd_net -net xlslice_3_Dout1 [get_bd_pins mult_gen_4/B] [get_bd_pins xlslice_9/Dout]
  connect_bd_net -net xlslice_5_Dout1 [get_bd_pins mult_gen_5/B] [get_bd_pins xlslice_11/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: colorGainOscPhase
proc create_hier_cell_colorGainOscPhase { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_colorGainOscPhase() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 23 -to 0 Din0
  create_bd_pin -dir I -from 15 -to 0 Din1
  create_bd_pin -dir O -from 23 -to 0 dout0
  create_bd_pin -dir I pixClk_in

  # Create instance: mult_gen_3, and set properties
  set mult_gen_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_3 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_3


  # Create instance: mult_gen_4, and set properties
  set mult_gen_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_4 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_4


  # Create instance: mult_gen_5, and set properties
  set mult_gen_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_5 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Signed} \
    CONFIG.PortAWidth {16} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_5


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_1


  # Create instance: xlslice_7, and set properties
  set xlslice_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_7 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_7


  # Create instance: xlslice_9, and set properties
  set xlslice_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_9 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_9


  # Create instance: xlslice_11, and set properties
  set xlslice_11 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_11 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_11


  # Create port connections
  connect_bd_net -net Din1_1 [get_bd_pins Din1] [get_bd_pins mult_gen_3/A] [get_bd_pins mult_gen_4/A] [get_bd_pins mult_gen_5/A]
  connect_bd_net -net axi_gain_1_gpio2_io_o [get_bd_pins Din0] [get_bd_pins xlslice_11/Din] [get_bd_pins xlslice_7/Din] [get_bd_pins xlslice_9/Din]
  connect_bd_net -net mult_gen_0_P1 [get_bd_pins mult_gen_3/P] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net mult_gen_1_P1 [get_bd_pins mult_gen_4/P] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net mult_gen_2_P1 [get_bd_pins mult_gen_5/P] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net pixClk_in_1 [get_bd_pins pixClk_in] [get_bd_pins mult_gen_3/CLK] [get_bd_pins mult_gen_4/CLK] [get_bd_pins mult_gen_5/CLK]
  connect_bd_net -net xlconcat_0_dout1 [get_bd_pins dout0] [get_bd_pins xlconcat_1/dout]
  connect_bd_net -net xlslice_1_Dout1 [get_bd_pins mult_gen_3/B] [get_bd_pins xlslice_7/Dout]
  connect_bd_net -net xlslice_3_Dout1 [get_bd_pins mult_gen_4/B] [get_bd_pins xlslice_9/Dout]
  connect_bd_net -net xlslice_5_Dout1 [get_bd_pins mult_gen_5/B] [get_bd_pins xlslice_11/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: colorGainFeedback1
proc create_hier_cell_colorGainFeedback1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_colorGainFeedback1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 23 -to 0 Din
  create_bd_pin -dir I -from 23 -to 0 Din0
  create_bd_pin -dir I -from 23 -to 0 Din1
  create_bd_pin -dir I -from 23 -to 0 Din2
  create_bd_pin -dir O -from 23 -to 0 dout0
  create_bd_pin -dir O -from 23 -to 0 dout1
  create_bd_pin -dir I pixClk_in

  # Create instance: mult_gen_0, and set properties
  set mult_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_0 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_0


  # Create instance: mult_gen_1, and set properties
  set mult_gen_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_1 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_1


  # Create instance: mult_gen_2, and set properties
  set mult_gen_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_2 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_2


  # Create instance: mult_gen_3, and set properties
  set mult_gen_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_3 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_3


  # Create instance: mult_gen_4, and set properties
  set mult_gen_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_4 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_4


  # Create instance: mult_gen_5, and set properties
  set mult_gen_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_5 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_5


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_0


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_1


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_2


  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_3


  # Create instance: xlslice_4, and set properties
  set xlslice_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_4 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_4


  # Create instance: xlslice_5, and set properties
  set xlslice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_5 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_5


  # Create instance: xlslice_6, and set properties
  set xlslice_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_6 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_6


  # Create instance: xlslice_7, and set properties
  set xlslice_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_7 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_7


  # Create instance: xlslice_8, and set properties
  set xlslice_8 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_8 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_8


  # Create instance: xlslice_9, and set properties
  set xlslice_9 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_9 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_9


  # Create instance: xlslice_10, and set properties
  set xlslice_10 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_10 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_10


  # Create instance: xlslice_11, and set properties
  set xlslice_11 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_11 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_11


  # Create port connections
  connect_bd_net -net Net [get_bd_pins pixClk_in] [get_bd_pins mult_gen_0/CLK] [get_bd_pins mult_gen_1/CLK] [get_bd_pins mult_gen_2/CLK] [get_bd_pins mult_gen_3/CLK] [get_bd_pins mult_gen_4/CLK] [get_bd_pins mult_gen_5/CLK]
  connect_bd_net -net axi_gain_1_gpio2_io_o [get_bd_pins Din] [get_bd_pins xlslice_11/Din] [get_bd_pins xlslice_7/Din] [get_bd_pins xlslice_9/Din]
  connect_bd_net -net axi_gain_1_gpio_io_o [get_bd_pins Din2] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_3/Din] [get_bd_pins xlslice_5/Din]
  connect_bd_net -net mult_gen_0_P [get_bd_pins mult_gen_0/P] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net mult_gen_0_P1 [get_bd_pins mult_gen_3/P] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net mult_gen_1_P [get_bd_pins mult_gen_1/P] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net mult_gen_1_P1 [get_bd_pins mult_gen_4/P] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net mult_gen_2_P [get_bd_pins mult_gen_2/P] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net mult_gen_2_P1 [get_bd_pins mult_gen_5/P] [get_bd_pins xlconcat_1/In2]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data [get_bd_pins Din0] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_2/Din] [get_bd_pins xlslice_4/Din]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data1 [get_bd_pins Din1] [get_bd_pins xlslice_10/Din] [get_bd_pins xlslice_6/Din] [get_bd_pins xlslice_8/Din]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins dout0] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconcat_0_dout1 [get_bd_pins dout1] [get_bd_pins xlconcat_1/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins mult_gen_0/A] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_0_Dout1 [get_bd_pins mult_gen_3/A] [get_bd_pins xlslice_6/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins mult_gen_0/B] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_1_Dout1 [get_bd_pins mult_gen_3/B] [get_bd_pins xlslice_7/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins mult_gen_1/A] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_2_Dout1 [get_bd_pins mult_gen_4/A] [get_bd_pins xlslice_8/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins mult_gen_1/B] [get_bd_pins xlslice_3/Dout]
  connect_bd_net -net xlslice_3_Dout1 [get_bd_pins mult_gen_4/B] [get_bd_pins xlslice_9/Dout]
  connect_bd_net -net xlslice_4_Dout [get_bd_pins mult_gen_2/A] [get_bd_pins xlslice_4/Dout]
  connect_bd_net -net xlslice_4_Dout1 [get_bd_pins mult_gen_5/A] [get_bd_pins xlslice_10/Dout]
  connect_bd_net -net xlslice_5_Dout [get_bd_pins mult_gen_2/B] [get_bd_pins xlslice_5/Dout]
  connect_bd_net -net xlslice_5_Dout1 [get_bd_pins mult_gen_5/B] [get_bd_pins xlslice_11/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: mixerMatrix
proc create_hier_cell_mixerMatrix { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_mixerMatrix() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE_MIXER_0


  # Create pins
  create_bd_pin -dir I -type clk PixelClk
  create_bd_pin -dir I -from 23 -to 0 din0
  create_bd_pin -dir I -from 15 -to 0 din1
  create_bd_pin -dir I -from 23 -to 0 din3
  create_bd_pin -dir I -from 15 -to 0 din4
  create_bd_pin -dir O -from 23 -to 0 dout
  create_bd_pin -dir I -from 23 -to 0 pixIn0
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn

  # Create instance: colorGainMatrix
  create_hier_cell_colorGainMatrix $hier_obj colorGainMatrix

  # Create instance: mixer_0, and set properties
  set mixer_0 [ create_bd_cell -type ip -vlnv user.org:user:mixer:2.0 mixer_0 ]
  set_property -dict [list \
    CONFIG.IN_NUM {8} \
    CONFIG.IN_WIDTH {16} \
    CONFIG.OUT_WIDTH {24} \
  ] $mixer_0


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_2


  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_3


  # Create instance: xlslice_5, and set properties
  set xlslice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_5 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_5


  # Create instance: xlslice_6, and set properties
  set xlslice_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_6 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
  ] $xlslice_6


  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins S_AXI_LITE_MIXER_0] [get_bd_intf_pins mixer_0/S00_AXI]

  # Create port connections
  connect_bd_net -net Din_1 [get_bd_pins pixIn0] [get_bd_pins colorGainMatrix/Din] [get_bd_pins mixer_0/vid_in]
  connect_bd_net -net PixelClk_1 [get_bd_pins PixelClk] [get_bd_pins mixer_0/pix_clk]
  connect_bd_net -net colorGainMatrix_dout [get_bd_pins colorGainMatrix/dout] [get_bd_pins mixer_0/bg_in]
  connect_bd_net -net din0_1 [get_bd_pins din0] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_2/Din]
  connect_bd_net -net din1_1 [get_bd_pins din1] [get_bd_pins mixer_0/din3]
  connect_bd_net -net din3_1 [get_bd_pins din3] [get_bd_pins xlslice_3/Din] [get_bd_pins xlslice_5/Din] [get_bd_pins xlslice_6/Din]
  connect_bd_net -net din4_1 [get_bd_pins din4] [get_bd_pins mixer_0/din4]
  connect_bd_net -net g_br_1 [get_bd_pins colorGainMatrix/g_br] [get_bd_pins mixer_0/dout1]
  connect_bd_net -net mixer_0_dout0 [get_bd_pins colorGainMatrix/g_rr] [get_bd_pins mixer_0/dout0]
  connect_bd_net -net mixer_0_dout2 [get_bd_pins colorGainMatrix/g_gr] [get_bd_pins mixer_0/dout2]
  connect_bd_net -net mixer_0_dout3 [get_bd_pins colorGainMatrix/g_rg] [get_bd_pins mixer_0/dout3]
  connect_bd_net -net mixer_0_dout4 [get_bd_pins colorGainMatrix/g_gg] [get_bd_pins mixer_0/dout4]
  connect_bd_net -net mixer_0_dout5 [get_bd_pins colorGainMatrix/g_bg] [get_bd_pins mixer_0/dout5]
  connect_bd_net -net mixer_0_dout6 [get_bd_pins colorGainMatrix/g_rb] [get_bd_pins mixer_0/dout6]
  connect_bd_net -net mixer_0_dout7 [get_bd_pins colorGainMatrix/g_gb] [get_bd_pins mixer_0/dout7]
  connect_bd_net -net mixer_0_dout8 [get_bd_pins colorGainMatrix/g_bb] [get_bd_pins mixer_0/dout8]
  connect_bd_net -net mixer_0_pix_out [get_bd_pins dout] [get_bd_pins mixer_0/pix_out]
  connect_bd_net -net s_axi_aclk_1 [get_bd_pins s_axi_aclk] [get_bd_pins mixer_0/s00_axi_aclk]
  connect_bd_net -net s_axi_aresetn_1 [get_bd_pins s_axi_aresetn] [get_bd_pins mixer_0/s00_axi_aresetn]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins mixer_0/din0] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins mixer_0/din1] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins mixer_0/din2] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins mixer_0/din5] [get_bd_pins xlslice_3/Dout]
  connect_bd_net -net xlslice_5_Dout [get_bd_pins mixer_0/din6] [get_bd_pins xlslice_5/Dout]
  connect_bd_net -net xlslice_6_Dout [get_bd_pins mixer_0/din7] [get_bd_pins xlslice_6/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: colorGainMain
proc create_hier_cell_colorGainMain { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_colorGainMain() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins

  # Create pins
  create_bd_pin -dir I -from 23 -to 0 Din
  create_bd_pin -dir I -from 23 -to 0 Din1
  create_bd_pin -dir O -from 23 -to 0 dout
  create_bd_pin -dir I pixClk_in

  # Create instance: mult_gen_0, and set properties
  set mult_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_0 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_0


  # Create instance: mult_gen_1, and set properties
  set mult_gen_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_1 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_1


  # Create instance: mult_gen_2, and set properties
  set mult_gen_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:mult_gen:12.0 mult_gen_2 ]
  set_property -dict [list \
    CONFIG.MultType {Parallel_Multiplier} \
    CONFIG.Multiplier_Construction {Use_Mults} \
    CONFIG.OutputWidthLow {8} \
    CONFIG.PipeStages {1} \
    CONFIG.PortAType {Unsigned} \
    CONFIG.PortAWidth {8} \
    CONFIG.PortBType {Unsigned} \
    CONFIG.PortBWidth {8} \
    CONFIG.Use_Custom_Output_Width {true} \
  ] $mult_gen_2


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.IN1_WIDTH {8} \
    CONFIG.IN2_WIDTH {8} \
    CONFIG.NUM_PORTS {3} \
  ] $xlconcat_0


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {7} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_2


  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {8} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_3


  # Create instance: xlslice_4, and set properties
  set xlslice_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_4 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_4


  # Create instance: xlslice_5, and set properties
  set xlslice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_5 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {16} \
    CONFIG.DIN_WIDTH {24} \
    CONFIG.DOUT_WIDTH {8} \
  ] $xlslice_5


  # Create port connections
  connect_bd_net -net axi_gain_1_gpio_io_o [get_bd_pins Din1] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_3/Din] [get_bd_pins xlslice_5/Din]
  connect_bd_net -net mult_gen_0_P [get_bd_pins mult_gen_0/P] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net mult_gen_1_P [get_bd_pins mult_gen_1/P] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net mult_gen_2_P [get_bd_pins mult_gen_2/P] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net pixClk_in_1 [get_bd_pins pixClk_in] [get_bd_pins mult_gen_0/CLK] [get_bd_pins mult_gen_1/CLK] [get_bd_pins mult_gen_2/CLK]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data [get_bd_pins Din] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_2/Din] [get_bd_pins xlslice_4/Din]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins dout] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins mult_gen_0/A] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins mult_gen_0/B] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins mult_gen_1/A] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins mult_gen_1/B] [get_bd_pins xlslice_3/Dout]
  connect_bd_net -net xlslice_4_Dout [get_bd_pins mult_gen_2/A] [get_bd_pins xlslice_4/Dout]
  connect_bd_net -net xlslice_5_Dout [get_bd_pins mult_gen_2/B] [get_bd_pins xlslice_5/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: PS
proc create_hier_cell_PS { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_PS() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR

  create_bd_intf_pin -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 MDIO_ETHERNET_0_0

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M_AXI_GP0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_HP0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_HP1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_HP2


  # Create pins
  create_bd_pin -dir O -from 0 -to 0 -type rst ARESETN
  create_bd_pin -dir O -type clk CLK_25M
  create_bd_pin -dir I -type clk ENET0_GMII_RX_CLK_0
  create_bd_pin -dir I ENET0_GMII_RX_DV_0
  create_bd_pin -dir I -type clk ENET0_GMII_TX_CLK_0
  create_bd_pin -dir O -from 0 -to 0 ENET0_GMII_TX_EN_0
  create_bd_pin -dir O -type clk FCLK_CLK0_100M
  create_bd_pin -dir O -type clk FCLK_CLK0_200M
  create_bd_pin -dir O -type clk FCLK_CLK2_140M
  create_bd_pin -dir I I2C0_SCL_I
  create_bd_pin -dir O I2C0_SCL_O
  create_bd_pin -dir O I2C0_SCL_T
  create_bd_pin -dir I I2C0_SDA_I
  create_bd_pin -dir O I2C0_SDA_O
  create_bd_pin -dir O I2C0_SDA_T
  create_bd_pin -dir I -from 8 -to 0 -type intr IRQ_F2P
  create_bd_pin -dir I SPI0_MISO_I
  create_bd_pin -dir I SPI0_MOSI_I
  create_bd_pin -dir O SPI0_MOSI_O
  create_bd_pin -dir O SPI0_MOSI_T
  create_bd_pin -dir I SPI0_SCLK_I
  create_bd_pin -dir O SPI0_SCLK_O
  create_bd_pin -dir O SPI0_SCLK_T
  create_bd_pin -dir O SPI0_SS1_O
  create_bd_pin -dir I SPI0_SS_I
  create_bd_pin -dir O SPI0_SS_O
  create_bd_pin -dir O SPI0_SS_T
  create_bd_pin -dir I UART0_RX
  create_bd_pin -dir O UART0_TX
  create_bd_pin -dir I -from 3 -to 0 enet0_gmii_rxd
  create_bd_pin -dir O -from 3 -to 0 enet0_gmii_txd
  create_bd_pin -dir O -from 0 -to 0 -type rst peripheral_aresetn1

  # Create instance: DivideBy4_25MHz, and set properties
  set block_name DivideBy2N
  set block_cell_name DivideBy4_25MHz
  if { [catch {set DivideBy4_25MHz [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $DivideBy4_25MHz eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
    set_property -dict [list \
    CONFIG.N {2} \
    CONFIG.WIDTH {2} \
  ] $DivideBy4_25MHz


  # Create instance: proc_sys_reset_0_100M, and set properties
  set proc_sys_reset_0_100M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 proc_sys_reset_0_100M ]

  # Create instance: processing_system7_0, and set properties
  set processing_system7_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:processing_system7:5.5 processing_system7_0 ]
  set_property -dict [list \
    CONFIG.PCW_ACT_APU_PERIPHERAL_FREQMHZ {666.666687} \
    CONFIG.PCW_ACT_CAN0_PERIPHERAL_FREQMHZ {23.8095} \
    CONFIG.PCW_ACT_CAN1_PERIPHERAL_FREQMHZ {23.8095} \
    CONFIG.PCW_ACT_CAN_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_DCI_PERIPHERAL_FREQMHZ {10.158730} \
    CONFIG.PCW_ACT_ENET0_PERIPHERAL_FREQMHZ {25.000000} \
    CONFIG.PCW_ACT_ENET1_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_FPGA0_PERIPHERAL_FREQMHZ {100.000000} \
    CONFIG.PCW_ACT_FPGA1_PERIPHERAL_FREQMHZ {64.000000} \
    CONFIG.PCW_ACT_FPGA2_PERIPHERAL_FREQMHZ {145.454544} \
    CONFIG.PCW_ACT_FPGA3_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_I2C_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_ACT_PCAP_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_QSPI_PERIPHERAL_FREQMHZ {10.000000} \
    CONFIG.PCW_ACT_SDIO_PERIPHERAL_FREQMHZ {25.396826} \
    CONFIG.PCW_ACT_SMC_PERIPHERAL_FREQMHZ {100.000000} \
    CONFIG.PCW_ACT_SPI_PERIPHERAL_FREQMHZ {160.000000} \
    CONFIG.PCW_ACT_TPIU_PERIPHERAL_FREQMHZ {200.000000} \
    CONFIG.PCW_ACT_TTC0_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC0_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK0_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK1_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC1_CLK2_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_ACT_TTC_PERIPHERAL_FREQMHZ {50} \
    CONFIG.PCW_ACT_UART_PERIPHERAL_FREQMHZ {100.000000} \
    CONFIG.PCW_ACT_USB0_PERIPHERAL_FREQMHZ {60} \
    CONFIG.PCW_ACT_USB1_PERIPHERAL_FREQMHZ {60} \
    CONFIG.PCW_ACT_WDT_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_APU_CLK_RATIO_ENABLE {6:2:1} \
    CONFIG.PCW_APU_PERIPHERAL_FREQMHZ {666.666666} \
    CONFIG.PCW_CAN0_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_CAN0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_CAN1_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_CAN1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_CAN_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_CAN_PERIPHERAL_VALID {0} \
    CONFIG.PCW_CLK0_FREQ {100000000} \
    CONFIG.PCW_CLK1_FREQ {64000000} \
    CONFIG.PCW_CLK2_FREQ {145454544} \
    CONFIG.PCW_CLK3_FREQ {200000000} \
    CONFIG.PCW_CORE0_FIQ_INTR {0} \
    CONFIG.PCW_CORE0_IRQ_INTR {0} \
    CONFIG.PCW_CORE1_FIQ_INTR {0} \
    CONFIG.PCW_CORE1_IRQ_INTR {0} \
    CONFIG.PCW_CPU_CPU_6X4X_MAX_RANGE {667} \
    CONFIG.PCW_CPU_PERIPHERAL_CLKSRC {ARM PLL} \
    CONFIG.PCW_CRYSTAL_PERIPHERAL_FREQMHZ {33.333333} \
    CONFIG.PCW_DCI_PERIPHERAL_CLKSRC {DDR PLL} \
    CONFIG.PCW_DCI_PERIPHERAL_FREQMHZ {10.159} \
    CONFIG.PCW_DDR_PERIPHERAL_CLKSRC {DDR PLL} \
    CONFIG.PCW_DDR_RAM_BASEADDR {0x00100000} \
    CONFIG.PCW_DDR_RAM_HIGHADDR {0x0FFFFFFF} \
    CONFIG.PCW_DM_WIDTH {4} \
    CONFIG.PCW_DQS_WIDTH {4} \
    CONFIG.PCW_DQ_WIDTH {32} \
    CONFIG.PCW_ENET0_BASEADDR {0xE000B000} \
    CONFIG.PCW_ENET0_ENET0_IO {EMIO} \
    CONFIG.PCW_ENET0_GRP_MDIO_ENABLE {1} \
    CONFIG.PCW_ENET0_GRP_MDIO_IO {EMIO} \
    CONFIG.PCW_ENET0_HIGHADDR {0xE000BFFF} \
    CONFIG.PCW_ENET0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_ENET0_PERIPHERAL_FREQMHZ {100 Mbps} \
    CONFIG.PCW_ENET0_RESET_ENABLE {0} \
    CONFIG.PCW_ENET1_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_ENET1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_ENET_RESET_ENABLE {1} \
    CONFIG.PCW_ENET_RESET_POLARITY {Active Low} \
    CONFIG.PCW_ENET_RESET_SELECT {Share reset pin} \
    CONFIG.PCW_EN_4K_TIMER {0} \
    CONFIG.PCW_EN_CAN0 {0} \
    CONFIG.PCW_EN_CAN1 {0} \
    CONFIG.PCW_EN_CLK0_PORT {1} \
    CONFIG.PCW_EN_CLK1_PORT {1} \
    CONFIG.PCW_EN_CLK2_PORT {1} \
    CONFIG.PCW_EN_CLK3_PORT {1} \
    CONFIG.PCW_EN_CLKTRIG0_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG1_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG2_PORT {0} \
    CONFIG.PCW_EN_CLKTRIG3_PORT {0} \
    CONFIG.PCW_EN_DDR {1} \
    CONFIG.PCW_EN_EMIO_CAN0 {0} \
    CONFIG.PCW_EN_EMIO_CAN1 {0} \
    CONFIG.PCW_EN_EMIO_CD_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_CD_SDIO1 {0} \
    CONFIG.PCW_EN_EMIO_ENET0 {1} \
    CONFIG.PCW_EN_EMIO_ENET1 {0} \
    CONFIG.PCW_EN_EMIO_GPIO {1} \
    CONFIG.PCW_EN_EMIO_I2C0 {1} \
    CONFIG.PCW_EN_EMIO_I2C1 {0} \
    CONFIG.PCW_EN_EMIO_MODEM_UART0 {0} \
    CONFIG.PCW_EN_EMIO_MODEM_UART1 {0} \
    CONFIG.PCW_EN_EMIO_PJTAG {0} \
    CONFIG.PCW_EN_EMIO_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_SDIO1 {0} \
    CONFIG.PCW_EN_EMIO_SPI0 {1} \
    CONFIG.PCW_EN_EMIO_SPI1 {0} \
    CONFIG.PCW_EN_EMIO_SRAM_INT {0} \
    CONFIG.PCW_EN_EMIO_TRACE {0} \
    CONFIG.PCW_EN_EMIO_TTC0 {0} \
    CONFIG.PCW_EN_EMIO_TTC1 {0} \
    CONFIG.PCW_EN_EMIO_UART0 {1} \
    CONFIG.PCW_EN_EMIO_UART1 {0} \
    CONFIG.PCW_EN_EMIO_WDT {0} \
    CONFIG.PCW_EN_EMIO_WP_SDIO0 {0} \
    CONFIG.PCW_EN_EMIO_WP_SDIO1 {0} \
    CONFIG.PCW_EN_ENET0 {1} \
    CONFIG.PCW_EN_ENET1 {0} \
    CONFIG.PCW_EN_GPIO {1} \
    CONFIG.PCW_EN_I2C0 {1} \
    CONFIG.PCW_EN_I2C1 {0} \
    CONFIG.PCW_EN_MODEM_UART0 {0} \
    CONFIG.PCW_EN_MODEM_UART1 {0} \
    CONFIG.PCW_EN_PJTAG {0} \
    CONFIG.PCW_EN_PTP_ENET0 {0} \
    CONFIG.PCW_EN_PTP_ENET1 {0} \
    CONFIG.PCW_EN_QSPI {0} \
    CONFIG.PCW_EN_RST0_PORT {1} \
    CONFIG.PCW_EN_RST1_PORT {0} \
    CONFIG.PCW_EN_RST2_PORT {0} \
    CONFIG.PCW_EN_RST3_PORT {0} \
    CONFIG.PCW_EN_SDIO0 {1} \
    CONFIG.PCW_EN_SDIO1 {0} \
    CONFIG.PCW_EN_SMC {1} \
    CONFIG.PCW_EN_SPI0 {1} \
    CONFIG.PCW_EN_SPI1 {0} \
    CONFIG.PCW_EN_TRACE {0} \
    CONFIG.PCW_EN_TTC0 {0} \
    CONFIG.PCW_EN_TTC1 {0} \
    CONFIG.PCW_EN_UART0 {1} \
    CONFIG.PCW_EN_UART1 {1} \
    CONFIG.PCW_EN_USB0 {0} \
    CONFIG.PCW_EN_USB1 {0} \
    CONFIG.PCW_EN_WDT {0} \
    CONFIG.PCW_FCLK0_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK1_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK2_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK3_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_FCLK_CLK0_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK1_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK2_BUF {TRUE} \
    CONFIG.PCW_FCLK_CLK3_BUF {TRUE} \
    CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_FPGA1_PERIPHERAL_FREQMHZ {64} \
    CONFIG.PCW_FPGA2_PERIPHERAL_FREQMHZ {142} \
    CONFIG.PCW_FPGA3_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_FPGA_FCLK0_ENABLE {1} \
    CONFIG.PCW_FPGA_FCLK1_ENABLE {1} \
    CONFIG.PCW_FPGA_FCLK2_ENABLE {1} \
    CONFIG.PCW_FPGA_FCLK3_ENABLE {1} \
    CONFIG.PCW_GP0_EN_MODIFIABLE_TXN {1} \
    CONFIG.PCW_GP0_NUM_READ_THREADS {4} \
    CONFIG.PCW_GP0_NUM_WRITE_THREADS {4} \
    CONFIG.PCW_GP1_EN_MODIFIABLE_TXN {1} \
    CONFIG.PCW_GP1_NUM_READ_THREADS {4} \
    CONFIG.PCW_GP1_NUM_WRITE_THREADS {4} \
    CONFIG.PCW_GPIO_BASEADDR {0xE000A000} \
    CONFIG.PCW_GPIO_EMIO_GPIO_ENABLE {1} \
    CONFIG.PCW_GPIO_EMIO_GPIO_IO {64} \
    CONFIG.PCW_GPIO_EMIO_GPIO_WIDTH {64} \
    CONFIG.PCW_GPIO_HIGHADDR {0xE000AFFF} \
    CONFIG.PCW_GPIO_MIO_GPIO_ENABLE {1} \
    CONFIG.PCW_GPIO_MIO_GPIO_IO {MIO} \
    CONFIG.PCW_GPIO_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_I2C0_BASEADDR {0xE0004000} \
    CONFIG.PCW_I2C0_HIGHADDR {0xE0004FFF} \
    CONFIG.PCW_I2C0_I2C0_IO {EMIO} \
    CONFIG.PCW_I2C0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_I2C0_RESET_ENABLE {0} \
    CONFIG.PCW_I2C1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_I2C_PERIPHERAL_FREQMHZ {111.111115} \
    CONFIG.PCW_I2C_RESET_ENABLE {1} \
    CONFIG.PCW_I2C_RESET_POLARITY {Active Low} \
    CONFIG.PCW_I2C_RESET_SELECT {Share reset pin} \
    CONFIG.PCW_IMPORT_BOARD_PRESET {None} \
    CONFIG.PCW_INCLUDE_ACP_TRANS_CHECK {0} \
    CONFIG.PCW_IRQ_F2P_INTR {1} \
    CONFIG.PCW_IRQ_F2P_MODE {DIRECT} \
    CONFIG.PCW_MIO_0_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_0_PULLUP {disabled} \
    CONFIG.PCW_MIO_0_SLEW {slow} \
    CONFIG.PCW_MIO_10_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_10_PULLUP {enabled} \
    CONFIG.PCW_MIO_10_SLEW {slow} \
    CONFIG.PCW_MIO_11_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_11_PULLUP {enabled} \
    CONFIG.PCW_MIO_11_SLEW {slow} \
    CONFIG.PCW_MIO_12_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_12_PULLUP {enabled} \
    CONFIG.PCW_MIO_12_SLEW {slow} \
    CONFIG.PCW_MIO_13_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_13_PULLUP {enabled} \
    CONFIG.PCW_MIO_13_SLEW {slow} \
    CONFIG.PCW_MIO_14_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_14_PULLUP {disabled} \
    CONFIG.PCW_MIO_14_SLEW {slow} \
    CONFIG.PCW_MIO_15_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_15_PULLUP {enabled} \
    CONFIG.PCW_MIO_15_SLEW {slow} \
    CONFIG.PCW_MIO_16_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_16_PULLUP {enabled} \
    CONFIG.PCW_MIO_16_SLEW {slow} \
    CONFIG.PCW_MIO_17_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_17_PULLUP {enabled} \
    CONFIG.PCW_MIO_17_SLEW {slow} \
    CONFIG.PCW_MIO_18_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_18_PULLUP {enabled} \
    CONFIG.PCW_MIO_18_SLEW {slow} \
    CONFIG.PCW_MIO_19_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_19_PULLUP {enabled} \
    CONFIG.PCW_MIO_19_SLEW {slow} \
    CONFIG.PCW_MIO_1_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_1_PULLUP {enabled} \
    CONFIG.PCW_MIO_1_SLEW {slow} \
    CONFIG.PCW_MIO_20_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_20_PULLUP {enabled} \
    CONFIG.PCW_MIO_20_SLEW {slow} \
    CONFIG.PCW_MIO_21_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_21_PULLUP {enabled} \
    CONFIG.PCW_MIO_21_SLEW {slow} \
    CONFIG.PCW_MIO_22_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_22_PULLUP {enabled} \
    CONFIG.PCW_MIO_22_SLEW {slow} \
    CONFIG.PCW_MIO_23_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_23_PULLUP {enabled} \
    CONFIG.PCW_MIO_23_SLEW {slow} \
    CONFIG.PCW_MIO_24_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_24_PULLUP {enabled} \
    CONFIG.PCW_MIO_24_SLEW {slow} \
    CONFIG.PCW_MIO_25_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_25_PULLUP {enabled} \
    CONFIG.PCW_MIO_25_SLEW {slow} \
    CONFIG.PCW_MIO_26_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_26_PULLUP {enabled} \
    CONFIG.PCW_MIO_26_SLEW {slow} \
    CONFIG.PCW_MIO_27_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_27_PULLUP {enabled} \
    CONFIG.PCW_MIO_27_SLEW {slow} \
    CONFIG.PCW_MIO_28_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_28_PULLUP {enabled} \
    CONFIG.PCW_MIO_28_SLEW {slow} \
    CONFIG.PCW_MIO_29_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_29_PULLUP {enabled} \
    CONFIG.PCW_MIO_29_SLEW {slow} \
    CONFIG.PCW_MIO_2_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_2_SLEW {slow} \
    CONFIG.PCW_MIO_30_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_30_PULLUP {enabled} \
    CONFIG.PCW_MIO_30_SLEW {slow} \
    CONFIG.PCW_MIO_31_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_31_PULLUP {enabled} \
    CONFIG.PCW_MIO_31_SLEW {slow} \
    CONFIG.PCW_MIO_32_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_32_PULLUP {enabled} \
    CONFIG.PCW_MIO_32_SLEW {slow} \
    CONFIG.PCW_MIO_33_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_33_PULLUP {enabled} \
    CONFIG.PCW_MIO_33_SLEW {slow} \
    CONFIG.PCW_MIO_34_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_34_PULLUP {enabled} \
    CONFIG.PCW_MIO_34_SLEW {slow} \
    CONFIG.PCW_MIO_35_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_35_PULLUP {enabled} \
    CONFIG.PCW_MIO_35_SLEW {slow} \
    CONFIG.PCW_MIO_36_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_36_PULLUP {enabled} \
    CONFIG.PCW_MIO_36_SLEW {slow} \
    CONFIG.PCW_MIO_37_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_37_PULLUP {enabled} \
    CONFIG.PCW_MIO_37_SLEW {slow} \
    CONFIG.PCW_MIO_38_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_38_PULLUP {enabled} \
    CONFIG.PCW_MIO_38_SLEW {slow} \
    CONFIG.PCW_MIO_39_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_39_PULLUP {enabled} \
    CONFIG.PCW_MIO_39_SLEW {slow} \
    CONFIG.PCW_MIO_3_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_3_SLEW {slow} \
    CONFIG.PCW_MIO_40_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_40_PULLUP {enabled} \
    CONFIG.PCW_MIO_40_SLEW {slow} \
    CONFIG.PCW_MIO_41_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_41_PULLUP {enabled} \
    CONFIG.PCW_MIO_41_SLEW {slow} \
    CONFIG.PCW_MIO_42_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_42_PULLUP {enabled} \
    CONFIG.PCW_MIO_42_SLEW {slow} \
    CONFIG.PCW_MIO_43_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_43_PULLUP {enabled} \
    CONFIG.PCW_MIO_43_SLEW {slow} \
    CONFIG.PCW_MIO_44_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_44_PULLUP {enabled} \
    CONFIG.PCW_MIO_44_SLEW {slow} \
    CONFIG.PCW_MIO_45_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_45_PULLUP {enabled} \
    CONFIG.PCW_MIO_45_SLEW {slow} \
    CONFIG.PCW_MIO_46_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_46_PULLUP {enabled} \
    CONFIG.PCW_MIO_46_SLEW {slow} \
    CONFIG.PCW_MIO_47_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_47_PULLUP {enabled} \
    CONFIG.PCW_MIO_47_SLEW {slow} \
    CONFIG.PCW_MIO_48_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_48_PULLUP {enabled} \
    CONFIG.PCW_MIO_48_SLEW {slow} \
    CONFIG.PCW_MIO_49_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_49_PULLUP {enabled} \
    CONFIG.PCW_MIO_49_SLEW {slow} \
    CONFIG.PCW_MIO_4_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_4_SLEW {slow} \
    CONFIG.PCW_MIO_50_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_50_PULLUP {enabled} \
    CONFIG.PCW_MIO_50_SLEW {slow} \
    CONFIG.PCW_MIO_51_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_51_PULLUP {enabled} \
    CONFIG.PCW_MIO_51_SLEW {slow} \
    CONFIG.PCW_MIO_52_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_52_PULLUP {enabled} \
    CONFIG.PCW_MIO_52_SLEW {slow} \
    CONFIG.PCW_MIO_53_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_53_PULLUP {enabled} \
    CONFIG.PCW_MIO_53_SLEW {slow} \
    CONFIG.PCW_MIO_5_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_5_SLEW {slow} \
    CONFIG.PCW_MIO_6_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_6_SLEW {slow} \
    CONFIG.PCW_MIO_7_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_7_SLEW {slow} \
    CONFIG.PCW_MIO_8_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_8_SLEW {slow} \
    CONFIG.PCW_MIO_9_IOTYPE {LVCMOS 3.3V} \
    CONFIG.PCW_MIO_9_PULLUP {enabled} \
    CONFIG.PCW_MIO_9_SLEW {slow} \
    CONFIG.PCW_MIO_PRIMITIVE {54} \
    CONFIG.PCW_MIO_TREE_PERIPHERALS {NAND Flash#GPIO#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#NAND Flash#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#UART\
1#UART 1#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#SD 0#GPIO#GPIO#GPIO#GPIO#GPIO#SD 0#SD 0#SD 0#SD 0#SD 0#SD 0#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO#GPIO} \
    CONFIG.PCW_MIO_TREE_SIGNALS {cs#gpio[1]#ale#we_b#data[2]#data[0]#data[1]#cle#re_b#data[4]#data[5]#data[6]#data[7]#data[3]#busy#gpio[15]#gpio[16]#gpio[17]#gpio[18]#gpio[19]#gpio[20]#gpio[21]#gpio[22]#gpio[23]#tx#rx#gpio[26]#gpio[27]#gpio[28]#gpio[29]#gpio[30]#gpio[31]#gpio[32]#gpio[33]#cd#gpio[35]#gpio[36]#gpio[37]#gpio[38]#gpio[39]#clk#cmd#data[0]#data[1]#data[2]#data[3]#gpio[46]#gpio[47]#gpio[48]#gpio[49]#gpio[50]#gpio[51]#gpio[52]#gpio[53]}\
\
    CONFIG.PCW_M_AXI_GP0_ENABLE_STATIC_REMAP {0} \
    CONFIG.PCW_M_AXI_GP0_ID_WIDTH {12} \
    CONFIG.PCW_M_AXI_GP0_SUPPORT_NARROW_BURST {0} \
    CONFIG.PCW_M_AXI_GP0_THREAD_ID_WIDTH {12} \
    CONFIG.PCW_NAND_CYCLES_T_AR {10} \
    CONFIG.PCW_NAND_CYCLES_T_CLR {20} \
    CONFIG.PCW_NAND_CYCLES_T_RC {50} \
    CONFIG.PCW_NAND_CYCLES_T_REA {20} \
    CONFIG.PCW_NAND_CYCLES_T_RR {20} \
    CONFIG.PCW_NAND_CYCLES_T_WC {50} \
    CONFIG.PCW_NAND_CYCLES_T_WP {25} \
    CONFIG.PCW_NAND_GRP_D8_ENABLE {0} \
    CONFIG.PCW_NAND_NAND_IO {MIO 0 2.. 14} \
    CONFIG.PCW_NAND_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_NOR_CS0_T_CEOE {1} \
    CONFIG.PCW_NOR_CS0_T_PC {1} \
    CONFIG.PCW_NOR_CS0_T_RC {11} \
    CONFIG.PCW_NOR_CS0_T_TR {1} \
    CONFIG.PCW_NOR_CS0_T_WC {11} \
    CONFIG.PCW_NOR_CS0_T_WP {1} \
    CONFIG.PCW_NOR_CS0_WE_TIME {0} \
    CONFIG.PCW_NOR_CS1_T_CEOE {1} \
    CONFIG.PCW_NOR_CS1_T_PC {1} \
    CONFIG.PCW_NOR_CS1_T_RC {11} \
    CONFIG.PCW_NOR_CS1_T_TR {1} \
    CONFIG.PCW_NOR_CS1_T_WC {11} \
    CONFIG.PCW_NOR_CS1_T_WP {1} \
    CONFIG.PCW_NOR_CS1_WE_TIME {0} \
    CONFIG.PCW_NOR_SRAM_CS0_T_CEOE {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_PC {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_RC {11} \
    CONFIG.PCW_NOR_SRAM_CS0_T_TR {1} \
    CONFIG.PCW_NOR_SRAM_CS0_T_WC {11} \
    CONFIG.PCW_NOR_SRAM_CS0_T_WP {1} \
    CONFIG.PCW_NOR_SRAM_CS0_WE_TIME {0} \
    CONFIG.PCW_NOR_SRAM_CS1_T_CEOE {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_PC {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_RC {11} \
    CONFIG.PCW_NOR_SRAM_CS1_T_TR {1} \
    CONFIG.PCW_NOR_SRAM_CS1_T_WC {11} \
    CONFIG.PCW_NOR_SRAM_CS1_T_WP {1} \
    CONFIG.PCW_NOR_SRAM_CS1_WE_TIME {0} \
    CONFIG.PCW_OVERRIDE_BASIC_CLOCK {0} \
    CONFIG.PCW_P2F_ENET0_INTR {0} \
    CONFIG.PCW_P2F_GPIO_INTR {0} \
    CONFIG.PCW_P2F_I2C0_INTR {0} \
    CONFIG.PCW_P2F_SDIO0_INTR {0} \
    CONFIG.PCW_P2F_SMC_INTR {0} \
    CONFIG.PCW_P2F_SPI0_INTR {0} \
    CONFIG.PCW_P2F_UART0_INTR {0} \
    CONFIG.PCW_P2F_UART1_INTR {0} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY0 {0.080} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY1 {0.063} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY2 {0.057} \
    CONFIG.PCW_PACKAGE_DDR_BOARD_DELAY3 {0.068} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_0 {-0.047} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_1 {-0.025} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_2 {-0.006} \
    CONFIG.PCW_PACKAGE_DDR_DQS_TO_CLK_DELAY_3 {-0.017} \
    CONFIG.PCW_PACKAGE_NAME {clg400} \
    CONFIG.PCW_PCAP_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_PCAP_PERIPHERAL_FREQMHZ {200} \
    CONFIG.PCW_PERIPHERAL_BOARD_PRESET {part0} \
    CONFIG.PCW_PJTAG_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_PLL_BYPASSMODE_ENABLE {0} \
    CONFIG.PCW_PRESET_BANK0_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_PRESET_BANK1_VOLTAGE {LVCMOS 3.3V} \
    CONFIG.PCW_PS7_SI_REV {PRODUCTION} \
    CONFIG.PCW_QSPI_INTERNAL_HIGHADDRESS {0xFCFFFFFF} \
    CONFIG.PCW_QSPI_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SD0_GRP_CD_ENABLE {1} \
    CONFIG.PCW_SD0_GRP_CD_IO {MIO 34} \
    CONFIG.PCW_SD0_GRP_POW_ENABLE {0} \
    CONFIG.PCW_SD0_GRP_WP_ENABLE {0} \
    CONFIG.PCW_SD0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SD0_SD0_IO {MIO 40 .. 45} \
    CONFIG.PCW_SD1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_SDIO0_BASEADDR {0xE0100000} \
    CONFIG.PCW_SDIO0_HIGHADDR {0xE0100FFF} \
    CONFIG.PCW_SDIO_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SDIO_PERIPHERAL_FREQMHZ {25} \
    CONFIG.PCW_SDIO_PERIPHERAL_VALID {1} \
    CONFIG.PCW_SMC_CYCLE_T0 {NA} \
    CONFIG.PCW_SMC_CYCLE_T1 {NA} \
    CONFIG.PCW_SMC_CYCLE_T2 {NA} \
    CONFIG.PCW_SMC_CYCLE_T3 {NA} \
    CONFIG.PCW_SMC_CYCLE_T4 {NA} \
    CONFIG.PCW_SMC_CYCLE_T5 {NA} \
    CONFIG.PCW_SMC_CYCLE_T6 {NA} \
    CONFIG.PCW_SMC_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SMC_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_SMC_PERIPHERAL_VALID {1} \
    CONFIG.PCW_SPI0_BASEADDR {0xE0006000} \
    CONFIG.PCW_SPI0_HIGHADDR {0xE0006FFF} \
    CONFIG.PCW_SPI0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_SPI0_SPI0_IO {EMIO} \
    CONFIG.PCW_SPI1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_SPI_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_SPI_PERIPHERAL_FREQMHZ {166.666666} \
    CONFIG.PCW_SPI_PERIPHERAL_VALID {1} \
    CONFIG.PCW_S_AXI_HP0_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP0_ID_WIDTH {6} \
    CONFIG.PCW_S_AXI_HP1_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP1_ID_WIDTH {6} \
    CONFIG.PCW_S_AXI_HP2_DATA_WIDTH {64} \
    CONFIG.PCW_S_AXI_HP2_ID_WIDTH {6} \
    CONFIG.PCW_TPIU_PERIPHERAL_CLKSRC {External} \
    CONFIG.PCW_TRACE_INTERNAL_WIDTH {2} \
    CONFIG.PCW_TRACE_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK0_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK1_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC0_CLK2_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK0_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK1_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_TTC1_CLK2_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_TTC1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_UART0_BASEADDR {0xE0000000} \
    CONFIG.PCW_UART0_BAUD_RATE {115200} \
    CONFIG.PCW_UART0_GRP_FULL_ENABLE {0} \
    CONFIG.PCW_UART0_HIGHADDR {0xE0000FFF} \
    CONFIG.PCW_UART0_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART0_UART0_IO {EMIO} \
    CONFIG.PCW_UART1_BASEADDR {0xE0001000} \
    CONFIG.PCW_UART1_BAUD_RATE {115200} \
    CONFIG.PCW_UART1_GRP_FULL_ENABLE {0} \
    CONFIG.PCW_UART1_HIGHADDR {0xE0001FFF} \
    CONFIG.PCW_UART1_PERIPHERAL_ENABLE {1} \
    CONFIG.PCW_UART1_UART1_IO {MIO 24 .. 25} \
    CONFIG.PCW_UART_PERIPHERAL_CLKSRC {IO PLL} \
    CONFIG.PCW_UART_PERIPHERAL_FREQMHZ {100} \
    CONFIG.PCW_UART_PERIPHERAL_VALID {1} \
    CONFIG.PCW_UIPARAM_ACT_DDR_FREQ_MHZ {533.333374} \
    CONFIG.PCW_UIPARAM_DDR_ADV_ENABLE {0} \
    CONFIG.PCW_UIPARAM_DDR_AL {0} \
    CONFIG.PCW_UIPARAM_DDR_BL {8} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY0 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY1 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY2 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BOARD_DELAY3 {0.25} \
    CONFIG.PCW_UIPARAM_DDR_BUS_WIDTH {16 Bit} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PACKAGE_LENGTH {54.563} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PACKAGE_LENGTH {54.563} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PACKAGE_LENGTH {54.563} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PACKAGE_LENGTH {54.563} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_CLOCK_STOP_EN {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PACKAGE_LENGTH {101.239} \
    CONFIG.PCW_UIPARAM_DDR_DQS_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PACKAGE_LENGTH {79.5025} \
    CONFIG.PCW_UIPARAM_DDR_DQS_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PACKAGE_LENGTH {60.536} \
    CONFIG.PCW_UIPARAM_DDR_DQS_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PACKAGE_LENGTH {71.7715} \
    CONFIG.PCW_UIPARAM_DDR_DQS_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_0 {0.0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_1 {0.0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_2 {0.0} \
    CONFIG.PCW_UIPARAM_DDR_DQS_TO_CLK_DELAY_3 {0.0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PACKAGE_LENGTH {104.5365} \
    CONFIG.PCW_UIPARAM_DDR_DQ_0_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PACKAGE_LENGTH {70.676} \
    CONFIG.PCW_UIPARAM_DDR_DQ_1_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PACKAGE_LENGTH {59.1615} \
    CONFIG.PCW_UIPARAM_DDR_DQ_2_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_LENGTH_MM {0} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PACKAGE_LENGTH {81.319} \
    CONFIG.PCW_UIPARAM_DDR_DQ_3_PROPOGATION_DELAY {160} \
    CONFIG.PCW_UIPARAM_DDR_ECC {Disabled} \
    CONFIG.PCW_UIPARAM_DDR_ENABLE {1} \
    CONFIG.PCW_UIPARAM_DDR_FREQ_MHZ {533.333333} \
    CONFIG.PCW_UIPARAM_DDR_HIGH_TEMP {Normal (0-85)} \
    CONFIG.PCW_UIPARAM_DDR_MEMORY_TYPE {DDR 3} \
    CONFIG.PCW_UIPARAM_DDR_PARTNO {MT41K128M16 JT-125} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_DATA_EYE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_READ_GATE {1} \
    CONFIG.PCW_UIPARAM_DDR_TRAIN_WRITE_LEVEL {1} \
    CONFIG.PCW_UIPARAM_DDR_USE_INTERNAL_VREF {0} \
    CONFIG.PCW_UIPARAM_GENERATE_SUMMARY {NA} \
    CONFIG.PCW_USB0_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_USB1_PERIPHERAL_ENABLE {0} \
    CONFIG.PCW_USB_RESET_ENABLE {1} \
    CONFIG.PCW_USB_RESET_POLARITY {Active Low} \
    CONFIG.PCW_USE_AXI_FABRIC_IDLE {0} \
    CONFIG.PCW_USE_AXI_NONSECURE {0} \
    CONFIG.PCW_USE_CORESIGHT {0} \
    CONFIG.PCW_USE_CROSS_TRIGGER {0} \
    CONFIG.PCW_USE_CR_FABRIC {1} \
    CONFIG.PCW_USE_DDR_BYPASS {0} \
    CONFIG.PCW_USE_DEBUG {0} \
    CONFIG.PCW_USE_DMA0 {0} \
    CONFIG.PCW_USE_DMA1 {0} \
    CONFIG.PCW_USE_DMA2 {0} \
    CONFIG.PCW_USE_DMA3 {0} \
    CONFIG.PCW_USE_EXPANDED_IOP {0} \
    CONFIG.PCW_USE_FABRIC_INTERRUPT {1} \
    CONFIG.PCW_USE_HIGH_OCM {0} \
    CONFIG.PCW_USE_M_AXI_GP0 {1} \
    CONFIG.PCW_USE_M_AXI_GP1 {0} \
    CONFIG.PCW_USE_PROC_EVENT_BUS {0} \
    CONFIG.PCW_USE_PS_SLCR_REGISTERS {0} \
    CONFIG.PCW_USE_S_AXI_ACP {0} \
    CONFIG.PCW_USE_S_AXI_GP0 {0} \
    CONFIG.PCW_USE_S_AXI_GP1 {0} \
    CONFIG.PCW_USE_S_AXI_HP0 {1} \
    CONFIG.PCW_USE_S_AXI_HP1 {1} \
    CONFIG.PCW_USE_S_AXI_HP2 {1} \
    CONFIG.PCW_USE_S_AXI_HP3 {0} \
    CONFIG.PCW_USE_TRACE {0} \
    CONFIG.PCW_VALUE_SILVERSION {3} \
    CONFIG.PCW_WDT_PERIPHERAL_CLKSRC {CPU_1X} \
    CONFIG.PCW_WDT_PERIPHERAL_DIVISOR0 {1} \
    CONFIG.PCW_WDT_PERIPHERAL_ENABLE {0} \
    CONFIG.preset {None} \
  ] $processing_system7_0


  # Create instance: rst_ps7_0_140M, and set properties
  set rst_ps7_0_140M [ create_bd_cell -type ip -vlnv xilinx.com:ip:proc_sys_reset:5.0 rst_ps7_0_140M ]

  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {4} \
    CONFIG.IN1_WIDTH {4} \
    CONFIG.NUM_PORTS {2} \
  ] $xlconcat_0


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {3} \
    CONFIG.DIN_TO {0} \
    CONFIG.DIN_WIDTH {8} \
    CONFIG.DOUT_WIDTH {4} \
  ] $xlslice_0


  # Create interface connections
  connect_bd_intf_net -intf_net Conn1 [get_bd_intf_pins M_AXI_GP0] [get_bd_intf_pins processing_system7_0/M_AXI_GP0]
  connect_bd_intf_net -intf_net S_AXI_HP0_1 [get_bd_intf_pins S_AXI_HP0] [get_bd_intf_pins processing_system7_0/S_AXI_HP0]
  connect_bd_intf_net -intf_net S_AXI_HP1_1 [get_bd_intf_pins S_AXI_HP1] [get_bd_intf_pins processing_system7_0/S_AXI_HP1]
  connect_bd_intf_net -intf_net S_AXI_HP2_2 [get_bd_intf_pins S_AXI_HP2] [get_bd_intf_pins processing_system7_0/S_AXI_HP2]
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_pins DDR] [get_bd_intf_pins processing_system7_0/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_pins FIXED_IO] [get_bd_intf_pins processing_system7_0/FIXED_IO]
  connect_bd_intf_net -intf_net processing_system7_0_MDIO_ETHERNET_0 [get_bd_intf_pins MDIO_ETHERNET_0_0] [get_bd_intf_pins processing_system7_0/MDIO_ETHERNET_0]

  # Create port connections
  connect_bd_net -net DivideBy4_25MHz_clk_out [get_bd_pins CLK_25M] [get_bd_pins DivideBy4_25MHz/clk_out]
  connect_bd_net -net ENET0_GMII_RX_CLK_0_1 [get_bd_pins ENET0_GMII_RX_CLK_0] [get_bd_pins processing_system7_0/ENET0_GMII_RX_CLK]
  connect_bd_net -net ENET0_GMII_RX_DV_0_1 [get_bd_pins ENET0_GMII_RX_DV_0] [get_bd_pins processing_system7_0/ENET0_GMII_RX_DV]
  connect_bd_net -net ENET0_GMII_TX_CLK_0_1 [get_bd_pins ENET0_GMII_TX_CLK_0] [get_bd_pins processing_system7_0/ENET0_GMII_TX_CLK]
  connect_bd_net -net IRQ_F2P_1 [get_bd_pins IRQ_F2P] [get_bd_pins processing_system7_0/IRQ_F2P]
  connect_bd_net -net In0_0_1 [get_bd_pins enet0_gmii_rxd] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net PS_I2C0_SCL_I [get_bd_pins I2C0_SCL_I] [get_bd_pins processing_system7_0/I2C0_SCL_I]
  connect_bd_net -net PS_I2C0_SCL_O [get_bd_pins I2C0_SCL_O] [get_bd_pins processing_system7_0/I2C0_SCL_O]
  connect_bd_net -net PS_I2C0_SCL_T [get_bd_pins I2C0_SCL_T] [get_bd_pins processing_system7_0/I2C0_SCL_T]
  connect_bd_net -net PS_I2C0_SDA_I [get_bd_pins I2C0_SDA_I] [get_bd_pins processing_system7_0/I2C0_SDA_I]
  connect_bd_net -net PS_I2C0_SDA_O [get_bd_pins I2C0_SDA_O] [get_bd_pins processing_system7_0/I2C0_SDA_O]
  connect_bd_net -net PS_I2C0_SDA_T [get_bd_pins I2C0_SDA_T] [get_bd_pins processing_system7_0/I2C0_SDA_T]
  connect_bd_net -net PS_SPI0_MISO_I [get_bd_pins SPI0_MISO_I] [get_bd_pins processing_system7_0/SPI0_MISO_I]
  connect_bd_net -net PS_SPI0_MOSI_I [get_bd_pins SPI0_MOSI_I] [get_bd_pins processing_system7_0/SPI0_MOSI_I]
  connect_bd_net -net PS_SPI0_MOSI_O [get_bd_pins SPI0_MOSI_O] [get_bd_pins processing_system7_0/SPI0_MOSI_O]
  connect_bd_net -net PS_SPI0_MOSI_T [get_bd_pins SPI0_MOSI_T] [get_bd_pins processing_system7_0/SPI0_MOSI_T]
  connect_bd_net -net PS_SPI0_SCLK_I [get_bd_pins SPI0_SCLK_I] [get_bd_pins processing_system7_0/SPI0_SCLK_I]
  connect_bd_net -net PS_SPI0_SCLK_O [get_bd_pins SPI0_SCLK_O] [get_bd_pins processing_system7_0/SPI0_SCLK_O]
  connect_bd_net -net PS_SPI0_SCLK_T [get_bd_pins SPI0_SCLK_T] [get_bd_pins processing_system7_0/SPI0_SCLK_T]
  connect_bd_net -net PS_SPI0_SS1_O [get_bd_pins SPI0_SS1_O] [get_bd_pins processing_system7_0/SPI0_SS1_O]
  connect_bd_net -net PS_SPI0_SS_I [get_bd_pins SPI0_SS_I] [get_bd_pins processing_system7_0/SPI0_SS_I]
  connect_bd_net -net PS_SPI0_SS_O [get_bd_pins SPI0_SS_O] [get_bd_pins processing_system7_0/SPI0_SS_O]
  connect_bd_net -net PS_SPI0_SS_T [get_bd_pins SPI0_SS_T] [get_bd_pins processing_system7_0/SPI0_SS_T]
  connect_bd_net -net PS_UART0_RX [get_bd_pins UART0_RX] [get_bd_pins processing_system7_0/UART0_RX]
  connect_bd_net -net PS_UART0_TX [get_bd_pins UART0_TX] [get_bd_pins processing_system7_0/UART0_TX]
  connect_bd_net -net proc_sys_reset_0_peripheral_aresetn [get_bd_pins ARESETN] [get_bd_pins proc_sys_reset_0_100M/peripheral_aresetn]
  connect_bd_net -net processing_system7_0_ENET0_GMII_TXD [get_bd_pins processing_system7_0/ENET0_GMII_TXD] [get_bd_pins xlslice_0/Din]
  connect_bd_net -net processing_system7_0_ENET0_GMII_TX_EN [get_bd_pins ENET0_GMII_TX_EN_0] [get_bd_pins processing_system7_0/ENET0_GMII_TX_EN]
  connect_bd_net -net processing_system7_0_FCLK_CLK0 [get_bd_pins FCLK_CLK0_100M] [get_bd_pins DivideBy4_25MHz/clk] [get_bd_pins proc_sys_reset_0_100M/slowest_sync_clk] [get_bd_pins processing_system7_0/FCLK_CLK0] [get_bd_pins processing_system7_0/M_AXI_GP0_ACLK]
  connect_bd_net -net processing_system7_0_FCLK_CLK2_140M [get_bd_pins FCLK_CLK2_140M] [get_bd_pins processing_system7_0/FCLK_CLK2] [get_bd_pins processing_system7_0/S_AXI_HP0_ACLK] [get_bd_pins processing_system7_0/S_AXI_HP1_ACLK] [get_bd_pins processing_system7_0/S_AXI_HP2_ACLK] [get_bd_pins rst_ps7_0_140M/slowest_sync_clk]
  connect_bd_net -net processing_system7_0_FCLK_CLK3 [get_bd_pins FCLK_CLK0_200M] [get_bd_pins processing_system7_0/FCLK_CLK3]
  connect_bd_net -net processing_system7_0_FCLK_RESET0_N [get_bd_pins proc_sys_reset_0_100M/ext_reset_in] [get_bd_pins processing_system7_0/FCLK_RESET0_N] [get_bd_pins rst_ps7_0_140M/ext_reset_in]
  connect_bd_net -net rst_ps7_0_140M_peripheral_aresetn [get_bd_pins peripheral_aresetn1] [get_bd_pins rst_ps7_0_140M/peripheral_aresetn]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins processing_system7_0/ENET0_GMII_RXD] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins DivideBy4_25MHz/resetn] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins enet0_gmii_txd] [get_bd_pins xlslice_0/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: HDMI_2
proc create_hier_cell_HDMI_2 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_HDMI_2() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 DDC_2

  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE_0


  # Create pins
  create_bd_pin -dir I -type clk RefClk
  create_bd_pin -dir I -type clk TMDS_Clk_n_2
  create_bd_pin -dir I -type clk TMDS_Clk_p_2
  create_bd_pin -dir I -from 2 -to 0 TMDS_Data_n_2
  create_bd_pin -dir I -from 2 -to 0 TMDS_Data_p_2
  create_bd_pin -dir I -type rst aRst_n
  create_bd_pin -dir O -from 4 -to 0 debug
  create_bd_pin -dir I -type clk m_axi_s2mm_aclk_0
  create_bd_pin -dir I -type rst pRst_n
  create_bd_pin -dir O -from 19 -to 0 rx_acr_cts
  create_bd_pin -dir O -from 19 -to 0 rx_acr_n
  create_bd_pin -dir O -from 15 -to 0 rx_aud_l
  create_bd_pin -dir O -from 15 -to 0 rx_aud_r
  create_bd_pin -dir O rx_aud_valid
  create_bd_pin -dir O -type clk rx_clk
  create_bd_pin -dir I -from 31 -to 0 rx_ctrl
  create_bd_pin -dir O -from 31 -to 0 rx_peak
  create_bd_pin -dir O rx_pub
  create_bd_pin -dir O -from 31 -to 0 rx_samples
  create_bd_pin -dir O -from 31 -to 0 rx_size_h
  create_bd_pin -dir O -from 31 -to 0 rx_size_v
  create_bd_pin -dir O -from 1 -to 0 rx_status
  create_bd_pin -dir O -type intr s2mm_introut_0
  create_bd_pin -dir I -type clk s_axi_lite_aclk_0
  create_bd_pin -dir I -type clk s_axis_s2mm_aclk_0
  create_bd_pin -dir O -from 15 -to 0 tx_aud_l
  create_bd_pin -dir O -from 15 -to 0 tx_aud_r
  create_bd_pin -dir O tx_aud_valid
  create_bd_pin -dir I -type clk tx_clk

  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
    CONFIG.S00_HAS_DATA_FIFO {0} \
    CONFIG.S00_HAS_REGSLICE {0} \
  ] $axi_interconnect_1


  # Create instance: axi_vdma_0, and set properties
  set axi_vdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0 ]
  set_property -dict [list \
    CONFIG.c_include_mm2s {0} \
    CONFIG.c_num_fstores {3} \
    CONFIG.c_s2mm_linebuffer_depth {4096} \
    CONFIG.c_s2mm_max_burst_length {16} \
  ] $axi_vdma_0


  # Create instance: axis_subset_converter_0, and set properties
  set axis_subset_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 axis_subset_converter_0 ]
  set_property -dict [list \
    CONFIG.M_HAS_TKEEP {1} \
    CONFIG.M_HAS_TLAST {1} \
    CONFIG.M_TDATA_NUM_BYTES {4} \
    CONFIG.M_TUSER_WIDTH {1} \
    CONFIG.S_HAS_TKEEP {1} \
    CONFIG.S_HAS_TLAST {1} \
    CONFIG.S_TDATA_NUM_BYTES {3} \
    CONFIG.S_TUSER_WIDTH {1} \
    CONFIG.TDATA_REMAP {8'b11111111,tdata[23:16],tdata[7:0],tdata[15:8]} \
  ] $axis_subset_converter_0


  # Create instance: dvi2rgb_0, and set properties
  set dvi2rgb_0 [ create_bd_cell -type ip -vlnv digilentinc.com:ip:dvi2rgb:2.0 dvi2rgb_0 ]
  set_property -dict [list \
    CONFIG.kAddBUFG {false} \
    CONFIG.kClkRange {2} \
    CONFIG.kDebug {false} \
    CONFIG.kRstActiveHigh {false} \
  ] $dvi2rgb_0


  # Create instance: hdmi_rx_0, and set properties
  set block_name hdmi_rx
  set block_cell_name hdmi_rx_0
  if { [catch {set hdmi_rx_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hdmi_rx_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: v_vid_in_axi4s_0, and set properties
  set v_vid_in_axi4s_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_vid_in_axi4s:5.0 v_vid_in_axi4s_0 ]
  set_property -dict [list \
    CONFIG.C_ADDR_WIDTH {13} \
    CONFIG.C_HAS_ASYNC_CLK {1} \
  ] $v_vid_in_axi4s_0


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property CONFIG.NUM_PORTS {5} $xlconcat_0


  # Create interface connections
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins M00_AXI_0] [get_bd_intf_pins axi_interconnect_1/M00_AXI]
  connect_bd_intf_net -intf_net Conn3 [get_bd_intf_pins S_AXI_LITE_0] [get_bd_intf_pins axi_vdma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_vdma_0_M_AXI_S2MM [get_bd_intf_pins axi_interconnect_1/S00_AXI] [get_bd_intf_pins axi_vdma_0/M_AXI_S2MM]
  connect_bd_intf_net -intf_net axis_subset_converter_0_M_AXIS [get_bd_intf_pins axi_vdma_0/S_AXIS_S2MM] [get_bd_intf_pins axis_subset_converter_0/M_AXIS]
  connect_bd_intf_net -intf_net dvi2rgb_1_DDC [get_bd_intf_pins DDC_2] [get_bd_intf_pins dvi2rgb_0/DDC]
  connect_bd_intf_net -intf_net v_vid_in_axi4s_0_video_out [get_bd_intf_pins axis_subset_converter_0/S_AXIS] [get_bd_intf_pins v_vid_in_axi4s_0/video_out]

  # Create port connections
  connect_bd_net -net RefClk_1 [get_bd_pins RefClk] [get_bd_pins dvi2rgb_0/RefClk]
  connect_bd_net -net TMDS_Clk_n_2_1 [get_bd_pins TMDS_Clk_n_2] [get_bd_pins dvi2rgb_0/TMDS_Clk_n]
  connect_bd_net -net TMDS_Clk_p_2_1 [get_bd_pins TMDS_Clk_p_2] [get_bd_pins dvi2rgb_0/TMDS_Clk_p]
  connect_bd_net -net TMDS_Data_n_2_1 [get_bd_pins TMDS_Data_n_2] [get_bd_pins dvi2rgb_0/TMDS_Data_n]
  connect_bd_net -net TMDS_Data_p_2_1 [get_bd_pins TMDS_Data_p_2] [get_bd_pins dvi2rgb_0/TMDS_Data_p]
  connect_bd_net -net aRst_n_1 [get_bd_pins aRst_n] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axi_vdma_0/axi_resetn] [get_bd_pins axis_subset_converter_0/aresetn] [get_bd_pins v_vid_in_axi4s_0/aresetn]
  connect_bd_net -net axi_vdma_0_s2mm_introut [get_bd_pins s2mm_introut_0] [get_bd_pins axi_vdma_0/s2mm_introut]
  connect_bd_net -net dvi2rgb_0_aPixelClkLckd [get_bd_pins dvi2rgb_0/aPixelClkLckd] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net dvi2rgb_0_pRawSym [get_bd_pins dvi2rgb_0/pRawSym] [get_bd_pins hdmi_rx_0/pRawSym]
  connect_bd_net -net dvi2rgb_1_PixelClk [get_bd_pins dvi2rgb_0/PixelClk] [get_bd_pins hdmi_rx_0/clk] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_clk]
  connect_bd_net -net dvi2rgb_1_pLocked [get_bd_pins dvi2rgb_0/pLocked] [get_bd_pins hdmi_rx_0/pLocked] [get_bd_pins v_vid_in_axi4s_0/vid_io_in_ce] [get_bd_pins xlconcat_0/In0]
  connect_bd_net -net dvi2rgb_1_vid_pData [get_bd_pins dvi2rgb_0/vid_pData] [get_bd_pins hdmi_rx_0/vid_pData]
  connect_bd_net -net dvi2rgb_1_vid_pHSync [get_bd_pins dvi2rgb_0/vid_pHSync] [get_bd_pins hdmi_rx_0/vid_pHSync]
  connect_bd_net -net dvi2rgb_1_vid_pVDE [get_bd_pins dvi2rgb_0/vid_pVDE] [get_bd_pins hdmi_rx_0/vid_pVDE]
  connect_bd_net -net dvi2rgb_1_vid_pVSync [get_bd_pins dvi2rgb_0/vid_pVSync] [get_bd_pins hdmi_rx_0/vid_pVSync]
  connect_bd_net -net hdmi_rx_0_o_pData [get_bd_pins hdmi_rx_0/o_pData] [get_bd_pins v_vid_in_axi4s_0/vid_data]
  connect_bd_net -net hdmi_rx_0_o_pHSync [get_bd_pins hdmi_rx_0/o_pHSync] [get_bd_pins v_vid_in_axi4s_0/vid_hsync]
  connect_bd_net -net hdmi_rx_0_o_pVDE [get_bd_pins hdmi_rx_0/o_pVDE] [get_bd_pins v_vid_in_axi4s_0/vid_active_video]
  connect_bd_net -net hdmi_rx_0_o_pVSync [get_bd_pins hdmi_rx_0/o_pVSync] [get_bd_pins v_vid_in_axi4s_0/vid_vsync]
  connect_bd_net -net hdmi_rx_0_rx_acr_cts [get_bd_pins rx_acr_cts] [get_bd_pins hdmi_rx_0/rx_acr_cts]
  connect_bd_net -net hdmi_rx_0_rx_acr_n [get_bd_pins rx_acr_n] [get_bd_pins hdmi_rx_0/rx_acr_n]
  connect_bd_net -net hdmi_rx_0_rx_clk_out [get_bd_pins rx_clk] [get_bd_pins hdmi_rx_0/rx_clk_out]
  connect_bd_net -net hdmi_rx_0_rx_l [get_bd_pins rx_aud_l] [get_bd_pins hdmi_rx_0/rx_l]
  connect_bd_net -net hdmi_rx_0_rx_peak [get_bd_pins rx_peak] [get_bd_pins hdmi_rx_0/rx_peak]
  connect_bd_net -net hdmi_rx_0_rx_pub [get_bd_pins rx_pub] [get_bd_pins hdmi_rx_0/rx_pub]
  connect_bd_net -net hdmi_rx_0_rx_r [get_bd_pins rx_aud_r] [get_bd_pins hdmi_rx_0/rx_r]
  connect_bd_net -net hdmi_rx_0_rx_samples [get_bd_pins rx_samples] [get_bd_pins hdmi_rx_0/rx_samples]
  connect_bd_net -net hdmi_rx_0_rx_size_h [get_bd_pins rx_size_h] [get_bd_pins hdmi_rx_0/rx_size_h]
  connect_bd_net -net hdmi_rx_0_rx_size_v [get_bd_pins rx_size_v] [get_bd_pins hdmi_rx_0/rx_size_v]
  connect_bd_net -net hdmi_rx_0_rx_status [get_bd_pins rx_status] [get_bd_pins hdmi_rx_0/rx_status]
  connect_bd_net -net hdmi_rx_0_rx_valid [get_bd_pins rx_aud_valid] [get_bd_pins hdmi_rx_0/rx_valid]
  connect_bd_net -net hdmi_rx_0_tx_aud_l [get_bd_pins tx_aud_l] [get_bd_pins hdmi_rx_0/tx_aud_l]
  connect_bd_net -net hdmi_rx_0_tx_aud_r [get_bd_pins tx_aud_r] [get_bd_pins hdmi_rx_0/tx_aud_r]
  connect_bd_net -net hdmi_rx_0_tx_aud_valid [get_bd_pins tx_aud_valid] [get_bd_pins hdmi_rx_0/tx_aud_valid]
  connect_bd_net -net m_axi_s2mm_aclk_0_1 [get_bd_pins m_axi_s2mm_aclk_0] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_vdma_0/m_axi_s2mm_aclk] [get_bd_pins axis_subset_converter_0/aclk]
  connect_bd_net -net pRst_n_1 [get_bd_pins pRst_n] [get_bd_pins dvi2rgb_0/aRst_n] [get_bd_pins dvi2rgb_0/pRst_n]
  connect_bd_net -net rx_ctrl_1 [get_bd_pins rx_ctrl] [get_bd_pins hdmi_rx_0/rx_ctrl]
  connect_bd_net -net s_axi_lite_aclk_0_1 [get_bd_pins s_axi_lite_aclk_0] [get_bd_pins axi_vdma_0/s_axi_lite_aclk]
  connect_bd_net -net s_axis_s2mm_aclk_0_1 [get_bd_pins s_axis_s2mm_aclk_0] [get_bd_pins axi_vdma_0/s_axis_s2mm_aclk] [get_bd_pins v_vid_in_axi4s_0/aclk]
  connect_bd_net -net tx_clk_1 [get_bd_pins tx_clk] [get_bd_pins hdmi_rx_0/tx_clk]
  connect_bd_net -net v_vid_in_axi4s_0_fid [get_bd_pins v_vid_in_axi4s_0/fid] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net v_vid_in_axi4s_0_overflow [get_bd_pins v_vid_in_axi4s_0/overflow] [get_bd_pins xlconcat_0/In2]
  connect_bd_net -net v_vid_in_axi4s_0_underflow [get_bd_pins v_vid_in_axi4s_0/underflow] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins debug] [get_bd_pins xlconcat_0/dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: HDMI_1
proc create_hier_cell_HDMI_1 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_HDMI_1() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE


  # Create pins
  create_bd_pin -dir I -type rst ARESETN
  create_bd_pin -dir O -from 0 -to 0 HDMI_OEN
  create_bd_pin -dir I -from 0 -to 0 In2
  create_bd_pin -dir I -type clk PixelClk
  create_bd_pin -dir I -type clk SerialClk
  create_bd_pin -dir O -type clk TMDS_Clk_n_1
  create_bd_pin -dir O -type clk TMDS_Clk_p_1
  create_bd_pin -dir O -from 2 -to 0 TMDS_Data_n_1
  create_bd_pin -dir O -from 2 -to 0 TMDS_Data_p_1
  create_bd_pin -dir I -type rst aRst_n
  create_bd_pin -dir I active_video_in
  create_bd_pin -dir I -from 15 -to 0 aud_l
  create_bd_pin -dir I -from 15 -to 0 aud_r
  create_bd_pin -dir I aud_valid
  create_bd_pin -dir I -from 31 -to 0 audio_ctrl
  create_bd_pin -dir I -from 31 -to 0 audio_fs_inc
  create_bd_pin -dir I -from 23 -to 0 gPhase
  create_bd_pin -dir I hblank_in
  create_bd_pin -dir I hsync_in
  create_bd_pin -dir I -from 5 -to 0 inIRQ
  create_bd_pin -dir I -type clk m_axis_mm2s_aclk
  create_bd_pin -dir I mm2s_fsync
  create_bd_pin -dir I -from 15 -to 0 osc_phase
  create_bd_pin -dir I -from 15 -to 0 osc_wave
  create_bd_pin -dir O -from 8 -to 0 outIRQ
  create_bd_pin -dir O -from 23 -to 0 pixData
  create_bd_pin -dir I -from 23 -to 0 pixIn1
  create_bd_pin -dir I -from 31 -to 0 regs_fb_ch1
  create_bd_pin -dir I -from 31 -to 0 regs_fb_ch2
  create_bd_pin -dir I -from 31 -to 0 regs_osc_ch1
  create_bd_pin -dir I -from 31 -to 0 regs_osc_ch2
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir I vblank_in
  create_bd_pin -dir O vo_locked
  create_bd_pin -dir O vo_underflow
  create_bd_pin -dir I vsync_in

  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
    CONFIG.S00_HAS_DATA_FIFO {2} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_1


  # Create instance: axi_vdma_0, and set properties
  set axi_vdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0 ]
  set_property -dict [list \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_mm2s_linebuffer_depth {4096} \
    CONFIG.c_mm2s_max_burst_length {16} \
    CONFIG.c_num_fstores {3} \
    CONFIG.c_use_mm2s_fsync {1} \
  ] $axi_vdma_0


  # Create instance: axis_subset_converter_0, and set properties
  set axis_subset_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 axis_subset_converter_0 ]
  set_property -dict [list \
    CONFIG.M_HAS_TKEEP {1} \
    CONFIG.M_HAS_TLAST {1} \
    CONFIG.M_TDATA_NUM_BYTES {3} \
    CONFIG.M_TUSER_WIDTH {1} \
    CONFIG.S_HAS_TKEEP {1} \
    CONFIG.S_HAS_TLAST {1} \
    CONFIG.S_TDATA_NUM_BYTES {4} \
    CONFIG.S_TUSER_WIDTH {1} \
    CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} \
    CONFIG.TKEEP_REMAP {tkeep[2:0]} \
    CONFIG.TLAST_REMAP {tlast[0]} \
    CONFIG.TUSER_REMAP {tuser[0:0]} \
  ] $axis_subset_converter_0


  # Create instance: c_addsub_0, and set properties
  set c_addsub_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_0 ]
  set_property -dict [list \
    CONFIG.AINIT_Value {8000} \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {16} \
    CONFIG.B_Constant {false} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {0000000000000000} \
    CONFIG.B_Width {16} \
    CONFIG.CE {false} \
    CONFIG.Latency {2} \
    CONFIG.Latency_Configuration {Automatic} \
    CONFIG.Out_Width {16} \
  ] $c_addsub_0


  # Create instance: c_addsub_1, and set properties
  set c_addsub_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_1 ]
  set_property -dict [list \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {24} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {000000000000000000000000} \
    CONFIG.B_Width {24} \
    CONFIG.CE {false} \
    CONFIG.Latency {1} \
    CONFIG.Out_Width {24} \
  ] $c_addsub_1


  # Create instance: c_addsub_2, and set properties
  set c_addsub_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_2 ]
  set_property -dict [list \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {24} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {000000000000000000000000} \
    CONFIG.B_Width {24} \
    CONFIG.CE {false} \
    CONFIG.Latency {1} \
    CONFIG.Out_Width {24} \
  ] $c_addsub_2


  # Create instance: c_addsub_3, and set properties
  set c_addsub_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_3 ]
  set_property -dict [list \
    CONFIG.AINIT_Value {8000} \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {16} \
    CONFIG.B_Constant {false} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {0000000000000000} \
    CONFIG.B_Width {16} \
    CONFIG.CE {false} \
    CONFIG.Latency {2} \
    CONFIG.Latency_Configuration {Automatic} \
    CONFIG.Out_Width {16} \
  ] $c_addsub_3


  # Create instance: c_addsub_4, and set properties
  set c_addsub_4 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_4 ]
  set_property -dict [list \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {24} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {000000000000000000000000} \
    CONFIG.B_Width {24} \
    CONFIG.CE {false} \
    CONFIG.Latency {1} \
    CONFIG.Out_Width {24} \
  ] $c_addsub_4


  # Create instance: colorGainFeedback1
  create_hier_cell_colorGainFeedback1 $hier_obj colorGainFeedback1

  # Create instance: colorGainOscPhase
  create_hier_cell_colorGainOscPhase $hier_obj colorGainOscPhase

  # Create instance: colorGainOscSin
  create_hier_cell_colorGainOscSin $hier_obj colorGainOscSin

  # Create instance: div16_8_recip_0, and set properties
  set block_name div16_8_recip
  set block_cell_name div16_8_recip_0
  if { [catch {set div16_8_recip_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $div16_8_recip_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: div16_8_recip_1, and set properties
  set block_name div16_8_recip
  set block_cell_name div16_8_recip_1
  if { [catch {set div16_8_recip_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $div16_8_recip_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: hdmi_tx_0, and set properties
  set block_name hdmi_tx
  set block_cell_name hdmi_tx_0
  if { [catch {set hdmi_tx_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hdmi_tx_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: osc_ce, and set properties
  set osc_ce [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 osc_ce ]
  set_property -dict [list \
    CONFIG.CONST_VAL {1} \
    CONFIG.CONST_WIDTH {1} \
  ] $osc_ce


  # Create instance: v_axi4s_vid_out_0, and set properties
  set v_axi4s_vid_out_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_0 ]
  set_property -dict [list \
    CONFIG.C_ADDR_WIDTH {12} \
    CONFIG.C_HAS_ASYNC_CLK {1} \
    CONFIG.C_VTG_MASTER_SLAVE {1} \
  ] $v_axi4s_vid_out_0


  # Create instance: xlconcat_IRQ, and set properties
  set xlconcat_IRQ [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_IRQ ]
  set_property CONFIG.NUM_PORTS {4} $xlconcat_IRQ


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]
  set_property CONFIG.CONST_VAL {0} $xlconstant_1


  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {24} \
  ] $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {24} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property CONFIG.DIN_FROM {23} $xlslice_2


  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property CONFIG.DIN_FROM {23} $xlslice_3


  # Create instance: xlslice_5, and set properties
  set xlslice_5 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_5 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {16} \
  ] $xlslice_5


  # Create instance: xlslice_6, and set properties
  set xlslice_6 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_6 ]
  set_property CONFIG.DIN_FROM {23} $xlslice_6


  # Create instance: xlslice_7, and set properties
  set xlslice_7 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_7 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {15} \
    CONFIG.DIN_TO {0} \
  ] $xlslice_7


  # Create interface connections
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins M00_AXI1] [get_bd_intf_pins axi_interconnect_1/M00_AXI]
  connect_bd_intf_net -intf_net PS_M02_AXI [get_bd_intf_pins S_AXI_LITE] [get_bd_intf_pins axi_vdma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net axi_vdma_0_M_AXIS_MM2S [get_bd_intf_pins axi_vdma_0/M_AXIS_MM2S] [get_bd_intf_pins axis_subset_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net axi_vdma_0_M_AXI_MM2S [get_bd_intf_pins axi_interconnect_1/S00_AXI] [get_bd_intf_pins axi_vdma_0/M_AXI_MM2S]
  connect_bd_intf_net -intf_net axis_subset_converter_0_M_AXIS [get_bd_intf_pins axis_subset_converter_0/M_AXIS] [get_bd_intf_pins v_axi4s_vid_out_0/video_in]

  # Create port connections
  connect_bd_net -net In2_1 [get_bd_pins In2] [get_bd_pins xlconcat_IRQ/In2]
  connect_bd_net -net Net [get_bd_pins m_axis_mm2s_aclk] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_vdma_0/m_axi_mm2s_aclk] [get_bd_pins axi_vdma_0/m_axis_mm2s_aclk] [get_bd_pins axis_subset_converter_0/aclk] [get_bd_pins v_axi4s_vid_out_0/aclk]
  connect_bd_net -net PS_ARESETN [get_bd_pins s_axi_aresetn] [get_bd_pins axi_vdma_0/axi_resetn]
  connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_vdma_0/s_axi_lite_aclk]
  connect_bd_net -net PixelClk_1 [get_bd_pins PixelClk] [get_bd_pins c_addsub_0/CLK] [get_bd_pins c_addsub_1/CLK] [get_bd_pins c_addsub_2/CLK] [get_bd_pins c_addsub_3/CLK] [get_bd_pins c_addsub_4/CLK] [get_bd_pins colorGainFeedback1/pixClk_in] [get_bd_pins colorGainOscPhase/pixClk_in] [get_bd_pins colorGainOscSin/pixClk_in] [get_bd_pins div16_8_recip_0/clk] [get_bd_pins div16_8_recip_1/clk] [get_bd_pins hdmi_tx_0/PixelClk] [get_bd_pins v_axi4s_vid_out_0/vid_io_out_clk]
  connect_bd_net -net SerialClk_1 [get_bd_pins SerialClk] [get_bd_pins hdmi_tx_0/SerialClk]
  connect_bd_net -net aRst_n_1 [get_bd_pins aRst_n] [get_bd_pins hdmi_tx_0/aRst_n] [get_bd_pins v_axi4s_vid_out_0/aresetn]
  connect_bd_net -net active_video_in_1 [get_bd_pins active_video_in] [get_bd_pins v_axi4s_vid_out_0/vtg_active_video]
  connect_bd_net -net aud_l_1 [get_bd_pins aud_l] [get_bd_pins hdmi_tx_0/aud_l]
  connect_bd_net -net aud_r_1 [get_bd_pins aud_r] [get_bd_pins hdmi_tx_0/aud_r]
  connect_bd_net -net aud_valid_1 [get_bd_pins aud_valid] [get_bd_pins hdmi_tx_0/aud_valid]
  connect_bd_net -net audio_ctrl_1 [get_bd_pins audio_ctrl] [get_bd_pins hdmi_tx_0/ctrl]
  connect_bd_net -net audio_fs_inc_1 [get_bd_pins audio_fs_inc] [get_bd_pins hdmi_tx_0/fs_inc]
  connect_bd_net -net axi_vdma_0_mm2s_introut [get_bd_pins axi_vdma_0/mm2s_introut] [get_bd_pins xlconcat_IRQ/In1]
  connect_bd_net -net c_addsub_0_S [get_bd_pins c_addsub_0/S] [get_bd_pins colorGainOscSin/Din1]
  connect_bd_net -net c_addsub_1_S [get_bd_pins c_addsub_1/S] [get_bd_pins c_addsub_2/A]
  connect_bd_net -net c_addsub_2_S [get_bd_pins pixData] [get_bd_pins c_addsub_2/S] [get_bd_pins hdmi_tx_0/vid_pData]
  connect_bd_net -net c_addsub_3_S [get_bd_pins c_addsub_3/S] [get_bd_pins colorGainOscPhase/Din1]
  connect_bd_net -net c_addsub_4_S [get_bd_pins c_addsub_2/B] [get_bd_pins c_addsub_4/S]
  connect_bd_net -net colorGainFeedback1_dout0 [get_bd_pins c_addsub_1/A] [get_bd_pins colorGainFeedback1/dout0]
  connect_bd_net -net colorGainFeedback1_dout1 [get_bd_pins c_addsub_1/B] [get_bd_pins colorGainFeedback1/dout1]
  connect_bd_net -net colorGainMain_dout1 [get_bd_pins c_addsub_4/B] [get_bd_pins colorGainOscSin/dout0]
  connect_bd_net -net colorGainOscPhase_dout0 [get_bd_pins c_addsub_4/A] [get_bd_pins colorGainOscPhase/dout0]
  connect_bd_net -net div16_8_recip_0_quot [get_bd_pins c_addsub_0/A] [get_bd_pins div16_8_recip_0/quot]
  connect_bd_net -net div16_8_recip_1_quot [get_bd_pins c_addsub_3/A] [get_bd_pins div16_8_recip_1/quot]
  connect_bd_net -net gPhase_1 [get_bd_pins gPhase] [get_bd_pins colorGainOscPhase/Din0]
  connect_bd_net -net hblank_in_1 [get_bd_pins hblank_in] [get_bd_pins v_axi4s_vid_out_0/vtg_hblank]
  connect_bd_net -net hsync_in_1 [get_bd_pins hsync_in] [get_bd_pins v_axi4s_vid_out_0/vtg_hsync]
  connect_bd_net -net inIRQ_1 [get_bd_pins inIRQ] [get_bd_pins xlconcat_IRQ/In3]
  connect_bd_net -net mm2s_fsync_1 [get_bd_pins mm2s_fsync] [get_bd_pins axi_vdma_0/mm2s_fsync]
  connect_bd_net -net osc_ce_dout [get_bd_pins div16_8_recip_0/ce] [get_bd_pins div16_8_recip_1/ce] [get_bd_pins osc_ce/dout]
  connect_bd_net -net osc_phase_1 [get_bd_pins osc_phase] [get_bd_pins div16_8_recip_1/num]
  connect_bd_net -net osc_wave_1 [get_bd_pins osc_wave] [get_bd_pins div16_8_recip_0/num]
  connect_bd_net -net pixIn1_1 [get_bd_pins pixIn1] [get_bd_pins colorGainFeedback1/Din1]
  connect_bd_net -net regs_fb_ch1_1 [get_bd_pins regs_fb_ch1] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_2/Din]
  connect_bd_net -net regs_fb_ch2_1 [get_bd_pins regs_fb_ch2] [get_bd_pins xlslice_3/Din]
  connect_bd_net -net regs_osc_ch1_1 [get_bd_pins regs_osc_ch1] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_6/Din]
  connect_bd_net -net regs_osc_ch2_1 [get_bd_pins regs_osc_ch2] [get_bd_pins xlslice_5/Din] [get_bd_pins xlslice_7/Din]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_n [get_bd_pins TMDS_Clk_n_1] [get_bd_pins hdmi_tx_0/TMDS_Clk_n]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_p [get_bd_pins TMDS_Clk_p_1] [get_bd_pins hdmi_tx_0/TMDS_Clk_p]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_n [get_bd_pins TMDS_Data_n_1] [get_bd_pins hdmi_tx_0/TMDS_Data_n]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_p [get_bd_pins TMDS_Data_p_1] [get_bd_pins hdmi_tx_0/TMDS_Data_p]
  connect_bd_net -net rst_ps7_0_140M_peripheral_aresetn [get_bd_pins ARESETN] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axis_subset_converter_0/aresetn]
  connect_bd_net -net v_axi4s_vid_out_0_locked [get_bd_pins vo_locked] [get_bd_pins v_axi4s_vid_out_0/locked]
  connect_bd_net -net v_axi4s_vid_out_0_underflow [get_bd_pins vo_underflow] [get_bd_pins v_axi4s_vid_out_0/underflow]
  connect_bd_net -net v_axi4s_vid_out_0_vid_active_video [get_bd_pins hdmi_tx_0/vid_pVDE] [get_bd_pins v_axi4s_vid_out_0/vid_active_video]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data [get_bd_pins colorGainFeedback1/Din0] [get_bd_pins v_axi4s_vid_out_0/vid_data]
  connect_bd_net -net v_axi4s_vid_out_0_vid_hsync [get_bd_pins hdmi_tx_0/vid_pHSync] [get_bd_pins v_axi4s_vid_out_0/vid_hsync]
  connect_bd_net -net v_axi4s_vid_out_0_vid_vsync [get_bd_pins hdmi_tx_0/vid_pVSync] [get_bd_pins v_axi4s_vid_out_0/vid_vsync]
  connect_bd_net -net vblank_in_1 [get_bd_pins vblank_in] [get_bd_pins v_axi4s_vid_out_0/vtg_vblank]
  connect_bd_net -net vsync_in_1 [get_bd_pins vsync_in] [get_bd_pins v_axi4s_vid_out_0/vtg_vsync]
  connect_bd_net -net xlconcat_IRQ_dout [get_bd_pins outIRQ] [get_bd_pins xlconcat_IRQ/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins HDMI_OEN] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins xlconcat_IRQ/In0] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins div16_8_recip_0/den] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins div16_8_recip_1/den] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins colorGainFeedback1/Din2] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins colorGainFeedback1/Din] [get_bd_pins xlslice_3/Dout]
  connect_bd_net -net xlslice_5_Dout [get_bd_pins c_addsub_3/B] [get_bd_pins xlslice_5/Dout]
  connect_bd_net -net xlslice_6_Dout [get_bd_pins colorGainOscSin/Din0] [get_bd_pins xlslice_6/Dout]
  connect_bd_net -net xlslice_7_Dout [get_bd_pins c_addsub_0/B] [get_bd_pins xlslice_7/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}

# Hierarchical cell: HDMI_0
proc create_hier_cell_HDMI_0 { parentCell nameHier } {

  variable script_folder

  if { $parentCell eq "" || $nameHier eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2092 -severity "ERROR" "create_hier_cell_HDMI_0() - Empty argument(s)!"}
     return
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj

  # Create cell and set as current instance
  set hier_obj [create_bd_cell -type hier $nameHier]
  current_bd_instance $hier_obj

  # Create interface pins
  create_bd_intf_pin -mode Master -vlnv xilinx.com:interface:aximm_rtl:1.0 M00_AXI1

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE_MIXER_0

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 S_AXI_LITE_VDMA

  create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:aximm_rtl:1.0 ctrl


  # Create pins
  create_bd_pin -dir I -type rst ARESETN
  create_bd_pin -dir O -from 0 -to 0 HDMI_OEN
  create_bd_pin -dir I -from 0 -to 0 In2
  create_bd_pin -dir I -from 0 -to 0 -type intr In3
  create_bd_pin -dir I -from 0 -to 0 -type intr In4
  create_bd_pin -dir I -type intr In5
  create_bd_pin -dir I -type clk PixelClk
  create_bd_pin -dir I SerialClk
  create_bd_pin -dir O TMDS_Clk_n_0
  create_bd_pin -dir O TMDS_Clk_p_0
  create_bd_pin -dir O -from 2 -to 0 TMDS_Data_n_0
  create_bd_pin -dir O -from 2 -to 0 TMDS_Data_p_0
  create_bd_pin -dir I -type rst aRst_n
  create_bd_pin -dir O active_video_out
  create_bd_pin -dir I -from 15 -to 0 aud_l
  create_bd_pin -dir I -from 15 -to 0 aud_r
  create_bd_pin -dir I aud_valid
  create_bd_pin -dir I -from 31 -to 0 audio_ctrl
  create_bd_pin -dir I -from 31 -to 0 audio_fs_inc
  create_bd_pin -dir I -from 7 -to 0 dds_phase_div_den_0
  create_bd_pin -dir O -from 5 -to 0 dout
  create_bd_pin -dir O hblank_out
  create_bd_pin -dir O hsync_out
  create_bd_pin -dir I -type clk m_axis_mm2s_aclk
  create_bd_pin -dir I mm2s_fsync
  create_bd_pin -dir I -from 15 -to 0 osc_phase
  create_bd_pin -dir I -from 15 -to 0 osc_wave
  create_bd_pin -dir O -from 23 -to 0 pixData
  create_bd_pin -dir I -from 23 -to 0 pixIn
  create_bd_pin -dir I -from 31 -to 0 regs_main_ch1
  create_bd_pin -dir I -from 31 -to 0 regs_main_ch2
  create_bd_pin -dir I -type clk s_axi_aclk
  create_bd_pin -dir I -type rst s_axi_aresetn
  create_bd_pin -dir O vblank_out
  create_bd_pin -dir O vo_locked
  create_bd_pin -dir O vo_underflow
  create_bd_pin -dir O vsync_out

  # Create instance: axi_interconnect_1, and set properties
  set axi_interconnect_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 axi_interconnect_1 ]
  set_property -dict [list \
    CONFIG.NUM_MI {1} \
    CONFIG.NUM_SI {1} \
    CONFIG.S00_HAS_DATA_FIFO {2} \
    CONFIG.S00_HAS_REGSLICE {4} \
  ] $axi_interconnect_1


  # Create instance: axi_vdma_0, and set properties
  set axi_vdma_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_vdma:6.3 axi_vdma_0 ]
  set_property -dict [list \
    CONFIG.c_include_s2mm {0} \
    CONFIG.c_m_axis_mm2s_tdata_width {32} \
    CONFIG.c_mm2s_linebuffer_depth {4096} \
    CONFIG.c_mm2s_max_burst_length {16} \
    CONFIG.c_num_fstores {3} \
    CONFIG.c_use_mm2s_fsync {1} \
  ] $axi_vdma_0


  # Create instance: axis_subset_converter_0, and set properties
  set axis_subset_converter_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:axis_subset_converter:1.1 axis_subset_converter_0 ]
  set_property -dict [list \
    CONFIG.M_HAS_TKEEP {1} \
    CONFIG.M_HAS_TLAST {1} \
    CONFIG.M_TDATA_NUM_BYTES {3} \
    CONFIG.M_TUSER_WIDTH {1} \
    CONFIG.S_HAS_TKEEP {1} \
    CONFIG.S_HAS_TLAST {1} \
    CONFIG.S_TDATA_NUM_BYTES {4} \
    CONFIG.S_TUSER_WIDTH {1} \
    CONFIG.TDATA_REMAP {tdata[23:16],tdata[7:0],tdata[15:8]} \
    CONFIG.TKEEP_REMAP {tkeep[2:0]} \
    CONFIG.TLAST_REMAP {tlast[0]} \
    CONFIG.TUSER_REMAP {tuser[0:0]} \
  ] $axis_subset_converter_0


  # Create instance: blk_mem_gen_0, and set properties
  set blk_mem_gen_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 blk_mem_gen_0 ]
  set_property -dict [list \
    CONFIG.Algorithm {Minimum_Area} \
    CONFIG.Assume_Synchronous_Clk {true} \
    CONFIG.Enable_A {Always_Enabled} \
    CONFIG.Enable_B {Always_Enabled} \
    CONFIG.Fill_Remaining_Memory_Locations {true} \
    CONFIG.Memory_Type {Simple_Dual_Port_RAM} \
    CONFIG.Operating_Mode_A {READ_FIRST} \
    CONFIG.Write_Depth_A {16384} \
    CONFIG.Write_Width_A {24} \
    CONFIG.use_bram_block {Stand_Alone} \
  ] $blk_mem_gen_0


  # Create instance: c_addsub_0, and set properties
  set c_addsub_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_0 ]
  set_property -dict [list \
    CONFIG.AINIT_Value {8000} \
    CONFIG.A_Type {Signed} \
    CONFIG.A_Width {16} \
    CONFIG.B_Constant {false} \
    CONFIG.B_Type {Signed} \
    CONFIG.B_Value {0000000000000000} \
    CONFIG.B_Width {16} \
    CONFIG.CE {false} \
    CONFIG.Latency {2} \
    CONFIG.Latency_Configuration {Automatic} \
    CONFIG.Out_Width {16} \
  ] $c_addsub_0


  # Create instance: c_addsub_1, and set properties
  set c_addsub_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_addsub:12.0 c_addsub_1 ]
  set_property -dict [list \
    CONFIG.A_Width {14} \
    CONFIG.B_Value {00000000000000} \
    CONFIG.B_Width {14} \
    CONFIG.CE {false} \
    CONFIG.Latency {0} \
    CONFIG.Out_Width {14} \
  ] $c_addsub_1


  # Create instance: c_counter_binary_0, and set properties
  set c_counter_binary_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:c_counter_binary:12.0 c_counter_binary_0 ]
  set_property CONFIG.Output_Width {14} $c_counter_binary_0


  # Create instance: colorGainMain
  create_hier_cell_colorGainMain $hier_obj colorGainMain

  # Create instance: div16_8_recip_0, and set properties
  set block_name div16_8_recip
  set block_cell_name div16_8_recip_0
  if { [catch {set div16_8_recip_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $div16_8_recip_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: div16_8_recip_1, and set properties
  set block_name div16_8_recip
  set block_cell_name div16_8_recip_1
  if { [catch {set div16_8_recip_1 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $div16_8_recip_1 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: hdmi_tx_0, and set properties
  set block_name hdmi_tx
  set block_cell_name hdmi_tx_0
  if { [catch {set hdmi_tx_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hdmi_tx_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: mixerMatrix
  create_hier_cell_mixerMatrix $hier_obj mixerMatrix

  # Create instance: osc_ce, and set properties
  set osc_ce [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 osc_ce ]
  set_property -dict [list \
    CONFIG.CONST_VAL {1} \
    CONFIG.CONST_WIDTH {1} \
  ] $osc_ce


  # Create instance: v_axi4s_vid_out_0, and set properties
  set v_axi4s_vid_out_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_axi4s_vid_out:4.0 v_axi4s_vid_out_0 ]
  set_property -dict [list \
    CONFIG.C_ADDR_WIDTH {12} \
    CONFIG.C_HAS_ASYNC_CLK {1} \
    CONFIG.C_VTG_MASTER_SLAVE {1} \
  ] $v_axi4s_vid_out_0


  # Create instance: v_tc_0, and set properties
  set v_tc_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:v_tc:6.2 v_tc_0 ]
  set_property CONFIG.enable_detection {false} $v_tc_0


  # Create instance: xlconcat_IRQ, and set properties
  set xlconcat_IRQ [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_IRQ ]
  set_property CONFIG.NUM_PORTS {6} $xlconcat_IRQ


  # Create instance: xlconstant_0, and set properties
  set xlconstant_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_0 ]

  # Create instance: xlconstant_1, and set properties
  set xlconstant_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 xlconstant_1 ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property CONFIG.DIN_FROM {23} $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {24} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property CONFIG.DIN_FROM {15} $xlslice_2


  # Create instance: xlslice_3, and set properties
  set xlslice_3 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_3 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {16} \
  ] $xlslice_3


  # Create interface connections
  connect_bd_intf_net -intf_net Conn2 [get_bd_intf_pins M00_AXI1] [get_bd_intf_pins axi_interconnect_1/M00_AXI]
  connect_bd_intf_net -intf_net PS_M02_AXI [get_bd_intf_pins S_AXI_LITE_VDMA] [get_bd_intf_pins axi_vdma_0/S_AXI_LITE]
  connect_bd_intf_net -intf_net PS_M06_AXI [get_bd_intf_pins ctrl] [get_bd_intf_pins v_tc_0/ctrl]
  connect_bd_intf_net -intf_net S_AXI_LITE_MIXER_0_1 [get_bd_intf_pins S_AXI_LITE_MIXER_0] [get_bd_intf_pins mixerMatrix/S_AXI_LITE_MIXER_0]
  connect_bd_intf_net -intf_net axi_vdma_0_M_AXIS_MM2S [get_bd_intf_pins axi_vdma_0/M_AXIS_MM2S] [get_bd_intf_pins axis_subset_converter_0/S_AXIS]
  connect_bd_intf_net -intf_net axi_vdma_0_M_AXI_MM2S [get_bd_intf_pins axi_interconnect_1/S00_AXI] [get_bd_intf_pins axi_vdma_0/M_AXI_MM2S]
  connect_bd_intf_net -intf_net axis_subset_converter_0_M_AXIS [get_bd_intf_pins axis_subset_converter_0/M_AXIS] [get_bd_intf_pins v_axi4s_vid_out_0/video_in]

  # Create port connections
  connect_bd_net -net Din_1 [get_bd_pins colorGainMain/Din] [get_bd_pins mixerMatrix/dout]
  connect_bd_net -net In2_1 [get_bd_pins In2] [get_bd_pins xlconcat_IRQ/In2]
  connect_bd_net -net In3_1 [get_bd_pins In3] [get_bd_pins xlconcat_IRQ/In3]
  connect_bd_net -net In4_1 [get_bd_pins In4] [get_bd_pins xlconcat_IRQ/In4]
  connect_bd_net -net In5_1 [get_bd_pins In5] [get_bd_pins xlconcat_IRQ/In5]
  connect_bd_net -net Net [get_bd_pins m_axis_mm2s_aclk] [get_bd_pins axi_interconnect_1/ACLK] [get_bd_pins axi_interconnect_1/M00_ACLK] [get_bd_pins axi_interconnect_1/S00_ACLK] [get_bd_pins axi_vdma_0/m_axi_mm2s_aclk] [get_bd_pins axi_vdma_0/m_axis_mm2s_aclk] [get_bd_pins axis_subset_converter_0/aclk] [get_bd_pins v_axi4s_vid_out_0/aclk]
  connect_bd_net -net PS_ARESETN [get_bd_pins s_axi_aresetn] [get_bd_pins axi_vdma_0/axi_resetn] [get_bd_pins mixerMatrix/s_axi_aresetn] [get_bd_pins v_tc_0/s_axi_aresetn]
  connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins s_axi_aclk] [get_bd_pins axi_vdma_0/s_axi_lite_aclk] [get_bd_pins div16_8_recip_0/clk] [get_bd_pins div16_8_recip_1/clk] [get_bd_pins mixerMatrix/s_axi_aclk] [get_bd_pins v_tc_0/s_axi_aclk]
  connect_bd_net -net SerialClk_1 [get_bd_pins SerialClk] [get_bd_pins hdmi_tx_0/SerialClk]
  connect_bd_net -net aRst_n_1 [get_bd_pins aRst_n] [get_bd_pins blk_mem_gen_0/wea] [get_bd_pins hdmi_tx_0/aRst_n] [get_bd_pins v_axi4s_vid_out_0/aresetn]
  connect_bd_net -net aud_l_1 [get_bd_pins aud_l] [get_bd_pins hdmi_tx_0/aud_l]
  connect_bd_net -net aud_r_1 [get_bd_pins aud_r] [get_bd_pins hdmi_tx_0/aud_r]
  connect_bd_net -net aud_valid_1 [get_bd_pins aud_valid] [get_bd_pins hdmi_tx_0/aud_valid]
  connect_bd_net -net audio_ctrl_1 [get_bd_pins audio_ctrl] [get_bd_pins hdmi_tx_0/ctrl]
  connect_bd_net -net audio_fs_inc_1 [get_bd_pins audio_fs_inc] [get_bd_pins hdmi_tx_0/fs_inc]
  connect_bd_net -net axi_dynclk_0_PXL_CLK_O [get_bd_pins PixelClk] [get_bd_pins blk_mem_gen_0/clka] [get_bd_pins blk_mem_gen_0/clkb] [get_bd_pins c_addsub_0/CLK] [get_bd_pins c_counter_binary_0/CLK] [get_bd_pins colorGainMain/pixClk_in] [get_bd_pins hdmi_tx_0/PixelClk] [get_bd_pins mixerMatrix/PixelClk] [get_bd_pins v_axi4s_vid_out_0/vid_io_out_clk] [get_bd_pins v_tc_0/clk]
  connect_bd_net -net axi_vdma_0_mm2s_introut [get_bd_pins axi_vdma_0/mm2s_introut] [get_bd_pins xlconcat_IRQ/In1]
  connect_bd_net -net blk_mem_gen_0_doutb [get_bd_pins blk_mem_gen_0/doutb] [get_bd_pins mixerMatrix/din3]
  connect_bd_net -net c_addsub_0_S [get_bd_pins c_addsub_0/S] [get_bd_pins mixerMatrix/din1]
  connect_bd_net -net c_addsub_1_S [get_bd_pins blk_mem_gen_0/addrb] [get_bd_pins c_addsub_1/S]
  connect_bd_net -net colorGain_dout [get_bd_pins pixData] [get_bd_pins colorGainMain/dout] [get_bd_pins hdmi_tx_0/vid_pData]
  connect_bd_net -net counter26_0_count [get_bd_pins blk_mem_gen_0/addra] [get_bd_pins c_addsub_1/A] [get_bd_pins c_counter_binary_0/Q]
  connect_bd_net -net den_0_1 [get_bd_pins dds_phase_div_den_0] [get_bd_pins div16_8_recip_1/den]
  connect_bd_net -net div16_8_recip_0_quot [get_bd_pins c_addsub_0/A] [get_bd_pins div16_8_recip_0/quot]
  connect_bd_net -net div16_8_recip_1_quot [get_bd_pins div16_8_recip_1/quot] [get_bd_pins mixerMatrix/din4]
  connect_bd_net -net mm2s_fsync_1 [get_bd_pins mm2s_fsync] [get_bd_pins axi_vdma_0/mm2s_fsync]
  connect_bd_net -net osc_ce_dout [get_bd_pins div16_8_recip_0/ce] [get_bd_pins div16_8_recip_1/ce] [get_bd_pins osc_ce/dout]
  connect_bd_net -net osc_phase_1 [get_bd_pins osc_phase] [get_bd_pins div16_8_recip_1/num]
  connect_bd_net -net osc_wave_1 [get_bd_pins osc_wave] [get_bd_pins div16_8_recip_0/num]
  connect_bd_net -net pixIn_1 [get_bd_pins pixIn] [get_bd_pins blk_mem_gen_0/dina] [get_bd_pins mixerMatrix/din0]
  connect_bd_net -net regs_main_ch1_1 [get_bd_pins regs_main_ch1] [get_bd_pins xlslice_0/Din] [get_bd_pins xlslice_1/Din]
  connect_bd_net -net regs_main_ch2_1 [get_bd_pins regs_main_ch2] [get_bd_pins xlslice_2/Din] [get_bd_pins xlslice_3/Din]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_n [get_bd_pins TMDS_Clk_n_0] [get_bd_pins hdmi_tx_0/TMDS_Clk_n]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_p [get_bd_pins TMDS_Clk_p_0] [get_bd_pins hdmi_tx_0/TMDS_Clk_p]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_n [get_bd_pins TMDS_Data_n_0] [get_bd_pins hdmi_tx_0/TMDS_Data_n]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_p [get_bd_pins TMDS_Data_p_0] [get_bd_pins hdmi_tx_0/TMDS_Data_p]
  connect_bd_net -net rst_ps7_0_140M_peripheral_aresetn [get_bd_pins ARESETN] [get_bd_pins axi_interconnect_1/ARESETN] [get_bd_pins axi_interconnect_1/M00_ARESETN] [get_bd_pins axi_interconnect_1/S00_ARESETN] [get_bd_pins axis_subset_converter_0/aresetn]
  connect_bd_net -net v_axi4s_vid_out_0_locked [get_bd_pins vo_locked] [get_bd_pins v_axi4s_vid_out_0/locked]
  connect_bd_net -net v_axi4s_vid_out_0_underflow [get_bd_pins vo_underflow] [get_bd_pins v_axi4s_vid_out_0/underflow]
  connect_bd_net -net v_axi4s_vid_out_0_vid_active_video [get_bd_pins hdmi_tx_0/vid_pVDE] [get_bd_pins v_axi4s_vid_out_0/vid_active_video]
  connect_bd_net -net v_axi4s_vid_out_0_vid_data [get_bd_pins mixerMatrix/pixIn0] [get_bd_pins v_axi4s_vid_out_0/vid_data]
  connect_bd_net -net v_axi4s_vid_out_0_vid_hsync [get_bd_pins hdmi_tx_0/vid_pHSync] [get_bd_pins v_axi4s_vid_out_0/vid_hsync]
  connect_bd_net -net v_axi4s_vid_out_0_vid_vsync [get_bd_pins hdmi_tx_0/vid_pVSync] [get_bd_pins v_axi4s_vid_out_0/vid_vsync]
  connect_bd_net -net v_tc_0_active_video_out [get_bd_pins active_video_out] [get_bd_pins v_axi4s_vid_out_0/vtg_active_video] [get_bd_pins v_tc_0/active_video_out]
  connect_bd_net -net v_tc_0_hblank_out [get_bd_pins hblank_out] [get_bd_pins v_axi4s_vid_out_0/vtg_hblank] [get_bd_pins v_tc_0/hblank_out]
  connect_bd_net -net v_tc_0_hsync_out [get_bd_pins hsync_out] [get_bd_pins v_axi4s_vid_out_0/vtg_hsync] [get_bd_pins v_tc_0/hsync_out]
  connect_bd_net -net v_tc_0_irq [get_bd_pins v_tc_0/irq] [get_bd_pins xlconcat_IRQ/In0]
  connect_bd_net -net v_tc_0_vblank_out [get_bd_pins vblank_out] [get_bd_pins v_axi4s_vid_out_0/vtg_vblank] [get_bd_pins v_tc_0/vblank_out]
  connect_bd_net -net v_tc_0_vsync_out [get_bd_pins vsync_out] [get_bd_pins v_axi4s_vid_out_0/vtg_vsync] [get_bd_pins v_tc_0/vsync_out]
  connect_bd_net -net xlconcat_IRQ_dout [get_bd_pins dout] [get_bd_pins xlconcat_IRQ/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_pins HDMI_OEN] [get_bd_pins xlconstant_0/dout]
  connect_bd_net -net xlconstant_1_dout [get_bd_pins v_tc_0/gen_clken] [get_bd_pins xlconstant_1/dout]
  connect_bd_net -net xlslice_0_Dout [get_bd_pins colorGainMain/Din1] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins div16_8_recip_0/den] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins c_addsub_0/B] [get_bd_pins xlslice_2/Dout]
  connect_bd_net -net xlslice_3_Dout [get_bd_pins c_addsub_1/B] [get_bd_pins xlslice_3/Dout]

  # Restore current instance
  current_bd_instance $oldCurInst
}


# Procedure to create entire design; Provide argument to make
# procedure reusable. If parentCell is "", will use root.
proc create_root_design { parentCell } {

  variable script_folder
  variable design_name

  if { $parentCell eq "" } {
     set parentCell [get_bd_cells /]
  }

  # Get object for parentCell
  set parentObj [get_bd_cells $parentCell]
  if { $parentObj == "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2090 -severity "ERROR" "Unable to find parent cell <$parentCell>!"}
     return
  }

  # Make sure parentObj is hier blk
  set parentType [get_property TYPE $parentObj]
  if { $parentType ne "hier" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2091 -severity "ERROR" "Parent <$parentObj> has TYPE = <$parentType>. Expected to be <hier>."}
     return
  }

  # Save current instance; Restore later
  set oldCurInst [current_bd_instance .]

  # Set parent object as current
  current_bd_instance $parentObj


  # Create interface ports
  set DDC_2 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:iic_rtl:1.0 DDC_2 ]

  set DDR [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:ddrx_rtl:1.0 DDR ]

  set FIXED_IO [ create_bd_intf_port -mode Master -vlnv xilinx.com:display_processing_system7:fixedio_rtl:1.0 FIXED_IO ]

  set MDIO_ETHERNET_0_0 [ create_bd_intf_port -mode Master -vlnv xilinx.com:interface:mdio_rtl:1.0 MDIO_ETHERNET_0_0 ]


  # Create ports
  set AUDIO_L [ create_bd_port -dir IO AUDIO_L ]
  set AUDIO_R [ create_bd_port -dir IO AUDIO_R ]
  set CLK25M [ create_bd_port -dir O -type clk CLK25M ]
  set_property -dict [ list \
   CONFIG.FREQ_HZ {25000000} \
 ] $CLK25M
  set ENET0_GMII_RX_CLK_0 [ create_bd_port -dir I -type clk -freq_hz 25000000 ENET0_GMII_RX_CLK_0 ]
  set ENET0_GMII_RX_DV_0 [ create_bd_port -dir I ENET0_GMII_RX_DV_0 ]
  set ENET0_GMII_TX_CLK_0 [ create_bd_port -dir I -type clk -freq_hz 25000000 ENET0_GMII_TX_CLK_0 ]
  set ENET0_GMII_TX_EN_0 [ create_bd_port -dir O -from 0 -to 0 ENET0_GMII_TX_EN_0 ]
  set HDMI_CEC_0 [ create_bd_port -dir O -from 0 -to 0 HDMI_CEC_0 ]
  set HDMI_CEC_1 [ create_bd_port -dir O -from 0 -to 0 HDMI_CEC_1 ]
  set HDMI_HPD [ create_bd_port -dir I -from 1 -to 0 HDMI_HPD ]
  set HDMI_HPD_2 [ create_bd_port -dir O -from 0 -to 0 HDMI_HPD_2 ]
  set J3P3_INPUT [ create_bd_port -dir I J3P3_INPUT ]
  set J3P4_OUTPUT [ create_bd_port -dir O J3P4_OUTPUT ]
  set J5P3_INPUT [ create_bd_port -dir I J5P3_INPUT ]
  set J5P4_OUTPUT [ create_bd_port -dir O J5P4_OUTPUT ]
  set LED_GREEN [ create_bd_port -dir O -from 0 -to 0 LED_GREEN ]
  set LED_RED [ create_bd_port -dir O -from 0 -to 0 LED_RED ]
  set PL_KEY [ create_bd_port -dir IO -from 3 -to 0 PL_KEY ]
  set TMDS_Clk_n_0 [ create_bd_port -dir O TMDS_Clk_n_0 ]
  set TMDS_Clk_n_1 [ create_bd_port -dir O TMDS_Clk_n_1 ]
  set TMDS_Clk_n_2 [ create_bd_port -dir I TMDS_Clk_n_2 ]
  set TMDS_Clk_p_0 [ create_bd_port -dir O TMDS_Clk_p_0 ]
  set TMDS_Clk_p_1 [ create_bd_port -dir O TMDS_Clk_p_1 ]
  set TMDS_Clk_p_2 [ create_bd_port -dir I TMDS_Clk_p_2 ]
  set TMDS_Data_n_0 [ create_bd_port -dir O -from 2 -to 0 TMDS_Data_n_0 ]
  set TMDS_Data_n_1 [ create_bd_port -dir O -from 2 -to 0 TMDS_Data_n_1 ]
  set TMDS_Data_n_2 [ create_bd_port -dir I -from 2 -to 0 TMDS_Data_n_2 ]
  set TMDS_Data_p_0 [ create_bd_port -dir O -from 2 -to 0 TMDS_Data_p_0 ]
  set TMDS_Data_p_1 [ create_bd_port -dir O -from 2 -to 0 TMDS_Data_p_1 ]
  set TMDS_Data_p_2 [ create_bd_port -dir I -from 2 -to 0 TMDS_Data_p_2 ]
  set enet0_gmii_rxd [ create_bd_port -dir I -from 3 -to 0 enet0_gmii_rxd ]
  set enet0_gmii_txd [ create_bd_port -dir O -from 3 -to 0 enet0_gmii_txd ]

  # Create instance: HDMI_0
  create_hier_cell_HDMI_0 [current_bd_instance .] HDMI_0

  # Create instance: HDMI_1
  create_hier_cell_HDMI_1 [current_bd_instance .] HDMI_1

  # Create instance: HDMI_2
  create_hier_cell_HDMI_2 [current_bd_instance .] HDMI_2

  # Create instance: PS
  create_hier_cell_PS [current_bd_instance .] PS

  # Create instance: axi_dynclk_0, and set properties
  set axi_dynclk_0 [ create_bd_cell -type ip -vlnv digilentinc.com:ip:axi_dynclk:1.2 axi_dynclk_0 ]

  # Create instance: dz_osc2_0, and set properties
  set block_name dz_osc2
  set block_cell_name dz_osc2_0
  if { [catch {set dz_osc2_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $dz_osc2_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: dz_regs_0, and set properties
  set block_name dz_regs
  set block_cell_name dz_regs_0
  if { [catch {set dz_regs_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $dz_regs_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: fsync_gen_0, and set properties
  set block_name fsync_gen
  set block_cell_name fsync_gen_0
  if { [catch {set fsync_gen_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $fsync_gen_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: hdmi_audio_regs_0, and set properties
  set block_name hdmi_audio_regs
  set block_cell_name hdmi_audio_regs_0
  if { [catch {set hdmi_audio_regs_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $hdmi_audio_regs_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: osc_trig_0, and set properties
  set osc_trig_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 osc_trig_0 ]
  set_property -dict [list \
    CONFIG.CONST_VAL {0} \
    CONFIG.CONST_WIDTH {1} \
  ] $osc_trig_0


  # Create instance: pl_io_0, and set properties
  set block_name pl_io
  set block_cell_name pl_io_0
  if { [catch {set pl_io_0 [create_bd_cell -type module -reference $block_name $block_cell_name] } errmsg] } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2095 -severity "ERROR" "Unable to add referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   } elseif { $pl_io_0 eq "" } {
     catch {common::send_gid_msg -ssname BD::TCL -id 2096 -severity "ERROR" "Unable to referenced block <$block_name>. Please add the files for ${block_name}'s definition into the project."}
     return 1
   }
  
  # Create instance: ps7_axi_periph, and set properties
  set ps7_axi_periph [ create_bd_cell -type ip -vlnv xilinx.com:ip:axi_interconnect:2.1 ps7_axi_periph ]
  set_property -dict [list \
    CONFIG.ENABLE_ADVANCED_OPTIONS {0} \
    CONFIG.NUM_MI {9} \
    CONFIG.NUM_SI {1} \
    CONFIG.S00_HAS_REGSLICE {4} \
    CONFIG.STRATEGY {1} \
  ] $ps7_axi_periph


  # Create instance: xlconcat_0, and set properties
  set xlconcat_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_0 ]
  set_property -dict [list \
    CONFIG.IN0_WIDTH {8} \
    CONFIG.NUM_PORTS {5} \
  ] $xlconcat_0


  # Create instance: xlconcat_1, and set properties
  set xlconcat_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_1 ]

  # Create instance: xlconcat_2, and set properties
  set xlconcat_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlconcat:2.1 xlconcat_2 ]

  # Create instance: xlslice_0, and set properties
  set xlslice_0 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_0 ]
  set_property CONFIG.DIN_WIDTH {4} $xlslice_0


  # Create instance: xlslice_1, and set properties
  set xlslice_1 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_1 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {31} \
    CONFIG.DIN_TO {24} \
  ] $xlslice_1


  # Create instance: xlslice_2, and set properties
  set xlslice_2 [ create_bd_cell -type ip -vlnv xilinx.com:ip:xlslice:1.0 xlslice_2 ]
  set_property -dict [list \
    CONFIG.DIN_FROM {23} \
    CONFIG.DIN_TO {0} \
  ] $xlslice_2


  # Create interface connections
  connect_bd_intf_net -intf_net HDMI_1_M00_AXI1 [get_bd_intf_pins HDMI_1/M00_AXI1] [get_bd_intf_pins PS/S_AXI_HP2]
  connect_bd_intf_net -intf_net HDMI_2_DDC_2 [get_bd_intf_ports DDC_2] [get_bd_intf_pins HDMI_2/DDC_2]
  connect_bd_intf_net -intf_net S00_AXI_2 [get_bd_intf_pins PS/M_AXI_GP0] [get_bd_intf_pins ps7_axi_periph/S00_AXI]
  connect_bd_intf_net -intf_net S_AXI_HP0_1 [get_bd_intf_pins HDMI_0/M00_AXI1] [get_bd_intf_pins PS/S_AXI_HP0]
  connect_bd_intf_net -intf_net S_AXI_HP1_1 [get_bd_intf_pins HDMI_2/M00_AXI_0] [get_bd_intf_pins PS/S_AXI_HP1]
  connect_bd_intf_net -intf_net S_AXI_LITE_0_1 [get_bd_intf_pins HDMI_2/S_AXI_LITE_0] [get_bd_intf_pins ps7_axi_periph/M03_AXI]
  connect_bd_intf_net -intf_net S_AXI_LITE_1 [get_bd_intf_pins HDMI_0/S_AXI_LITE_VDMA] [get_bd_intf_pins ps7_axi_periph/M02_AXI]
  connect_bd_intf_net -intf_net processing_system7_0_DDR [get_bd_intf_ports DDR] [get_bd_intf_pins PS/DDR]
  connect_bd_intf_net -intf_net processing_system7_0_FIXED_IO [get_bd_intf_ports FIXED_IO] [get_bd_intf_pins PS/FIXED_IO]
  connect_bd_intf_net -intf_net processing_system7_0_MDIO_ETHERNET_0 [get_bd_intf_ports MDIO_ETHERNET_0_0] [get_bd_intf_pins PS/MDIO_ETHERNET_0_0]
  connect_bd_intf_net -intf_net ps7_axi_periph_M00_AXI [get_bd_intf_pins dz_regs_0/s_axi] [get_bd_intf_pins ps7_axi_periph/M00_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M01_AXI [get_bd_intf_pins HDMI_0/ctrl] [get_bd_intf_pins ps7_axi_periph/M01_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M04_AXI [get_bd_intf_pins axi_dynclk_0/S_AXI_LITE] [get_bd_intf_pins ps7_axi_periph/M04_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M05_AXI [get_bd_intf_pins HDMI_1/S_AXI_LITE] [get_bd_intf_pins ps7_axi_periph/M05_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M06_AXI [get_bd_intf_pins HDMI_0/S_AXI_LITE_MIXER_0] [get_bd_intf_pins ps7_axi_periph/M06_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M07_AXI [get_bd_intf_pins dz_osc2_0/s_axi] [get_bd_intf_pins ps7_axi_periph/M07_AXI]
  connect_bd_intf_net -intf_net ps7_axi_periph_M08_AXI [get_bd_intf_pins hdmi_audio_regs_0/s_axi] [get_bd_intf_pins ps7_axi_periph/M08_AXI]

  # Create port connections
  connect_bd_net -net ARESETN_1 [get_bd_pins HDMI_0/ARESETN] [get_bd_pins HDMI_1/ARESETN] [get_bd_pins PS/peripheral_aresetn1]
  connect_bd_net -net AUDIO_L_1 [get_bd_ports AUDIO_L] [get_bd_pins pl_io_0/AUDIO_L]
  connect_bd_net -net AUDIO_R_1 [get_bd_ports AUDIO_R] [get_bd_pins pl_io_0/AUDIO_R]
  connect_bd_net -net ENET0_GMII_RX_CLK_0_1 [get_bd_ports ENET0_GMII_RX_CLK_0] [get_bd_pins PS/ENET0_GMII_RX_CLK_0]
  connect_bd_net -net ENET0_GMII_RX_DV_0_1 [get_bd_ports ENET0_GMII_RX_DV_0] [get_bd_pins PS/ENET0_GMII_RX_DV_0]
  connect_bd_net -net ENET0_GMII_TX_CLK_0_1 [get_bd_ports ENET0_GMII_TX_CLK_0] [get_bd_pins PS/ENET0_GMII_TX_CLK_0]
  connect_bd_net -net HDMI_0_active_video_out [get_bd_pins HDMI_0/active_video_out] [get_bd_pins HDMI_1/active_video_in] [get_bd_pins dz_osc2_0/line_de]
  connect_bd_net -net HDMI_0_dout [get_bd_pins HDMI_0/dout] [get_bd_pins HDMI_1/inIRQ]
  connect_bd_net -net HDMI_0_hblank_out [get_bd_pins HDMI_0/hblank_out] [get_bd_pins HDMI_1/hblank_in]
  connect_bd_net -net HDMI_0_hsync_out [get_bd_pins HDMI_0/hsync_out] [get_bd_pins HDMI_1/hsync_in] [get_bd_pins dz_osc2_0/hsync]
  connect_bd_net -net HDMI_0_vblank_out [get_bd_pins HDMI_0/vblank_out] [get_bd_pins HDMI_1/vblank_in]
  connect_bd_net -net HDMI_0_vo_locked [get_bd_pins HDMI_0/vo_locked] [get_bd_pins hdmi_audio_regs_0/vo0_locked]
  connect_bd_net -net HDMI_0_vo_underflow [get_bd_pins HDMI_0/vo_underflow] [get_bd_pins hdmi_audio_regs_0/vo0_underflow]
  connect_bd_net -net HDMI_0_vsync_out [get_bd_pins HDMI_0/vsync_out] [get_bd_pins HDMI_1/vsync_in] [get_bd_pins dz_osc2_0/vsync] [get_bd_pins fsync_gen_0/vsync] [get_bd_pins hdmi_audio_regs_0/vsync]
  connect_bd_net -net HDMI_1_HDMI_OEN [get_bd_ports HDMI_CEC_1] [get_bd_pins HDMI_1/HDMI_OEN]
  connect_bd_net -net HDMI_1_TMDS_Clk_n_1 [get_bd_ports TMDS_Clk_n_1] [get_bd_pins HDMI_1/TMDS_Clk_n_1]
  connect_bd_net -net HDMI_1_TMDS_Clk_p_1 [get_bd_ports TMDS_Clk_p_1] [get_bd_pins HDMI_1/TMDS_Clk_p_1]
  connect_bd_net -net HDMI_1_TMDS_Data_n_1 [get_bd_ports TMDS_Data_n_1] [get_bd_pins HDMI_1/TMDS_Data_n_1]
  connect_bd_net -net HDMI_1_TMDS_Data_p_1 [get_bd_ports TMDS_Data_p_1] [get_bd_pins HDMI_1/TMDS_Data_p_1]
  connect_bd_net -net HDMI_1_outIRQ [get_bd_pins HDMI_1/outIRQ] [get_bd_pins PS/IRQ_F2P]
  connect_bd_net -net HDMI_1_pixData [get_bd_pins HDMI_0/pixIn] [get_bd_pins HDMI_1/pixData]
  connect_bd_net -net HDMI_1_vo_locked [get_bd_pins HDMI_1/vo_locked] [get_bd_pins hdmi_audio_regs_0/vo1_locked]
  connect_bd_net -net HDMI_1_vo_underflow [get_bd_pins HDMI_1/vo_underflow] [get_bd_pins hdmi_audio_regs_0/vo1_underflow]
  connect_bd_net -net HDMI_2_debug [get_bd_pins HDMI_2/debug] [get_bd_pins xlconcat_0/In2] [get_bd_pins xlslice_0/Din]
  connect_bd_net -net HDMI_2_rx_acr_cts [get_bd_pins HDMI_2/rx_acr_cts] [get_bd_pins hdmi_audio_regs_0/rx_acr_cts]
  connect_bd_net -net HDMI_2_rx_acr_n [get_bd_pins HDMI_2/rx_acr_n] [get_bd_pins hdmi_audio_regs_0/rx_acr_n]
  connect_bd_net -net HDMI_2_rx_aud_l [get_bd_pins HDMI_2/rx_aud_l] [get_bd_pins pl_io_0/rx_l]
  connect_bd_net -net HDMI_2_rx_aud_r [get_bd_pins HDMI_2/rx_aud_r] [get_bd_pins pl_io_0/rx_r]
  connect_bd_net -net HDMI_2_rx_aud_valid [get_bd_pins HDMI_2/rx_aud_valid] [get_bd_pins pl_io_0/rx_valid]
  connect_bd_net -net HDMI_2_rx_clk [get_bd_pins HDMI_2/rx_clk] [get_bd_pins pl_io_0/rx_clk]
  connect_bd_net -net HDMI_2_rx_peak [get_bd_pins HDMI_2/rx_peak] [get_bd_pins hdmi_audio_regs_0/rx_peak]
  connect_bd_net -net HDMI_2_rx_pub [get_bd_pins HDMI_2/rx_pub] [get_bd_pins hdmi_audio_regs_0/rx_pub]
  connect_bd_net -net HDMI_2_rx_samples [get_bd_pins HDMI_2/rx_samples] [get_bd_pins hdmi_audio_regs_0/rx_samples]
  connect_bd_net -net HDMI_2_rx_size_h [get_bd_pins HDMI_2/rx_size_h] [get_bd_pins hdmi_audio_regs_0/rx_size_h]
  connect_bd_net -net HDMI_2_rx_size_v [get_bd_pins HDMI_2/rx_size_v] [get_bd_pins hdmi_audio_regs_0/rx_size_v]
  connect_bd_net -net HDMI_2_rx_status [get_bd_pins HDMI_2/rx_status] [get_bd_pins hdmi_audio_regs_0/rx_status]
  connect_bd_net -net HDMI_2_s2mm_introut_0 [get_bd_pins HDMI_0/In3] [get_bd_pins HDMI_2/s2mm_introut_0]
  connect_bd_net -net HDMI_2_tx_aud_l [get_bd_pins HDMI_2/tx_aud_l] [get_bd_pins pl_io_0/loop_l]
  connect_bd_net -net HDMI_2_tx_aud_r [get_bd_pins HDMI_2/tx_aud_r] [get_bd_pins pl_io_0/loop_r]
  connect_bd_net -net HDMI_2_tx_aud_valid [get_bd_pins HDMI_2/tx_aud_valid] [get_bd_pins pl_io_0/loop_valid]
  connect_bd_net -net HDMI_HPD_1 [get_bd_ports HDMI_HPD] [get_bd_pins xlconcat_0/In1]
  connect_bd_net -net In0_0_1 [get_bd_ports enet0_gmii_rxd] [get_bd_pins PS/enet0_gmii_rxd]
  connect_bd_net -net J3P3_INPUT_1 [get_bd_ports J3P3_INPUT] [get_bd_pins hdmi_audio_regs_0/j3p3] [get_bd_pins xlconcat_0/In3]
  connect_bd_net -net J5P3_INPUT_1 [get_bd_ports J5P3_INPUT] [get_bd_pins hdmi_audio_regs_0/j5p3] [get_bd_pins xlconcat_0/In4]
  connect_bd_net -net Net [get_bd_pins HDMI_0/m_axis_mm2s_aclk] [get_bd_pins HDMI_1/m_axis_mm2s_aclk] [get_bd_pins HDMI_2/m_axi_s2mm_aclk_0] [get_bd_pins HDMI_2/s_axis_s2mm_aclk_0] [get_bd_pins PS/FCLK_CLK2_140M] [get_bd_pins fsync_gen_0/clk]
  connect_bd_net -net PL_KEY_1 [get_bd_ports PL_KEY] [get_bd_pins pl_io_0/PL_KEY]
  connect_bd_net -net PS_ARESETN [get_bd_pins HDMI_0/s_axi_aresetn] [get_bd_pins HDMI_1/s_axi_aresetn] [get_bd_pins PS/ARESETN] [get_bd_pins axi_dynclk_0/s_axi_lite_aresetn] [get_bd_pins dz_osc2_0/aresetn] [get_bd_pins dz_regs_0/s_axi_aresetn] [get_bd_pins hdmi_audio_regs_0/s_axi_aresetn] [get_bd_pins pl_io_0/rstn] [get_bd_pins ps7_axi_periph/ARESETN] [get_bd_pins ps7_axi_periph/M00_ARESETN] [get_bd_pins ps7_axi_periph/M01_ARESETN] [get_bd_pins ps7_axi_periph/M02_ARESETN] [get_bd_pins ps7_axi_periph/M03_ARESETN] [get_bd_pins ps7_axi_periph/M04_ARESETN] [get_bd_pins ps7_axi_periph/M05_ARESETN] [get_bd_pins ps7_axi_periph/M06_ARESETN] [get_bd_pins ps7_axi_periph/M07_ARESETN] [get_bd_pins ps7_axi_periph/M08_ARESETN] [get_bd_pins ps7_axi_periph/S00_ARESETN]
  connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins HDMI_0/s_axi_aclk] [get_bd_pins HDMI_1/s_axi_aclk] [get_bd_pins HDMI_2/s_axi_lite_aclk_0] [get_bd_pins PS/FCLK_CLK0_100M] [get_bd_pins axi_dynclk_0/REF_CLK_I] [get_bd_pins axi_dynclk_0/s_axi_lite_aclk] [get_bd_pins dz_osc2_0/clk] [get_bd_pins dz_regs_0/s_axi_aclk] [get_bd_pins hdmi_audio_regs_0/s_axi_aclk] [get_bd_pins pl_io_0/clk] [get_bd_pins ps7_axi_periph/ACLK] [get_bd_pins ps7_axi_periph/M00_ACLK] [get_bd_pins ps7_axi_periph/M01_ACLK] [get_bd_pins ps7_axi_periph/M02_ACLK] [get_bd_pins ps7_axi_periph/M03_ACLK] [get_bd_pins ps7_axi_periph/M04_ACLK] [get_bd_pins ps7_axi_periph/M05_ACLK] [get_bd_pins ps7_axi_periph/M06_ACLK] [get_bd_pins ps7_axi_periph/M07_ACLK] [get_bd_pins ps7_axi_periph/M08_ACLK] [get_bd_pins ps7_axi_periph/S00_ACLK]
  connect_bd_net -net PS_FCLK_CLK0_200M [get_bd_pins HDMI_2/RefClk] [get_bd_pins PS/FCLK_CLK0_200M]
  connect_bd_net -net PS_FCLK_CLK3_0 [get_bd_ports CLK25M] [get_bd_pins PS/CLK_25M]
  connect_bd_net -net PS_I2C0_SCL_O_top [get_bd_pins PS/I2C0_SCL_O] [get_bd_pins pl_io_0/I2C0_SCL_O]
  connect_bd_net -net PS_I2C0_SCL_T_top [get_bd_pins PS/I2C0_SCL_T] [get_bd_pins pl_io_0/I2C0_SCL_T]
  connect_bd_net -net PS_I2C0_SDA_O_top [get_bd_pins PS/I2C0_SDA_O] [get_bd_pins pl_io_0/I2C0_SDA_O]
  connect_bd_net -net PS_I2C0_SDA_T_top [get_bd_pins PS/I2C0_SDA_T] [get_bd_pins pl_io_0/I2C0_SDA_T]
  connect_bd_net -net PS_SPI0_MOSI_O_top [get_bd_pins PS/SPI0_MOSI_O] [get_bd_pins pl_io_0/SPI0_MOSI_O]
  connect_bd_net -net PS_SPI0_MOSI_T_top [get_bd_pins PS/SPI0_MOSI_T] [get_bd_pins pl_io_0/SPI0_MOSI_T]
  connect_bd_net -net PS_SPI0_SCLK_O_top [get_bd_pins PS/SPI0_SCLK_O] [get_bd_pins pl_io_0/SPI0_SCLK_O]
  connect_bd_net -net PS_SPI0_SCLK_T_top [get_bd_pins PS/SPI0_SCLK_T] [get_bd_pins pl_io_0/SPI0_SCLK_T]
  connect_bd_net -net PS_SPI0_SS1_O_top [get_bd_pins PS/SPI0_SS1_O] [get_bd_pins pl_io_0/SPI0_SS1_O]
  connect_bd_net -net PS_SPI0_SS_O_top [get_bd_pins PS/SPI0_SS_O] [get_bd_pins pl_io_0/SPI0_SS_O]
  connect_bd_net -net PS_SPI0_SS_T_top [get_bd_pins PS/SPI0_SS_T] [get_bd_pins pl_io_0/SPI0_SS_T]
  connect_bd_net -net PS_UART0_TX_top [get_bd_pins PS/UART0_TX] [get_bd_pins pl_io_0/UART0_TX]
  connect_bd_net -net TMDS_Clk_n_2_1 [get_bd_ports TMDS_Clk_n_2] [get_bd_pins HDMI_2/TMDS_Clk_n_2]
  connect_bd_net -net TMDS_Clk_p_2_1 [get_bd_ports TMDS_Clk_p_2] [get_bd_pins HDMI_2/TMDS_Clk_p_2]
  connect_bd_net -net TMDS_Data_n_2_1 [get_bd_ports TMDS_Data_n_2] [get_bd_pins HDMI_2/TMDS_Data_n_2]
  connect_bd_net -net TMDS_Data_p_2_1 [get_bd_ports TMDS_Data_p_2] [get_bd_pins HDMI_2/TMDS_Data_p_2]
  connect_bd_net -net axi_dynclk_0_LOCKED_O [get_bd_pins HDMI_0/aRst_n] [get_bd_pins HDMI_1/aRst_n] [get_bd_pins HDMI_2/aRst_n] [get_bd_pins HDMI_2/pRst_n] [get_bd_pins axi_dynclk_0/LOCKED_O] [get_bd_pins hdmi_audio_regs_0/dyn_locked]
  connect_bd_net -net axi_dynclk_0_PXL_CLK_5X_O [get_bd_pins HDMI_0/SerialClk] [get_bd_pins HDMI_1/SerialClk] [get_bd_pins axi_dynclk_0/PXL_CLK_5X_O]
  connect_bd_net -net axi_dynclk_0_PXL_CLK_O [get_bd_pins HDMI_0/PixelClk] [get_bd_pins HDMI_1/PixelClk] [get_bd_pins HDMI_2/tx_clk] [get_bd_pins axi_dynclk_0/PXL_CLK_O] [get_bd_pins hdmi_audio_regs_0/pxl_clk] [get_bd_pins pl_io_0/tx_clk]
  connect_bd_net -net dz_osc2_0_phase0 [get_bd_pins HDMI_0/osc_phase] [get_bd_pins dz_osc2_0/phase0]
  connect_bd_net -net dz_osc2_0_phase0_full [get_bd_pins dz_osc2_0/phase0_full] [get_bd_pins hdmi_audio_regs_0/dds_phase]
  connect_bd_net -net dz_osc2_0_phase1 [get_bd_pins HDMI_1/osc_phase] [get_bd_pins dz_osc2_0/phase1]
  connect_bd_net -net dz_osc2_0_wave0 [get_bd_pins HDMI_0/osc_wave] [get_bd_pins dz_osc2_0/wave0]
  connect_bd_net -net dz_osc2_0_wave1 [get_bd_pins HDMI_1/osc_wave] [get_bd_pins dz_osc2_0/wave1]
  connect_bd_net -net dz_regs_0_b0_ch2 [get_bd_pins dz_regs_0/b0_ch2] [get_bd_pins xlslice_1/Din] [get_bd_pins xlslice_2/Din]
  connect_bd_net -net dz_regs_0_b1_ch1 [get_bd_pins HDMI_0/regs_main_ch1] [get_bd_pins dz_regs_0/b1_ch1]
  connect_bd_net -net dz_regs_0_b1_ch2 [get_bd_pins HDMI_0/regs_main_ch2] [get_bd_pins dz_regs_0/b1_ch2]
  connect_bd_net -net dz_regs_0_b3_ch1 [get_bd_pins HDMI_1/regs_osc_ch1] [get_bd_pins dz_regs_0/b3_ch1]
  connect_bd_net -net dz_regs_0_b3_ch2 [get_bd_pins HDMI_1/regs_osc_ch2] [get_bd_pins dz_regs_0/b3_ch2]
  connect_bd_net -net dz_regs_0_b6_ch1 [get_bd_pins HDMI_1/regs_fb_ch1] [get_bd_pins dz_regs_0/b6_ch1]
  connect_bd_net -net dz_regs_0_b6_ch2 [get_bd_pins HDMI_1/regs_fb_ch2] [get_bd_pins dz_regs_0/b6_ch2]
  connect_bd_net -net dz_regs_0_irq [get_bd_pins HDMI_0/In2] [get_bd_pins dz_regs_0/irq]
  connect_bd_net -net fsync_gen_0_fsync [get_bd_pins HDMI_0/mm2s_fsync] [get_bd_pins HDMI_1/mm2s_fsync] [get_bd_pins fsync_gen_0/fsync]
  connect_bd_net -net hdmi_audio_regs_0_cap_pop [get_bd_pins hdmi_audio_regs_0/cap_pop] [get_bd_pins pl_io_0/cap_pop]
  connect_bd_net -net hdmi_audio_regs_0_ev_irq [get_bd_pins HDMI_0/In5] [get_bd_pins hdmi_audio_regs_0/ev_irq]
  connect_bd_net -net hdmi_audio_regs_0_hpd2 [get_bd_ports HDMI_HPD_2] [get_bd_pins hdmi_audio_regs_0/hpd2]
  connect_bd_net -net hdmi_audio_regs_0_i2s_ctrl [get_bd_pins hdmi_audio_regs_0/i2s_ctrl] [get_bd_pins pl_io_0/i2s_ctrl]
  connect_bd_net -net hdmi_audio_regs_0_i2s_inc [get_bd_pins hdmi_audio_regs_0/i2s_inc] [get_bd_pins pl_io_0/i2s_inc]
  connect_bd_net -net hdmi_audio_regs_0_io_func [get_bd_pins hdmi_audio_regs_0/io_func] [get_bd_pins pl_io_0/io_func]
  connect_bd_net -net hdmi_audio_regs_0_io_out [get_bd_pins hdmi_audio_regs_0/io_out] [get_bd_pins pl_io_0/io_out]
  connect_bd_net -net hdmi_audio_regs_0_irq [get_bd_pins HDMI_0/In4] [get_bd_pins hdmi_audio_regs_0/irq]
  connect_bd_net -net hdmi_audio_regs_0_j3p4 [get_bd_ports J3P4_OUTPUT] [get_bd_pins hdmi_audio_regs_0/j3p4]
  connect_bd_net -net hdmi_audio_regs_0_j5p4 [get_bd_ports J5P4_OUTPUT] [get_bd_pins hdmi_audio_regs_0/j5p4]
  connect_bd_net -net hdmi_audio_regs_0_led_red [get_bd_ports LED_RED] [get_bd_pins hdmi_audio_regs_0/led_red]
  connect_bd_net -net hdmi_audio_regs_0_pcm_flush [get_bd_pins hdmi_audio_regs_0/pcm_flush] [get_bd_pins pl_io_0/pcm_flush]
  connect_bd_net -net hdmi_audio_regs_0_pcm_run [get_bd_pins hdmi_audio_regs_0/pcm_run] [get_bd_pins pl_io_0/pcm_run]
  connect_bd_net -net hdmi_audio_regs_0_pcm_wdata [get_bd_pins hdmi_audio_regs_0/pcm_wdata] [get_bd_pins pl_io_0/pcm_wdata]
  connect_bd_net -net hdmi_audio_regs_0_pcm_wr [get_bd_pins hdmi_audio_regs_0/pcm_wr] [get_bd_pins pl_io_0/pcm_wr]
  connect_bd_net -net hdmi_audio_regs_0_rx_ctrl [get_bd_pins HDMI_2/rx_ctrl] [get_bd_pins hdmi_audio_regs_0/rx_ctrl]
  connect_bd_net -net hdmi_audio_regs_0_tx0_ctrl [get_bd_pins HDMI_0/audio_ctrl] [get_bd_pins hdmi_audio_regs_0/tx0_ctrl]
  connect_bd_net -net hdmi_audio_regs_0_tx_ctrl [get_bd_pins HDMI_1/audio_ctrl] [get_bd_pins hdmi_audio_regs_0/tx_ctrl]
  connect_bd_net -net hdmi_audio_regs_0_tx_fs_inc [get_bd_pins HDMI_0/audio_fs_inc] [get_bd_pins HDMI_1/audio_fs_inc] [get_bd_pins hdmi_audio_regs_0/tx_fs_inc]
  connect_bd_net -net osc_trig_0_dout [get_bd_pins dz_osc2_0/ext_trig] [get_bd_pins osc_trig_0/dout]
  connect_bd_net -net pixIn1_1 [get_bd_pins HDMI_0/pixData] [get_bd_pins HDMI_1/pixIn1]
  connect_bd_net -net pl_io_0_I2C0_SCL_I [get_bd_pins PS/I2C0_SCL_I] [get_bd_pins pl_io_0/I2C0_SCL_I]
  connect_bd_net -net pl_io_0_I2C0_SDA_I [get_bd_pins PS/I2C0_SDA_I] [get_bd_pins pl_io_0/I2C0_SDA_I]
  connect_bd_net -net pl_io_0_SPI0_MISO_I [get_bd_pins PS/SPI0_MISO_I] [get_bd_pins pl_io_0/SPI0_MISO_I]
  connect_bd_net -net pl_io_0_SPI0_MOSI_I [get_bd_pins PS/SPI0_MOSI_I] [get_bd_pins pl_io_0/SPI0_MOSI_I]
  connect_bd_net -net pl_io_0_SPI0_SCLK_I [get_bd_pins PS/SPI0_SCLK_I] [get_bd_pins pl_io_0/SPI0_SCLK_I]
  connect_bd_net -net pl_io_0_SPI0_SS_I [get_bd_pins PS/SPI0_SS_I] [get_bd_pins pl_io_0/SPI0_SS_I]
  connect_bd_net -net pl_io_0_UART0_RX [get_bd_pins PS/UART0_RX] [get_bd_pins pl_io_0/UART0_RX]
  connect_bd_net -net pl_io_0_aud0_l [get_bd_pins HDMI_0/aud_l] [get_bd_pins pl_io_0/aud0_l]
  connect_bd_net -net pl_io_0_aud0_r [get_bd_pins HDMI_0/aud_r] [get_bd_pins pl_io_0/aud0_r]
  connect_bd_net -net pl_io_0_aud0_valid [get_bd_pins HDMI_0/aud_valid] [get_bd_pins pl_io_0/aud0_valid]
  connect_bd_net -net pl_io_0_aud_l [get_bd_pins HDMI_1/aud_l] [get_bd_pins pl_io_0/aud_l]
  connect_bd_net -net pl_io_0_aud_r [get_bd_pins HDMI_1/aud_r] [get_bd_pins pl_io_0/aud_r]
  connect_bd_net -net pl_io_0_aud_valid [get_bd_pins HDMI_1/aud_valid] [get_bd_pins pl_io_0/aud_valid]
  connect_bd_net -net pl_io_0_cap_head [get_bd_pins hdmi_audio_regs_0/cap_head] [get_bd_pins pl_io_0/cap_head]
  connect_bd_net -net pl_io_0_cap_level [get_bd_pins hdmi_audio_regs_0/cap_level] [get_bd_pins pl_io_0/cap_level]
  connect_bd_net -net pl_io_0_i2s_status [get_bd_pins hdmi_audio_regs_0/i2s_status] [get_bd_pins pl_io_0/i2s_status]
  connect_bd_net -net pl_io_0_io_in [get_bd_pins hdmi_audio_regs_0/io_in] [get_bd_pins pl_io_0/io_in]
  connect_bd_net -net pl_io_0_k4_in [get_bd_pins pl_io_0/k4_in] [get_bd_pins xlconcat_1/In0]
  connect_bd_net -net pl_io_0_k5_in [get_bd_pins pl_io_0/k5_in] [get_bd_pins xlconcat_1/In1]
  connect_bd_net -net pl_io_0_key_in [get_bd_pins pl_io_0/key_in] [get_bd_pins xlconcat_2/In0]
  connect_bd_net -net pl_io_0_pcm_frames [get_bd_pins hdmi_audio_regs_0/pcm_frames] [get_bd_pins pl_io_0/pcm_frames]
  connect_bd_net -net pl_io_0_pcm_level0 [get_bd_pins hdmi_audio_regs_0/pcm_level0] [get_bd_pins pl_io_0/pcm_level0]
  connect_bd_net -net pl_io_0_pcm_level1 [get_bd_pins hdmi_audio_regs_0/pcm_level1] [get_bd_pins pl_io_0/pcm_level1]
  connect_bd_net -net pl_io_0_pcm_level2 [get_bd_pins hdmi_audio_regs_0/pcm_level2] [get_bd_pins pl_io_0/pcm_level2]
  connect_bd_net -net pl_io_0_pcm_xrun [get_bd_pins hdmi_audio_regs_0/pcm_xrun] [get_bd_pins pl_io_0/pcm_xrun]
  connect_bd_net -net processing_system7_0_ENET0_GMII_TX_EN [get_bd_ports ENET0_GMII_TX_EN_0] [get_bd_pins PS/ENET0_GMII_TX_EN_0]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_n [get_bd_ports TMDS_Clk_n_0] [get_bd_pins HDMI_0/TMDS_Clk_n_0]
  connect_bd_net -net rgb2dvi_0_TMDS_Clk_p [get_bd_ports TMDS_Clk_p_0] [get_bd_pins HDMI_0/TMDS_Clk_p_0]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_n [get_bd_ports TMDS_Data_n_0] [get_bd_pins HDMI_0/TMDS_Data_n_0]
  connect_bd_net -net rgb2dvi_0_TMDS_Data_p [get_bd_ports TMDS_Data_p_0] [get_bd_pins HDMI_0/TMDS_Data_p_0]
  connect_bd_net -net xlconcat_0_dout [get_bd_pins dz_regs_0/gpio_in] [get_bd_pins xlconcat_0/dout]
  connect_bd_net -net xlconcat_1_dout [get_bd_pins xlconcat_1/dout] [get_bd_pins xlconcat_2/In1]
  connect_bd_net -net xlconcat_2_dout [get_bd_pins xlconcat_0/In0] [get_bd_pins xlconcat_2/dout]
  connect_bd_net -net xlconstant_0_dout [get_bd_ports HDMI_CEC_0] [get_bd_pins HDMI_0/HDMI_OEN]
  connect_bd_net -net xlslice_0_Dout [get_bd_ports enet0_gmii_txd] [get_bd_pins PS/enet0_gmii_txd]
  connect_bd_net -net xlslice_0_Dout1 [get_bd_ports LED_GREEN] [get_bd_pins xlslice_0/Dout]
  connect_bd_net -net xlslice_1_Dout [get_bd_pins HDMI_0/dds_phase_div_den_0] [get_bd_pins xlslice_1/Dout]
  connect_bd_net -net xlslice_2_Dout [get_bd_pins HDMI_1/gPhase] [get_bd_pins xlslice_2/Dout]

  # Create address segments
  assign_bd_address -offset 0x00000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces HDMI_0/axi_vdma_0/Data_MM2S] [get_bd_addr_segs PS/processing_system7_0/S_AXI_HP0/HP0_DDR_LOWOCM] -force
  assign_bd_address -offset 0x00000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces HDMI_1/axi_vdma_0/Data_MM2S] [get_bd_addr_segs PS/processing_system7_0/S_AXI_HP2/HP2_DDR_LOWOCM] -force
  assign_bd_address -offset 0x00000000 -range 0x10000000 -target_address_space [get_bd_addr_spaces HDMI_2/axi_vdma_0/Data_S2MM] [get_bd_addr_segs PS/processing_system7_0/S_AXI_HP1/HP1_DDR_LOWOCM] -force
  assign_bd_address -offset 0x43C40000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs axi_dynclk_0/S_AXI_LITE/S_AXI_LITE_reg] -force
  assign_bd_address -offset 0x43000000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs HDMI_0/axi_vdma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x43010000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs HDMI_1/axi_vdma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x43020000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs HDMI_2/axi_vdma_0/S_AXI_LITE/Reg] -force
  assign_bd_address -offset 0x43D00000 -range 0x00008000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs dz_osc2_0/s_axi/reg0] -force
  assign_bd_address -offset 0x41200000 -range 0x00080000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs dz_regs_0/s_axi/reg0] -force
  assign_bd_address -offset 0x43C60000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs hdmi_audio_regs_0/s_axi/reg0] -force
  assign_bd_address -offset 0x43C50000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs HDMI_0/mixerMatrix/mixer_0/S00_AXI/S00_AXI_reg] -force
  assign_bd_address -offset 0x43C20000 -range 0x00010000 -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] [get_bd_addr_segs HDMI_0/v_tc_0/ctrl/Reg] -force

  # Perform GUI Layout
  regenerate_bd_layout -layout_string {
   "ActiveEmotionalView":"Default View",
   "Default View_ScaleFactor":"0.853444",
   "Default View_TopLeft":"-356,1562",
   "ExpandedHierarchyInLayout":"",
   "comment_0":"PS groups:
- Programmable System(CPU)
- Reset
- AXI control
- Ethernet",
   "commentid":"comment_0|",
   "font_comment_0":"14",
   "guistr":"# # String gsaved with Nlview 7.0r4  2019-12-20 bk=1.5203 VDI=41 GEI=36 GUI=JA:10.0 TLS
#  -string -flagsOSRD
preplace port DDC_2 -pg 1 -lvl 5 -x 2100 -y 1450 -defaultsOSRD
preplace port DDR -pg 1 -lvl 5 -x 2100 -y 2020 -defaultsOSRD
preplace port FIXED_IO -pg 1 -lvl 5 -x 2100 -y 2040 -defaultsOSRD
preplace port MDIO_ETHERNET_0_0 -pg 1 -lvl 5 -x 2100 -y 2000 -defaultsOSRD
preplace port port-id_AUDIO_L -pg 1 -lvl 0 -x -10 -y 2020 -defaultsOSRD
preplace port port-id_AUDIO_R -pg 1 -lvl 0 -x -10 -y 2040 -defaultsOSRD
preplace port port-id_CLK25M -pg 1 -lvl 5 -x 2100 -y 2120 -defaultsOSRD
preplace port port-id_ENET0_GMII_RX_CLK_0 -pg 1 -lvl 0 -x -10 -y 2100 -defaultsOSRD
preplace port port-id_ENET0_GMII_RX_DV_0 -pg 1 -lvl 0 -x -10 -y 2120 -defaultsOSRD
preplace port port-id_ENET0_GMII_TX_CLK_0 -pg 1 -lvl 0 -x -10 -y 2140 -defaultsOSRD
preplace port port-id_TMDS_Clk_n_0 -pg 1 -lvl 5 -x 2100 -y 720 -defaultsOSRD
preplace port port-id_TMDS_Clk_n_1 -pg 1 -lvl 5 -x 2100 -y 260 -defaultsOSRD
preplace port port-id_TMDS_Clk_n_2 -pg 1 -lvl 0 -x -10 -y 1170 -defaultsOSRD
preplace port port-id_TMDS_Clk_p_0 -pg 1 -lvl 5 -x 2100 -y 700 -defaultsOSRD
preplace port port-id_TMDS_Clk_p_1 -pg 1 -lvl 5 -x 2100 -y 280 -defaultsOSRD
preplace port port-id_TMDS_Clk_p_2 -pg 1 -lvl 0 -x -10 -y 1150 -defaultsOSRD
preplace portBus ENET0_GMII_TX_EN_0 -pg 1 -lvl 5 -x 2100 -y 2080 -defaultsOSRD
preplace portBus HDMI_CEC_0 -pg 1 -lvl 5 -x 2100 -y 680 -defaultsOSRD
preplace portBus HDMI_CEC_1 -pg 1 -lvl 5 -x 2100 -y 200 -defaultsOSRD
preplace portBus HDMI_HPD -pg 1 -lvl 5 -x 2100 -y 1790 -defaultsOSRD -right
preplace portBus HDMI_HPD_2 -pg 1 -lvl 5 -x 2100 -y 2340 -defaultsOSRD
preplace portBus LED_GREEN -pg 1 -lvl 5 -x 2100 -y 1850 -defaultsOSRD
preplace portBus PL_KEY -pg 1 -lvl 0 -x -10 -y 1960 -defaultsOSRD
preplace portBus TMDS_Data_n_0 -pg 1 -lvl 5 -x 2100 -y 760 -defaultsOSRD
preplace portBus TMDS_Data_n_1 -pg 1 -lvl 5 -x 2100 -y 300 -defaultsOSRD
preplace portBus TMDS_Data_n_2 -pg 1 -lvl 0 -x -10 -y 1190 -defaultsOSRD
preplace portBus TMDS_Data_p_0 -pg 1 -lvl 5 -x 2100 -y 740 -defaultsOSRD
preplace portBus TMDS_Data_p_1 -pg 1 -lvl 5 -x 2100 -y 320 -defaultsOSRD
preplace portBus TMDS_Data_p_2 -pg 1 -lvl 0 -x -10 -y 1210 -defaultsOSRD
preplace portBus enet0_gmii_rxd -pg 1 -lvl 0 -x -10 -y 2160 -defaultsOSRD
preplace portBus enet0_gmii_txd -pg 1 -lvl 5 -x 2100 -y 2140 -defaultsOSRD
preplace inst HDMI_0 -pg 1 -lvl 3 -x 1060 -y 780 -defaultsOSRD
preplace inst HDMI_1 -pg 1 -lvl 3 -x 1060 -y 250 -defaultsOSRD
preplace inst HDMI_2 -pg 1 -lvl 4 -x 1770 -y 1480 -defaultsOSRD
preplace inst PS -pg 1 -lvl 4 -x 1770 -y 2110 -defaultsOSRD
preplace inst axi_dynclk_0 -pg 1 -lvl 4 -x 1770 -y 1030 -defaultsOSRD
preplace inst axi_gpio_hdmi_in_phase0_div_gPhase1 -pg 1 -lvl 4 -x 1770 -y 1220 -defaultsOSRD
preplace inst dds_axi_interface_0 -pg 1 -lvl 2 -x 450 -y 840 -defaultsOSRD
preplace inst dds_axi_interface_1 -pg 1 -lvl 2 -x 450 -y 1050 -defaultsOSRD
preplace inst ps7_axi_periph -pg 1 -lvl 3 -x 1060 -y 1550 -defaultsOSRD
preplace inst xlconcat_0 -pg 1 -lvl 4 -x 1770 -y 1710 -defaultsOSRD
preplace inst xlconcat_1 -pg 1 -lvl 1 -x 130 -y 2030 -defaultsOSRD
preplace inst xlconcat_2 -pg 1 -lvl 2 -x 450 -y 1970 -defaultsOSRD
preplace inst xlslice_0 -pg 1 -lvl 4 -x 1770 -y 1850 -defaultsOSRD
preplace inst xlslice_1 -pg 1 -lvl 1 -x 130 -y 740 -defaultsOSRD
preplace inst xlslice_2 -pg 1 -lvl 1 -x 130 -y 440 -defaultsOSRD
preplace netloc ARESETN_1 1 2 3 750 1000 1340J 900 2050
preplace netloc AUDIO_L_1 1 0 1 NJ 2020
preplace netloc AUDIO_R_1 1 0 1 NJ 2040
preplace netloc ENET0_GMII_RX_CLK_0_1 1 0 4 NJ 2100 NJ 2100 NJ 2100 NJ
preplace netloc ENET0_GMII_RX_DV_0_1 1 0 4 NJ 2120 NJ 2120 NJ 2120 NJ
preplace netloc ENET0_GMII_TX_CLK_0_1 1 0 4 NJ 2140 NJ 2140 NJ 2140 NJ
preplace netloc HDMI_0_active_video_out 1 2 2 790 1010 1270
preplace netloc HDMI_0_dout 1 2 2 820 540 1260
preplace netloc HDMI_0_hblank_out 1 2 2 830 490 1310
preplace netloc HDMI_0_hsync_out 1 2 2 840 500 1300
preplace netloc HDMI_0_vblank_out 1 2 2 810 1020 1260
preplace netloc HDMI_0_vsync_out 1 2 2 850 530 1290
preplace netloc HDMI_1_HDMI_OEN 1 3 2 NJ 200 NJ
preplace netloc HDMI_1_TMDS_Clk_n_1 1 3 2 NJ 220 2050J
preplace netloc HDMI_1_TMDS_Clk_p_1 1 3 2 NJ 240 2040J
preplace netloc HDMI_1_TMDS_Data_n_1 1 3 2 NJ 260 2030J
preplace netloc HDMI_1_TMDS_Data_p_1 1 3 2 NJ 280 1970J
preplace netloc HDMI_1_outIRQ 1 3 1 1370 300n
preplace netloc HDMI_1_pixData 1 2 2 840 1050 1320
preplace netloc HDMI_2_debug 1 3 2 1540 1320 1970
preplace netloc HDMI_2_s2mm_introut_0 1 2 3 850 1030 1360J 910 2030
preplace netloc HDMI_HPD_1 1 3 2 1560 1790 NJ
preplace netloc In0_0_1 1 0 4 NJ 2160 NJ 2160 NJ 2160 1270J
preplace netloc Net 1 2 3 730 1140 1440 1630 2010
preplace netloc PL_KEY_1 1 0 2 NJ 1960 NJ
preplace netloc PS_ARESETN 1 1 4 250 730 660 1130 1530 1910 1980
preplace netloc PS_FCLK_CLK0 1 1 4 240 720 650 1100 1510 1930 1970
preplace netloc PS_FCLK_CLK0_200M 1 3 2 1550 1920 2000
preplace netloc PS_FCLK_CLK3_0 1 4 1 2080J 2100n
preplace netloc TMDS_Clk_n_2_1 1 0 4 10J 1160 NJ 1160 NJ 1160 1460J
preplace netloc TMDS_Clk_p_2_1 1 0 4 NJ 1150 NJ 1150 NJ 1150 1470J
preplace netloc TMDS_Data_n_2_1 1 0 4 20J 1170 NJ 1170 NJ 1170 1400J
preplace netloc TMDS_Data_p_2_1 1 0 4 NJ 1210 NJ 1210 620J 1920 1490J
preplace netloc axi_dynclk_0_LOCKED_O 1 2 3 690 1090 1500 920 1990
preplace netloc axi_dynclk_0_PXL_CLK_5X_O 1 2 3 700 1060 1380J 930 1970
preplace netloc axi_dynclk_0_PXL_CLK_O 1 2 3 720 1040 1350J 890 2000
preplace netloc axi_gpio_hdmi_in_dds_phase_div_out_gpio2_io_o 1 0 5 10 520 NJ 520 NJ 520 NJ 520 2040
preplace netloc axi_gpio_hdmi_ip2intc_irpt 1 2 3 830 1070 1420J 940 1980
preplace netloc pixIn1_1 1 2 2 770 1080 1280
preplace netloc processing_system7_0_ENET0_GMII_TX_EN 1 4 1 2070J 2080n
preplace netloc rgb2dvi_0_TMDS_Clk_n 1 3 2 NJ 700 2050J
preplace netloc rgb2dvi_0_TMDS_Clk_p 1 3 2 1340J 710 2070J
preplace netloc rgb2dvi_0_TMDS_Data_n 1 3 2 NJ 740 2050J
preplace netloc rgb2dvi_0_TMDS_Data_p 1 3 2 1340J 750 2070J
preplace netloc xlconcat_0_dout 1 4 1 2000 1200n
preplace netloc xlconcat_1_dout 1 1 1 250 1980n
preplace netloc xlconcat_2_dout 1 2 2 NJ 1970 1520
preplace netloc xlconstant_0_dout 1 3 2 NJ 680 NJ
preplace netloc xlslice_0_Dout 1 4 1 2080J 2140n
preplace netloc xlslice_0_Dout1 1 4 1 NJ 1850
preplace netloc xlslice_1_Dout 1 1 2 NJ 740 640J
preplace netloc xlslice_2_Dout 1 1 2 240J 260 NJ
preplace netloc HDMI_1_M00_AXI1 1 3 1 1410 180n
preplace netloc HDMI_2_DDC_2 1 4 1 NJ 1450
preplace netloc S00_AXI_2 1 2 3 850 1120 NJ 1120 2020
preplace netloc S_AXI_HP0_1 1 3 1 1390 660n
preplace netloc S_AXI_HP1_1 1 3 2 1560 1940 1990
preplace netloc S_AXI_LITE_0_1 1 3 1 1480 1380n
preplace netloc S_AXI_LITE_1 1 2 2 800 1110 1280
preplace netloc S_AXI_LITE_gainFeedback_1 1 2 2 740 550 1330
preplace netloc dds_axi_interface_0_ctrl_m_axis 1 2 1 630 670n
preplace netloc dds_axi_interface_1_ctrl_m_axis 1 2 1 620 100n
preplace netloc processing_system7_0_DDR 1 4 1 2070J 2000n
preplace netloc processing_system7_0_FIXED_IO 1 4 1 2060J 2020n
preplace netloc processing_system7_0_MDIO_ETHERNET_0 1 4 1 2080J 2000n
preplace netloc ps7_axi_periph_M00_AXI 1 3 1 1450 1200n
preplace netloc ps7_axi_periph_M01_AXI 1 2 2 780 1200 1260
preplace netloc ps7_axi_periph_M04_AXI 1 3 1 1430 1000n
preplace netloc ps7_axi_periph_M05_AXI 1 2 2 680 1210 1270
preplace netloc ps7_axi_periph_M06_AXI 1 2 2 670 1910 1300
preplace netloc ps7_axi_periph_M07_AXI 1 2 2 760 1890 1270
preplace netloc ps7_axi_periph_M08_AXI 1 2 2 710 1900 1260
preplace netloc ps7_axi_periph_M09_AXI 1 1 3 260 1180 NJ 1180 1290
preplace netloc ps7_axi_periph_M11_AXI 1 1 3 270 1190 NJ 1190 1310
preplace cgraphic comment_0 place left -113 -3 textcolor 4 linecolor 3
levelinfo -pg 1 -10 130 450 1060 1770 2100
pagesize -pg 1 -db -bbox -sgen -230 0 2340 2400
",
   "linktoobj_comment_0":"",
   "linktotype_comment_0":"bd_design"
}

  # Restore current instance
  current_bd_instance $oldCurInst

  validate_bd_design
  save_bd_design
}
# End of create_root_design()


##################################################################
# MAIN FLOW
##################################################################

create_root_design ""


