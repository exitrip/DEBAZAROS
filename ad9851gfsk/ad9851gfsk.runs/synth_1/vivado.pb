
�
�You are suppressing all messages of type '%s'. You may potentially disregard important DRC, CDC, and implementation messages that can negatively impact your design.  If this is not desired, please run 'reset_msg_config -suppress -severity {%s}' to undo this change.598*common2
WARNING2default:default2
WARNING2default:defaultZ17-1355h px� 
�
�You are suppressing all messages of type '%s'. You may potentially disregard important DRC, CDC, and implementation messages that can negatively impact your design.  If this is not desired, please run 'reset_msg_config -suppress -severity {%s}' to undo this change.598*common2$
CRITICAL WARNING2default:default2$
CRITICAL WARNING2default:defaultZ17-1355h px� 
>
Refreshing IP repositories
234*coregenZ19-234hpx� 
�
 Loaded user IP repository '%s'.
1135*coregen2V
B/home/guido/Github/EBAZ4205_SDR_spectrum/ip_repo/ad9851gfsk_ip_1_02default:defaultZ19-1700hpx� 
�
"Loaded Vivado IP repository '%s'.
1332*coregen27
#/tools/Xilinx/Vivado/2022.2/data/ip2default:defaultZ19-2313hpx� 
�
Command: %s
1870*	planAhead2�
�read_checkpoint -auto_incremental -incremental /home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/utils_1/imports/synth_1/ad9851gfsk_ip_v1_0_bfm_1_wrapper.dcp2default:defaultZ12-2866hpx� 
�
;Read reference checkpoint from %s for incremental synthesis3154*	planAhead2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/utils_1/imports/synth_1/ad9851gfsk_ip_v1_0_bfm_1_wrapper.dcp2default:defaultZ12-5825hpx� 
T
-Please ensure there are no constraint changes3725*	planAheadZ12-7989hpx� 
�
Command: %s
53*	vivadotcl2\
Hsynth_design -top ad9851gfsk_ip_v1_0_bfm_1_wrapper -part xc7z010clg400-12default:defaultZ4-113hpx� 
:
Starting synth_design
149*	vivadotclZ4-321hpx� 
�
@Attempting to get a license for feature '%s' and/or device '%s'
308*common2
	Synthesis2default:default2
xc7z0102default:defaultZ17-347hpx� 
�
0Got license for feature '%s' and/or device '%s'
310*common2
	Synthesis2default:default2
xc7z0102default:defaultZ17-349hpx� 
V
Loading part %s157*device2#
xc7z010clg400-12default:defaultZ21-403hpx� 

VNo compile time benefit to using incremental synthesis; A full resynthesis will be run2353*designutilsZ20-5440hpx� 
�
�Flow is switching to default flow due to incremental criteria not met. If you would like to alter this behaviour and have the flow terminate instead, please set the following parameter config_implementation {autoIncr.Synth.RejectBehavior Terminate}2229*designutilsZ20-4379hpx� 
�
HMultithreading enabled for synth_design using a maximum of %s processes.4828*oasys2
42default:defaultZ8-7079hpx� 
a
?Launching helper process for spawning children vivado processes4827*oasysZ8-7078hpx� 
b
#Helper process launched with PID %s4824*oasys2
14366472default:defaultZ8-7075hpx� 
�
5undeclared symbol '%s', assumed default net type '%s'7502*oasys2
REGCCE2default:default2
wire2default:default2_
I/tools/Xilinx/Vivado/2022.2/data/verilog/src/unimacro/BRAM_SINGLE_MACRO.v2default:default2
21702default:default8@Z8-11241hpx� 
�
%s*synth2�
�Starting RTL Elaboration : Time (s): cpu = 00:00:02 ; elapsed = 00:00:02 . Memory (MB): peak = 1968.582 ; gain = 364.766 ; free physical = 14255 ; free virtual = 25607
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 2966.988; parent = 1968.586; children = 998.402
2default:defaulth px� 
�
synthesizing module '%s'638*oasys24
 ad9851gfsk_ip_v1_0_bfm_1_wrapper2default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
212default:default8@Z8-638hpx� 
�
-Port '%s' is missing in component declaration4102*oasys2

