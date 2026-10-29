# 2026-10-29_dz_osc2.tcl - BD edit: the two DDS (dds_axi_interface_0/1 +
# HDMI_0/HDMI_1 dds_compiler_0) -> one module reference dz_osc2_0
# (hw/rtl/dz_osc/, ROADMAP.md section 14) at 0x43D0_0000, 32 KB: channel 0
# at +0x0000 (the old HDMI_0 DDS address), channel 1 at +0x4000 (was
# 0x44D0_0000). ps7_axi_periph shrinks from 10 to 9 master ports (M09 audio
# -> M08; no port is left unconnected).
#
# One-time edit of the BD source (hw/bd/<variant>.tcl), in this order:
#   vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in project dds
#   vivado -mode batch -source hw/bd_edits/2026-10-29_dz_osc2.tcl \
#          -tclargs build/dds/ebaz4205_2out1in.xpr
#   vivado -mode batch -source hw/export_bd.tcl \
#          -tclargs ebaz4205_2out1in build/dds/ebaz4205_2out1in.xpr
#   git diff hw/bd/ebaz4205_2out1in.tcl     (review), then hw/build.tcl build
#
# What stays (the "sliders" after the generators, ROADMAP.md section 14,
# INTENTIONAL wrap / fold math): both div16_8_recip pairs with their GPIO
# denominators, the offset adders, the oscillator gains. Per channel:
#   wave<n>  (16 bit, two's complement sine as the compiler's) -> div16_8_recip_0/num
#   phase<n> (phase[31:16], aligned with wave, was xlslice_4)  -> div16_8_recip_1/num
#   phase0_full (32 bit) -> hdmi_audio_regs_0/dds_phase (event block, was HDMI_0/dds_phase)
# The dividers' ce came from the compiler's TVALID (high all the time): now 1.
# Raster in: HDMI_0/vsync_out, hsync_out, active_video_out (the shared VTC,
# discrete nets as for HDMI_1). ext_trig = 0 for now.
set repo [file normalize [file join [file dirname [info script]] ../..]]
set xpr  [file normalize [lindex $argv 0]]
open_project $xpr
foreach f {dz_osc2.v dz_osc_ch.v dz_sine_rom.v} {
    if {[get_files -quiet $repo/hw/rtl/dz_osc/$f] eq ""} {
        add_files -norecurse $repo/hw/rtl/dz_osc/$f
    }
}
update_compile_order -fileset sources_1
open_bd_design [get_files ebaz4205.bd]

# the interface pin at the other end of the interface net of $ipin
proc peer {ipin} {
    set p0 [get_bd_intf_pins $ipin]
    set n [get_bd_intf_nets -of_objects $p0]
    foreach p [get_bd_intf_pins -of_objects $n] {
        if {[get_property PATH $p] ne [get_property PATH $p0]} { return $p }
    }
    error "no peer for $ipin"
}
proc drop_net {pin} {
    set n [get_bd_nets -quiet -of_objects [get_bd_pins $pin]]
    if {$n ne ""} { delete_bd_objs $n }
}

# ---- 1. checks + the subordinate that moves (M09 audio -> M08) ---------------------
foreach h {HDMI_0 HDMI_1} {
    set w [get_property CONFIG.DIN_WIDTH [get_bd_cells $h/xlslice_4]]
    set f [get_property CONFIG.DIN_FROM  [get_bd_cells $h/xlslice_4]]
    if {$w != 32 || $f != 31} { error "$h/xlslice_4 is not the phase slice ($w, $f)" }
}
set audio [peer ps7_axi_periph/M09_AXI]
puts "INFO: M09 = $audio"

