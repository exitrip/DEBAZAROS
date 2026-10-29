# 2026-10-29_dz_regs.tcl - BD edit: the four AXI GPIOs that serve as register
# banks -> one module reference dz_regs_0 (hw/rtl/dz_regs/dz_regs.v) at
# 0x4120_0000, 512 KB, with the old GPIO addresses and offsets inside
# (ROADMAP.md section 14). ps7_axi_periph shrinks from 13 to 10 master ports
# (no port is left unconnected; addresses do not move, only port numbers).
#
# One-time edit of the BD source (hw/bd/<variant>.tcl), in this order:
#   vivado -mode batch -source hw/build.tcl -tclargs ebaz4205_2out1in project regs
#   vivado -mode batch -source hw/bd_edits/2026-10-29_dz_regs.tcl \
#          -tclargs build/regs/ebaz4205_2out1in.xpr
#   vivado -mode batch -source hw/export_bd.tcl \
#          -tclargs ebaz4205_2out1in build/regs/ebaz4205_2out1in.xpr
#   git diff hw/bd/ebaz4205_2out1in.tcl     (review), then hw/build.tcl build
# The edit keeps every consumer: the sink pins of each GPIO output are taken
# from the BD before anything is deleted, and the new outputs drive exactly
# those pins (the xlslice cells inside HDMI_0 / HDMI_1 stay as they are).
set repo [file normalize [file join [file dirname [info script]] ../..]]
set xpr  [file normalize [lindex $argv 0]]
open_project $xpr
add_files -norecurse $repo/hw/rtl/dz_regs/dz_regs.v
update_compile_order -fileset sources_1
open_bd_design [get_files ebaz4205.bd]

# the pins on the net of $pin, without $pin itself
proc sinks {pin} {
    set p0 [get_bd_pins $pin]
    set n [get_bd_nets -quiet -of_objects $p0]
    if {$n eq ""} { error "no net on $pin" }
    set r {}
    foreach p [get_bd_pins -of_objects $n] {
        if {[get_property PATH $p] ne [get_property PATH $p0]} { lappend r $p }
    }
    return $r
}
# the interface pin at the other end of the interface net of $ipin
proc peer {ipin} {
    set p0 [get_bd_intf_pins $ipin]
    set n [get_bd_intf_nets -of_objects $p0]
    foreach p [get_bd_intf_pins -of_objects $n] {
        if {[get_property PATH $p] ne [get_property PATH $p0]} { return $p }
    }
    error "no peer for $ipin"
}

set g0 axi_gpio_hdmi_in_phase0_div_gPhase1
set gm HDMI_0/axi_gpio_mainG_shift_memdelay
set go HDMI_1/axi_gpio_divOsc_gosc_shiftPhaseOsc
set gf HDMI_1/axi_gpio_divPhase_gmain_shiftPhase_gfeedback

# ---- 1. record the consumers ------------------------------------------------------
set s_b0  [sinks $g0/gpio2_io_o]
set s_irq [sinks $g0/ip2intc_irpt]
set d_in  [sinks $g0/gpio_io_i]          ;# the driver: xlconcat_0/dout
set s_m1  [sinks $gm/gpio_io_o]
set s_m2  [sinks $gm/gpio2_io_o]
set s_o1  [sinks $go/gpio_io_o]
set s_o2  [sinks $go/gpio2_io_o]
set s_f1  [sinks $gf/gpio_io_o]
set s_f2  [sinks $gf/gpio2_io_o]
puts "INFO: consumers b0 {$s_b0} irq {$s_irq} in {$d_in}"
puts "INFO: main {$s_m1} / {$s_m2}  osc {$s_o1} / {$s_o2}  fb {$s_f1} / {$s_f2}"
# the subordinates on the ports that move (M08, M09, M11, M12 -> M06..M09)
set mv {}
foreach {from to} {M08 M06 M09 M07 M11 M08 M12 M09} {
    lappend mv $to [peer ps7_axi_periph/${from}_AXI]
}
puts "INFO: port moves $mv"