data_out_02default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
222default:default8@Z8-5640hpx� 
�
-Port '%s' is missing in component declaration4102*oasys2 
pwm_am_out_02default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
222default:default8@Z8-5640hpx� 
�
-Port '%s' is missing in component declaration4102*oasys2#
read_data_out_02default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
222default:default8@Z8-5640hpx� 
�
Hmodule '%s' declared at '%s:%s' bound to instance '%s' of component '%s'3392*oasys2,
ad9851gfsk_ip_v1_0_bfm_12default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/synth/ad9851gfsk_ip_v1_0_bfm_1.vhd2default:default2
142default:default2.
ad9851gfsk_ip_v1_0_bfm_1_i2default:default2,
ad9851gfsk_ip_v1_0_bfm_12default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
292default:default8@Z8-3491hpx� 
�
synthesizing module '%s'638*oasys2,
ad9851gfsk_ip_v1_0_bfm_12default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/synth/ad9851gfsk_ip_v1_0_bfm_1.vhd2default:default2
282default:default8@Z8-638hpx� 
�
Hmodule '%s' declared at '%s:%s' bound to instance '%s' of component '%s'3392*oasys2;
'ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/.Xil/Vivado-1436577-guido-Neptune-series-i9/realtime/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0_stub.vhdl2default:default2
52default:default2 
ad9851gfsk_02default:default2;
'ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/synth/ad9851gfsk_ip_v1_0_bfm_1.vhd2default:default2
1182default:default8@Z8-3491hpx� 
�
synthesizing module '%s'638*oasys2;
'ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/.Xil/Vivado-1436577-guido-Neptune-series-i9/realtime/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0_stub.vhdl2default:default2
352default:default8@Z8-638hpx� 
�
Hmodule '%s' declared at '%s:%s' bound to instance '%s' of component '%s'3392*oasys27
#ad9851gfsk_ip_v1_0_bfm_1_master_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/.Xil/Vivado-1436577-guido-Neptune-series-i9/realtime/ad9851gfsk_ip_v1_0_bfm_1_master_0_0_stub.vhdl2default:default2
52default:default2
master_02default:default27
#ad9851gfsk_ip_v1_0_bfm_1_master_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/synth/ad9851gfsk_ip_v1_0_bfm_1.vhd2default:default2
1452default:default8@Z8-3491hpx� 
�
synthesizing module '%s'638*oasys27
#ad9851gfsk_ip_v1_0_bfm_1_master_0_02default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/.Xil/Vivado-1436577-guido-Neptune-series-i9/realtime/ad9851gfsk_ip_v1_0_bfm_1_master_0_0_stub.vhdl2default:default2
322default:default8@Z8-638hpx� 
�
%done synthesizing module '%s' (%s#%s)256*oasys2,
ad9851gfsk_ip_v1_0_bfm_12default:default2
02default:default2
12default:default2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/synth/ad9851gfsk_ip_v1_0_bfm_1.vhd2default:default2
282default:default8@Z8-256hpx� 
�
%done synthesizing module '%s' (%s#%s)256*oasys24
 ad9851gfsk_ip_v1_0_bfm_1_wrapper2default:default2
02default:default2
12default:default2�
~/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.srcs/sources_1/imports/hdl/ad9851gfsk_ip_v1_0_bfm_1_wrapper.vhd2default:default2
212default:default8@Z8-256hpx� 
�
%s*synth2�
�Finished RTL Elaboration : Time (s): cpu = 00:00:03 ; elapsed = 00:00:03 . Memory (MB): peak = 2035.551 ; gain = 431.734 ; free physical = 14342 ; free virtual = 25693
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3033.957; parent = 2035.555; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
M
%s
*synth25
!Start Handling Custom Attributes
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Handling Custom Attributes : Time (s): cpu = 00:00:03 ; elapsed = 00:00:03 . Memory (MB): peak = 2053.363 ; gain = 449.547 ; free physical = 14342 ; free virtual = 25694
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3051.770; parent = 2053.367; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished RTL Optimization Phase 1 : Time (s): cpu = 00:00:03 ; elapsed = 00:00:03 . Memory (MB): peak = 2053.363 ; gain = 449.547 ; free physical = 14342 ; free virtual = 25694
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3051.770; parent = 2053.367; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common2.
Netlist sorting complete. 2default:default2
00:00:002default:default2
00:00:002default:default2
2053.3632default:default2
0.0002default:default2
143382default:default2
256892default:defaultZ17-722h px� 
K
)Preparing netlist for logic optimization
349*projectZ1-570hpx� 
>

Processing XDC Constraints
244*projectZ1-262hpx� 
=
Initializing timing engine
348*projectZ1-569hpx� 
�
$Parsing XDC File [%s] for cell '%s'
848*designutils2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/ip/ad9851gfsk_ip_v1_0_bfm_1_master_0_0/ad9851gfsk_ip_v1_0_bfm_1_master_0_0/ad9851gfsk_ip_v1_0_bfm_1_master_0_0_in_context.xdc2default:default29
#ad9851gfsk_ip_v1_0_bfm_1_i/master_0	2default:default8Z20-848hpx� 
�
-Finished Parsing XDC File [%s] for cell '%s'
847*designutils2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/ip/ad9851gfsk_ip_v1_0_bfm_1_master_0_0/ad9851gfsk_ip_v1_0_bfm_1_master_0_0/ad9851gfsk_ip_v1_0_bfm_1_master_0_0_in_context.xdc2default:default29
#ad9851gfsk_ip_v1_0_bfm_1_i/master_0	2default:default8Z20-847hpx� 
�
$Parsing XDC File [%s] for cell '%s'
848*designutils2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/ip/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0_in_context.xdc2default:default2=
'ad9851gfsk_ip_v1_0_bfm_1_i/ad9851gfsk_0	2default:default8Z20-848hpx� 
�
-Finished Parsing XDC File [%s] for cell '%s'
847*designutils2�
�/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.gen/sources_1/bd/ad9851gfsk_ip_v1_0_bfm_1/ip/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0/ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0_in_context.xdc2default:default2=
'ad9851gfsk_ip_v1_0_bfm_1_i/ad9851gfsk_0	2default:default8Z20-847hpx� 
�
Parsing XDC File [%s]
179*designutils2p
Z/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/dont_touch.xdc2default:default8Z20-179hpx� 
�
Finished Parsing XDC File [%s]
178*designutils2p
Z/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/dont_touch.xdc2default:default8Z20-178hpx� 
H
&Completed Processing XDC Constraints

245*projectZ1-263hpx� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common2.
Netlist sorting complete. 2default:default2
00:00:002default:default2
00:00:002default:default2
2102.2892default:default2
0.0002default:default2
142702default:default2
256112default:defaultZ17-722h px� 
~
!Unisim Transformation Summary:
%s111*project29
%No Unisim elements were transformed.
2default:defaultZ1-111hpx� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common24
 Constraint Validation Runtime : 2default:default2
00:00:002default:default2
00:00:002default:default2
2102.2892default:default2
0.0002default:default2
142702default:default2
256112default:defaultZ17-722h px� 

VNo compile time benefit to using incremental synthesis; A full resynthesis will be run2353*designutilsZ20-5440hpx� 
�
�Flow is switching to default flow due to incremental criteria not met. If you would like to alter this behaviour and have the flow terminate instead, please set the following parameter config_implementation {autoIncr.Synth.RejectBehavior Terminate}2229*designutilsZ20-4379hpx� 
�
5undeclared symbol '%s', assumed default net type '%s'7502*oasys2
REGCCE2default:default2
wire2default:default2_
I/tools/Xilinx/Vivado/2022.2/data/verilog/src/unimacro/BRAM_SINGLE_MACRO.v2default:default2
21702default:default8@Z8-11241hpx� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Constraint Validation : Time (s): cpu = 00:00:06 ; elapsed = 00:00:06 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14325 ; free virtual = 25667
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
V
%s
*synth2>
*Start Loading Part and Timing Information
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
J
%s
*synth22
Loading part: xc7z010clg400-1
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Loading Part and Timing Information : Time (s): cpu = 00:00:06 ; elapsed = 00:00:06 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14325 ; free virtual = 25667
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
Z
%s
*synth2B
.Start Applying 'set_property' XDC Constraints
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished applying 'set_property' XDC Constraints : Time (s): cpu = 00:00:06 ; elapsed = 00:00:06 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14325 ; free virtual = 25667
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished RTL Optimization Phase 2 : Time (s): cpu = 00:00:06 ; elapsed = 00:00:07 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14323 ; free virtual = 25665
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
L
%s
*synth24
 Start RTL Component Statistics 
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
K
%s
*synth23
Detailed RTL Component Info : 
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
O
%s
*synth27
#Finished RTL Component Statistics 
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
H
%s
*synth20
Start Part Resource Summary
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s
*synth2j
VPart Resources:
DSPs: 80 (col length:40)
BRAMs: 120 (col length: RAMB18 40 RAMB36 20)
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
K
%s
*synth23
Finished Part Resource Summary
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
W
%s
*synth2?
+Start Cross Boundary and Area Optimization
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
H
&Parallel synthesis criteria is not met4829*oasysZ8-7080hpx� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Cross Boundary and Area Optimization : Time (s): cpu = 00:00:07 ; elapsed = 00:00:07 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14320 ; free virtual = 25666
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1356.693; parent = 1152.385; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
R
%s
*synth2:
&Start Applying XDC Timing Constraints
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Applying XDC Timing Constraints : Time (s): cpu = 00:00:09 ; elapsed = 00:00:10 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14201 ; free virtual = 25547
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1427.509; parent = 1223.242; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
F
%s
*synth2.
Start Timing Optimization
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Timing Optimization : Time (s): cpu = 00:00:09 ; elapsed = 00:00:10 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14201 ; free virtual = 25547
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1427.638; parent = 1223.371; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
E
%s
*synth2-
Start Technology Mapping
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Technology Mapping : Time (s): cpu = 00:00:09 ; elapsed = 00:00:10 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14197 ; free virtual = 25543
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.442; parent = 1224.176; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
?
%s
*synth2'
Start IO Insertion
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
Q
%s
*synth29
%Start Flattening Before IO Insertion
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
T
%s
*synth2<
(Finished Flattening Before IO Insertion
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
H
%s
*synth20
Start Final Netlist Cleanup
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
K
%s
*synth23
Finished Final Netlist Cleanup
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished IO Insertion : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.614; parent = 1224.348; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
O
%s
*synth27
#Start Renaming Generated Instances
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Renaming Generated Instances : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.618; parent = 1224.352; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
L
%s
*synth24
 Start Rebuilding User Hierarchy
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Rebuilding User Hierarchy : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.634; parent = 1224.367; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
K
%s
*synth23
Start Renaming Generated Ports
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Renaming Generated Ports : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.712; parent = 1224.445; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
M
%s
*synth25
!Start Handling Custom Attributes
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Handling Custom Attributes : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.712; parent = 1224.445; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
J
%s
*synth22
Start Renaming Generated Nets
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Renaming Generated Nets : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.728; parent = 1224.461; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
K
%s
*synth23
Start Writing Synthesis Report
2default:defaulthp
x
� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
A
%s
*synth2)

Report BlackBoxes: 
2default:defaulthp
x
� 
i
%s
*synth2Q
=+------+----------------------------------------+----------+
2default:defaulthp
x
� 
i
%s
*synth2Q
=|      |BlackBox name                           |Instances |
2default:defaulthp
x
� 
i
%s
*synth2Q
=+------+----------------------------------------+----------+
2default:defaulthp
x
� 
i
%s
*synth2Q
=|1     |ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0 |         1|
2default:defaulthp
x
� 
i
%s
*synth2Q
=|2     |ad9851gfsk_ip_v1_0_bfm_1_master_0_0     |         1|
2default:defaulthp
x
� 
i
%s
*synth2Q
=+------+----------------------------------------+----------+
2default:defaulthp
x
� 
A
%s*synth2)

