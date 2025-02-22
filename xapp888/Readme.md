*************************************************************************
```
   ____  ____
  /   /\/   /
 /___/  \  /
 \   \   \/    Copyright 2011-2019 Xilinx, Inc. All rights reserved.
  \   \        This file contains confidential and proprietary
  /   /        information of Xilinx, Inc. and is protected under U.S.
 /___/   /\    and international copyright and other intellectual
 \   \  /  \   property laws.
  \___\/\___\
```
*************************************************************************
```
Vendor:                 Xilinx
Current:                ReadMe.txt
Version:                2.8
Date Last Modified:     19 Jun 19
Date Created:           15 Nov 16
Associated Filename:    xapp888.zip
Associated Document:    XAPP888.
Supported Device(s):    7 series, UltraScale, UltraScale+, and Zynq UltraScale+ devices
Purpose:                Dynamic Reconfiguration Reference Design for MMCME2, MMCME3
                        MMCME4, PLLE2, PLLE3 and PLLE4
Reference:
```
*************************************************************************
Disclaimer:
```
      This disclaimer is not a license and does not grant any rights to
      the materials distributed herewith. Except as otherwise provided in
      a valid license issued to you by Xilinx, and to the maximum extent
      permitted by applicable law: (1) THESE MATERIALS ARE MADE AVAILABLE
      "AS IS" AND WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL
      WARRANTIES AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY,
      INCLUDING BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY,
      NON-INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
      (2) Xilinx shall not be liable (whether in contract or tort,
      including negligence, or under any other theory of liability) for
      any loss or damage of any kind or nature related to, arising under
      or in connection with these materials, including for any direct, or
      any indirect, special, incidental, or consequential loss or damage
      (including loss of data, profits, goodwill, or any type of loss or
      damage suffered as a result of any action brought by a third party)
      even if such damage or loss was reasonably foreseeable or Xilinx
      had been advised of the possibility of the same.
```
Critical Applications:
```
      Xilinx products are not designed or intended to be fail-safe, or
      for use in any application requiring fail-safe performance, such as
      life-support or safety devices or systems, Class III medical
      devices, nuclear facilities, applications related to the deployment
      of airbags, or any other applications that could lead to death,
      personal injury, or severe property or environmental damage
      (individually and collectively, "Critical Applications"). Customer
      assumes the sole risk and liability of any use of Xilinx products
      in Critical Applications, subject only to applicable laws and
      regulations governing limitations on product liability.
```
THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS PART OF THIS FILE AT ALL TIMES.
*************************************************************************
This readme file contains these sections:

1. REVISION HISTORY
2. OVERVIEW
3. SOFTWARE TOOLS AND SYSTEM REQUIREMENTS
4. DESIGN FILE HIERARCHY
5. INSTALLATION AND OPERATING INSTRUCTIONS
6. OTHER INFORMATION (OPTIONAL)
7. SUPPORT


1. REVISION HISTORY

This readme describes how to use the files that come with XAPP888