# ---- 2. inside HDMI_0 / HDMI_1: compiler and phase slice out, pins in ---------------
foreach h {HDMI_0 HDMI_1} {
    foreach pin {dds_compiler_0/m_axis_data_tdata dds_compiler_0/m_axis_data_tvalid
                 dds_compiler_0/m_axis_phase_tdata dds_compiler_0/m_axis_phase_tvalid
                 xlslice_4/Dout} {
        drop_net $h/$pin
    }
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins $h/dds_stream_s]]
    delete_bd_objs [get_bd_intf_pins $h/dds_stream_s]
    delete_bd_objs [get_bd_cells $h/dds_compiler_0] [get_bd_cells $h/xlslice_4]
    create_bd_pin -dir I -from 15 -to 0 $h/osc_wave
    create_bd_pin -dir I -from 15 -to 0 $h/osc_phase
    connect_bd_net [get_bd_pins $h/osc_wave]  [get_bd_pins $h/div16_8_recip_0/num]
    connect_bd_net [get_bd_pins $h/osc_phase] [get_bd_pins $h/div16_8_recip_1/num]
    set c [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 $h/osc_ce]
    set_property -dict [list CONFIG.CONST_VAL {1} CONFIG.CONST_WIDTH {1}] $c
    connect_bd_net [get_bd_pins $h/osc_ce/dout] \
        [get_bd_pins $h/div16_8_recip_0/ce] [get_bd_pins $h/div16_8_recip_1/ce]
}
drop_net hdmi_audio_regs_0/dds_phase
delete_bd_objs [get_bd_pins HDMI_0/dds_phase]

# ---- 3. top: the two AXI interfaces out, interconnect 9 ports ----------------------
foreach m {M07 M08 M09} {
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins ps7_axi_periph/${m}_AXI]]
}
delete_bd_objs [get_bd_cells dds_axi_interface_0] [get_bd_cells dds_axi_interface_1]
set_property CONFIG.NUM_MI {9} [get_bd_cells ps7_axi_periph]
connect_bd_intf_net [get_bd_intf_pins ps7_axi_periph/M08_AXI] $audio
for {set i 0} {$i < 9} {incr i} {
    set m [format M%02d $i]
    if {[get_bd_nets -quiet -of_objects [get_bd_pins ps7_axi_periph/${m}_ACLK]] eq ""} {
        connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins ps7_axi_periph/${m}_ACLK]
    }
    if {[get_bd_nets -quiet -of_objects [get_bd_pins ps7_axi_periph/${m}_ARESETN]] eq ""} {
        connect_bd_net -net PS_ARESETN [get_bd_pins ps7_axi_periph/${m}_ARESETN]
    }
}

# ---- 4. dz_osc2_0 and its connections ------------------------------------------------
create_bd_cell -type module -reference dz_osc2 dz_osc2_0
connect_bd_intf_net [get_bd_intf_pins ps7_axi_periph/M07_AXI] [get_bd_intf_pins dz_osc2_0/s_axi]
connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins dz_osc2_0/clk]
connect_bd_net -net PS_ARESETN [get_bd_pins dz_osc2_0/aresetn]
connect_bd_net [get_bd_pins HDMI_0/vsync_out]        [get_bd_pins dz_osc2_0/vsync]
connect_bd_net [get_bd_pins HDMI_0/hsync_out]        [get_bd_pins dz_osc2_0/hsync]
connect_bd_net [get_bd_pins HDMI_0/active_video_out] [get_bd_pins dz_osc2_0/line_de]
set c [create_bd_cell -type ip -vlnv xilinx.com:ip:xlconstant:1.1 osc_trig_0]
set_property -dict [list CONFIG.CONST_VAL {0} CONFIG.CONST_WIDTH {1}] $c
connect_bd_net [get_bd_pins osc_trig_0/dout] [get_bd_pins dz_osc2_0/ext_trig]
connect_bd_net [get_bd_pins dz_osc2_0/wave0]  [get_bd_pins HDMI_0/osc_wave]
connect_bd_net [get_bd_pins dz_osc2_0/phase0] [get_bd_pins HDMI_0/osc_phase]
connect_bd_net [get_bd_pins dz_osc2_0/wave1]  [get_bd_pins HDMI_1/osc_wave]
connect_bd_net [get_bd_pins dz_osc2_0/phase1] [get_bd_pins HDMI_1/osc_phase]
connect_bd_net [get_bd_pins dz_osc2_0/phase0_full] [get_bd_pins hdmi_audio_regs_0/dds_phase]

# ---- 5. address, check, save -----------------------------------------------------------
assign_bd_address -offset 0x43D00000 -range 32K \
    -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] \
    [get_bd_addr_segs dz_osc2_0/s_axi/reg0]
validate_bd_design
save_bd_design
puts "INFO: dz_osc2 edit done; now hw/export_bd.tcl"
close_project