Report Cell Usage: 
2default:defaulth px� 
j
%s*synth2R
>+------+---------------------------------------------+------+
2default:defaulth px� 
j
%s*synth2R
>|      |Cell                                         |Count |
2default:defaulth px� 
j
%s*synth2R
>+------+---------------------------------------------+------+
2default:defaulth px� 
j
%s*synth2R
>|1     |ad9851gfsk_ip_v1_0_bfm_1_ad9851gfsk_0_0_bbox |     1|
2default:defaulth px� 
j
%s*synth2R
>|2     |ad9851gfsk_ip_v1_0_bfm_1_master_0_0_bbox     |     1|
2default:defaulth px� 
j
%s*synth2R
>|3     |IBUF                                         |     2|
2default:defaulth px� 
j
%s*synth2R
>+------+---------------------------------------------+------+
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
�
%s*synth2�
�Finished Writing Synthesis Report : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14180 ; free virtual = 25542
2default:defaulth px� 
�
%s*synth2~
jSynthesis current peak Physical Memory [PSS] (MB): peak = 1428.759; parent = 1224.492; children = 204.309
2default:defaulth px� 
�
%s*synth2}
iSynthesis current peak Virtual Memory [VSS] (MB): peak = 3068.680; parent = 2070.277; children = 998.402
2default:defaulth px� 
~
%s
*synth2f
R---------------------------------------------------------------------------------
2default:defaulthp
x
� 
r
%s
*synth2Z
FSynthesis finished with 0 errors, 0 critical warnings and 1 warnings.
2default:defaulthp
x
� 
�
%s
*synth2�
�Synthesis Optimization Runtime : Time (s): cpu = 00:00:11 ; elapsed = 00:00:11 . Memory (MB): peak = 2102.289 ; gain = 449.547 ; free physical = 14234 ; free virtual = 25596
2default:defaulthp
x
� 
�
%s
*synth2�
�Synthesis Optimization Complete : Time (s): cpu = 00:00:11 ; elapsed = 00:00:12 . Memory (MB): peak = 2102.289 ; gain = 498.473 ; free physical = 14234 ; free virtual = 25596
2default:defaulthp
x
� 
B
 Translating synthesized netlist