*******************************************************************************
```
| Date       | Version | Revision Description                                        |
| ---------- | ------- | ------------------------------------------------------------|
| 7/19/2011  | 1.0     | Initial Xilinx release.                                     |
| 2/27/2012  | 1.01    | Removed CLKOUT6 in top_plle2_tb.v                           |
| 11/27/2012 | 1.02    | Updated plle2_drp_func.h and mmcme2_drp_func.h              |
| 5/30/2013  | 1.03    | Fixed error message for duty_cycle in mmcme2_drp_func.h     |
|            |         | and plle2_drp_func.h.                                       |
|            |         | Adds Fractional divide support for MMCME2                   |
| 7/30/2014  |   1.04  | Added MMCME3 and PLLE3                                      |
| 10/22/2014 |   1.5   | Added DRP calculations using TCL commands                   |
|            |         | Adjusted mmcme2_drp_func.h, mmcme3_drp_func.h,              |
|            |         | mmcme2_drp.v, mmcme3_drp.v to break out reg1/reg2/          |
|            |         | shared registers                                            |
| 2/10/2015  |   1.6   | Updating readme and verilog headers for clarity.            |
|            |         | PLLE2_DRP.v and PLLE3_DRP.v updated include statement       |
| 6/8/2015   |   1.7   | Added PLLE3 TCL calculations                                |
|            |         | Updated plle3_drp_func.h plle3_drp.v                        |
|            |         | Aligns to new TCL scripts for 18, 1A, 4E and 4F             |
|            |         | DRP addresses                                               |
|            |         | Updated WAIT_LOCK in _drp.v                                 |
| 5/2/2016   |   1.8   | Updated mask bits in mmcme3_drp.v, *cr951173*               |
|            |         | Updated mmcme2_drp.v/mmcme3_drp.v FRAC_EN DRP               |
|            |         | order.                                                      |
|            |         | Updated top_mmcme3.v to match S1/S2 comments.               |
| 2/28/2017  |   1.9   | Updated for UltraScale+. Update loop filter setting.        |
|            |         | Changed CLKFBOUT_MULT to 2-128 in the MMCM and 2-21 in      |
|            |         | the PLL.                                                    |
| 4/17/2017  |   2.0   | Fixed PLL4_drp_funct.h/top_pll4.tcl lock settings for       |
|            |         | M=6 and M=7                                                 |
|            |         | Fixed PLL3_drp_funt.h lock settings                         |
| 5/7/2017   |   2.1   | Fixed duplicate 'include statement in  mmcme4.drp           |
| 10/17/2017 |   2.2   | Fixed MMCME3 and MMCME4 tcl scripts to fix incorrect phase  |
|            |         | shift reporting in some cases                               |
| 11/30/2017 |   2.3   | Fixed MMCME2, MMCME3 & MMCME4 tcl scripts. Rewrote phase    |
|            |         | calculation for proper rounding to the nearest possible     |
|            |         | phase                                                       |
| 12/18/2017 |   2.4   | Fixed incorrect calculations for fractional M counter.      |
| 7/10/2018  |   2.5   | Fixed incorrect duty cycle and frequency generation when    |
|            |         | CLKOUT_DIV > 64 and outside of the min/max duty cycle range |
| 9/17/2018  |   2.6   | Removed strange characters, blank lines and excess on       |
|            |         | trailing space characters from TCL files.                   | 
| 10/22/2018 |   2.7   | Add new CP/RES/LFHF lookup tables in header and TCL files   |
|            |         |(cr1010263). Solve several minor issues.                     |
|            |         | Added QuestaSim simulation.                                 |
| 06/19/2019 |   2.8   | Add for UltraScale and UltraScale+ the POSTCRC BANDWIDTH    |
|            |         | option. Use this option only when using a MMCME3, MMCME4,   |
|            |         | PLLE3, or PLLE4 with the SEM-IP core.                       |
| ---------- | ------- | ------------------------------------------------------------|
```
2. OVERVIEW
This document describes how to use the files that come with XAPP888.zip.

This archive contains the DRP state machines for both the MMCMs and PLLs of 7 series, UltraScale, and UltraScale+ devices. In each example, top.v provides an example setup that shows how the MMCME/PLLE should be
connected to the DRP state machine.

3. SOFTWARE TOOLS AND SYSTEM REQUIREMENTS
* Vivado 2017.1 or later

To use this setup include:
​     top_mmcme*.v
​     top_mmcme*_tb.v
​     mmcme*_drp.v

In addition mmcme*_drp_func.h must be located in the project directory.

4. DESIGN FILE HIERARCHY

  HDL Files
  ===========
```
\Source
 |
 +-----  \MMCME*_DRP Directories
 |          Contains the Verilog source for a reference design that will switch
 |          between two MMCME* configurations
 |           +--\top_mmcme*.v
 |                 Top level example design file demonstrating to
 |                 connect the mmcme2_drp and mmcme2_adv
 |           +--\mmcme*_drp.v
 |                 DRP state machine for the MMCM
 |           +--\mmcme*_drp_func.h
 |                 Function calls and tables used by mmcm_drp
 |           +--\top_mmcme*_tb.v
 |                 Testbench for simulation
 +-----  \PLLE*_DRP Directories
 |         Contains the Verilog source for a reference design that will switch
 |         between two PLLE2 configurations
 |           +--\top_plle*.v
 |                 Top level example design file demonstrating to
 |                 connect the plle2_drp and plle2_adv
 |           +--\plle*_drp.v
 |                 DRP state machine for the PLL
 |           +--\plle*_drp_func.h
 |                 Function calls and tables used by plle2_drp
 |           +--\top_plle*_tb.v
 |                 Testbench for simulation
 +----- \QuestaSim_Mmcm_Pll_simulation
 |           +--\SimScripts
 |                 Read the Readme_Simulation.md file for instructions.
 |           +--\simulation
 |                 Readme_Simulation.md (a text file)
 |       Readme.md
 |         This read me text, markdown formatted, file.
 |       Readme_MmcmPll_Specs.md
 |         MMCM and PLL specifications and attributes from the data sheet.
 |         
```

5. INSTALLATION AND OPERATING INSTRUCTIONS


6. OTHER INFORMATION (OPTIONAL)
   In the top level design file, the DRP signals have added the MARK_DEBUG
   for designers who would like to add ILA probes.

   See "Vivado Design Suite User Guide: Programming and Debugging" (UG908)
   for additional information on hardware debugging.

   ILA probes are not required. ILA cores will require additional resources
   when used.

7. Support

To obtain technical support for this reference design, go to
www.xilinx.com/support to locate answers to known issues in the Xilinx
Answers Database or to create a WebCase.