# ---- 2. remove the GPIOs, their AXI nets and hierarchy interface pins ---------------
foreach pin [list $g0/gpio2_io_o $g0/ip2intc_irpt $g0/gpio_io_i $gm/gpio_io_o $gm/gpio2_io_o \
                 $go/gpio_io_o $go/gpio2_io_o $gf/gpio_io_o $gf/gpio2_io_o] {
    delete_bd_objs [get_bd_nets -of_objects [get_bd_pins $pin]]
}
foreach m {M00 M06 M07 M08 M09 M10 M11 M12} {
    delete_bd_objs [get_bd_intf_nets -of_objects [get_bd_intf_pins ps7_axi_periph/${m}_AXI]]
}
foreach h {HDMI_0/mainG_shift_memdelay HDMI_1/gosc_shift HDMI_1/S_AXI_LITE_gainFeedback} {
    delete_bd_objs [get_bd_intf_nets -quiet -of_objects [get_bd_intf_pins $h]]
    delete_bd_objs [get_bd_intf_pins $h]
}
delete_bd_objs [get_bd_cells $g0] [get_bd_cells $gm] [get_bd_cells $go] [get_bd_cells $gf]

# ---- 3. the interconnect: 10 master ports, every port on FCLK0 + ARESETN -------------
set_property CONFIG.NUM_MI {10} [get_bd_cells ps7_axi_periph]
foreach {to p} $mv { connect_bd_intf_net [get_bd_intf_pins ps7_axi_periph/${to}_AXI] $p }
for {set i 0} {$i < 10} {incr i} {
    set m [format M%02d $i]
    if {[get_bd_nets -quiet -of_objects [get_bd_pins ps7_axi_periph/${m}_ACLK]] eq ""} {
        connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins ps7_axi_periph/${m}_ACLK]
    }
    if {[get_bd_nets -quiet -of_objects [get_bd_pins ps7_axi_periph/${m}_ARESETN]] eq ""} {
        connect_bd_net -net PS_ARESETN [get_bd_pins ps7_axi_periph/${m}_ARESETN]
    }
}

# ---- 4. dz_regs_0 and its connections -------------------------------------------------
create_bd_cell -type module -reference dz_regs dz_regs_0
connect_bd_intf_net [get_bd_intf_pins ps7_axi_periph/M00_AXI] [get_bd_intf_pins dz_regs_0/s_axi]
connect_bd_net -net PS_FCLK_CLK0 [get_bd_pins dz_regs_0/s_axi_aclk]
connect_bd_net -net PS_ARESETN [get_bd_pins dz_regs_0/s_axi_aresetn]
connect_bd_net {*}$d_in [get_bd_pins dz_regs_0/gpio_in]
connect_bd_net [get_bd_pins dz_regs_0/b0_ch2] {*}$s_b0
connect_bd_net [get_bd_pins dz_regs_0/irq] {*}$s_irq
# hierarchy pins for the buses that went into HDMI_0 / HDMI_1
foreach {hpin src snk} [list \
        HDMI_0/regs_main_ch1 b1_ch1 $s_m1  HDMI_0/regs_main_ch2 b1_ch2 $s_m2 \
        HDMI_1/regs_osc_ch1  b3_ch1 $s_o1  HDMI_1/regs_osc_ch2  b3_ch2 $s_o2 \
        HDMI_1/regs_fb_ch1   b6_ch1 $s_f1  HDMI_1/regs_fb_ch2   b6_ch2 $s_f2] {
    create_bd_pin -dir I -from 31 -to 0 $hpin
    connect_bd_net [get_bd_pins $hpin] {*}$snk
    connect_bd_net [get_bd_pins dz_regs_0/$src] [get_bd_pins $hpin]
}

# ---- 5. address, check, save -----------------------------------------------------------
assign_bd_address -offset 0x41200000 -range 512K \
    -target_address_space [get_bd_addr_spaces PS/processing_system7_0/Data] \
    [get_bd_addr_segs dz_regs_0/s_axi/reg0]
validate_bd_design
save_bd_design
puts "INFO: dz_regs edit done; now hw/export_bd.tcl"
close_project