350*projectZ1-571hpx� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common2.
Netlist sorting complete. 2default:default2
00:00:002default:default2
00:00:002default:default2
2102.2892default:default2
0.0002default:default2
143472default:default2
257092default:defaultZ17-722h px� 
K
)Preparing netlist for logic optimization
349*projectZ1-570hpx� 
u
)Pushed %s inverter(s) to %s load pin(s).
98*opt2
02default:default2
02default:defaultZ31-138hpx� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common2.
Netlist sorting complete. 2default:default2
00:00:002default:default2
00:00:002default:default2
2102.2892default:default2
0.0002default:default2
142852default:default2
256512default:defaultZ17-722h px� 
~
!Unisim Transformation Summary:
%s111*project29
%No Unisim elements were transformed.
2default:defaultZ1-111hpx� 
g
$Synth Design complete, checksum: %s
562*	vivadotcl2
56cb9cd32default:defaultZ4-1430hpx� 
U
Releasing license: %s
83*common2
	Synthesis2default:defaultZ17-83hpx� 
�
G%s Infos, %s Warnings, %s Critical Warnings and %s Errors encountered.
28*	vivadotcl2
02default:default2
02default:default2
22default:default2
02default:defaultZ4-41hpx� 
^
%s completed successfully
29*	vivadotcl2 
synth_design2default:defaultZ4-42hpx� 
�
r%sTime (s): cpu = %s ; elapsed = %s . Memory (MB): peak = %s ; gain = %s ; free physical = %s ; free virtual = %s
480*common2"
synth_design: 2default:default2
00:00:162default:default2
00:00:152default:default2
2102.2892default:default2
756.8522default:default2
144882default:default2
258542default:defaultZ17-722h px� 
�
 The %s '%s' has been generated.
621*common2

checkpoint2default:default2�
p/home/guido/Github/EBAZ4205_SDR_spectrum/ad9851gfsk/ad9851gfsk.runs/synth_1/ad9851gfsk_ip_v1_0_bfm_1_wrapper.dcp2default:defaultZ17-1381hpx� 
�
%s4*runtcl2�
�Executing : report_utilization -file ad9851gfsk_ip_v1_0_bfm_1_wrapper_utilization_synth.rpt -pb ad9851gfsk_ip_v1_0_bfm_1_wrapper_utilization_synth.pb
2default:defaulthpx� 
�
Exiting %s at %s...
206*common2
Vivado2default:default2,
Sun Sep 17 21:38:37 20232default:defaultZ17-206hpx� 


End Record