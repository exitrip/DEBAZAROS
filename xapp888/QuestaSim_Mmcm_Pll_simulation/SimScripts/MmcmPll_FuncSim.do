#--------------------------------------------------------------------------------------------
#- � Copyright 2019, Xilinx, Inc. All rights reserved.
#- This file contains confidential and proprietary information of Xilinx, Inc. and is
#- protected under U.S. and international copyright and other intellectual property laws.
#--------------------------------------------------------------------------------------------
#-
#- Disclaimer:
#-		This disclaimer is not a license and does not grant any rights to the materials
#-		distributed herewith. Except as otherwise provided in a valid license issued to you
#-		by Xilinx, and to the maximum extent permitted by applicable law: (1) THESE MATERIALS
#-		ARE MADE AVAILABLE "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
#-		WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING BUT NOT LIMITED
#-		TO WARRANTIES OF MERCHANTABILITY, NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR
#-		PURPOSE; and (2) Xilinx shall not be liable (whether in contract or tort, including
#-		negligence, or under any other theory of liability) for any loss or damage of any
#-		kind or nature related to, arising under or in connection with these materials,
#-		including for any direct, or any indirect, special, incidental, or consequential
#-		loss or damage (including loss of data, profits, goodwill, or any type of loss or
#-		damage suffered as a result of any action brought by a third party) even if such
#-		damage or loss was reasonably foreseeable or Xilinx had been advised of the
#-		possibility of the same.
#-
#- CRITICAL APPLICATIONS
#-		Xilinx products are not designed or intended to be fail-safe, or for use in any
#-		application requiring fail-safe performance, such as life-support or safety devices
#-		or systems, Class III medical devices, nuclear facilities, applications related to
#-		the deployment of airbags, or any other applications that could lead to death,
#-		personal injury, or severe property or environmental damage (individually and
#-		collectively, "Critical Applications"). Customer assumes the sole risk and
#-		liability of any use of Xilinx products in Critical Applications, subject only to
#-		applicable laws and regulations governing limitations on product liability.
#-
#- THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
#-
#-		Contact:    e-mail  hotline@xilinx.com        phone   + 1 800 255 7778
#-   ____  ____
#-  /   /\/   /
#- /___/  \  / 			Vendor:              Xilinx Inc.
#- \   \   \/ 			Version:             V0.01
#-  \   \        		Filename:            Mmcme2_FuncSim.do
#-  /   /        		Date Created:        01-Oct-2018
#- /___/   /\    		Date Last Modified:  26-Jun-2019
#- \   \  /  \
#-  \___\/\___\
#-
#- Device:          7-Series, Ultrascale, Ultrascale+
#- Author:          Defossez
#- Entity Name:     Mmcm_Pll_FuncSim
#- Purpose:
#- Tools:           Questa-Sim 10.7d or newer
#- Limitations:     none
#-
#- Revision History:
#-	Rev: 01-Oct-2018 - Defossez
#-		Original release of this and "MmcmPll_TopFuncSim.tcl" TCL scripts.
#-	Rev: 26-Jun-2019 - defossez
#-		Script adapted to get rid of deprecated QuestSim command option -vopt.
#-		Add some user guideline "to display in the transcript window" text into
#-		bothe TCL files.
#--------------------------------------------------------------------------------------------
# This script can be executed from within the QuestaSim GUI.
#   - Start Questa-Sim
#   -       Click: [Tools] tab
#   -       Select: Tcl
#   -       Select: Execute Macro
#   -           Browse to find this file.
#   -           Select it and hit [Open].
#--------------------------------------------------------------------------------------------
# In a project the directory containing this and other simulation scripts is: /SimScripts.
# In a project the directory containing the files used for simulation is: /Simulation.
# It is assumed here that Questa-Sim is started from the desktop icon. The directory it starts
# in is the directory set in the icons "Start in:" box.
# It is assumed that this directory is E:/Projects
# It is thus necessary to change to the projects /Simulation directory in order to run this
# .do file.
# When the project is located somewhere else, change this path:
#--------------------------------------------------------------------------------------------
# cd ../Simulation
cd Simulation
#--------------------------------------------------------------------------------------------
#- Check if there is a basic design library, if not create it (name it by default 'work').
#- Create other design libraries depending the hierarchy of the design.
#--------------------------------------------------------------------------------------------
if {![file exists work]} {
    vlib work
}
#--------------------------------------------------------------------------------------------
#- Change the static path to the glbl.v file following the installation used!
#-
vlog -work work {C:\CaeTools\Xilinx\2019_1\Vivado\2019.1\data\verilog\src\glbl.v}
#-
# vlog -work work  ../../$1/${2}_drp_func.h
vlog -work work   ../../$1/${2}_drp.v
vlog -work work   ../../$1/top_${2}.v
vlog -work work   ../../$1/top_${2}_tb.v
#--------------------------------------------------------------------------------------------
#-
vsim -voptargs="+acc" -t ps -L unisims_ver -L unimacro_ver -L secureip work.top_tb work.glbl
#-
#--------------------------------------------------------------------------------------------
#- Invoke from here the waveform file in the Questa-Sim viewer.
#- The waveform file can be generated from a initial waveform setup in the GUI.
#--------------------------------------------------------------------------------------------
if {$1 == "MMCME2_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_7Series_Mmcm.do
}
if {$1 == "PLLE2_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_7Series_Pll.do
}
if {$1 == "MMCME3_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_Ultrscl_Mmcm.do
}
if {$1 == "PLLE3_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_Ultrscl_Pll.do
}
if {$1 == "MMCME4_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_UltrsclPls_Mmcm.do
}
if {$1 == "PLLE4_DRP"} {
  do ../SimScripts/MmcmPll_FuncWave_UltrsclPls_Pll.do
}
#--------------------------------------------------------------------------------------------
#- Run the simulation
#--------------------------------------------------------------------------------------------
run 1000000
#--------------------------------------------------------------------------------------------
#-
puts ""
puts ""
puts " WARNING!"
puts " Quit the simulation by typing\: \"quit \-sim\" in the transcript window "
puts " If the simulation needs to be rerun afterwards perform first a: \"cd \.\.\" command "
puts " in the transcript window. "
puts ""
#-
#--------------------------------------------------------------------------------------------
#-