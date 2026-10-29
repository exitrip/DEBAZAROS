# build.tcl - recreate a DEBAZAROS Vivado project from Tcl and build it.
#
#   vivado -mode batch -source hw/build.tcl -tclargs <variant> <phase> [<dir>]
#
#   variant  name of hw/bd/<variant>.tcl (e.g. ebaz4205_2out1in)
#   phase    project  create project + generate BD output products, then stop
#            build    project + synth + impl + .bit/.bit.bin/.xsa + hw_map.h
#   dir      output folder name under build/ (default <variant>). Use another
#            name while the GUI has build/<variant>/ open: the run deletes it.
#
# Output goes to build/<dir>/ (git-ignored). All inputs are in hw/ and the
# root IP repos; nothing is read from the legacy Vivado/ project.
# Vivado 2022.2 only (write_bd_tcl scripts are version-locked).

set repo    [file normalize [file join [file dirname [info script]] ..]]
set variant [lindex $argv 0]
set phase   [lindex $argv 1]
set part    xc7z010clg400-1
set out     $repo/build/[expr {[llength $argv] > 2 ? [lindex $argv 2] : $variant}]
set bdtcl   $repo/hw/bd/$variant.tcl

if {$variant eq "" || [lsearch {project build} $phase] < 0} {
    error "usage: -tclargs <variant> project|build"
}
if {![file exists $bdtcl]} { error "missing $bdtcl (run hw/export_bd.tcl)" }

# --- sources shared by all variants ------------------------------------------
# Custom IP repos.
set ip_repos [list \
    $repo/ip_repo/if \
    $repo/ip_repo/mixer_1_0 \
    $repo/IP_axi_dynclk \
    $repo/IP_dvi2rgb \
    $repo/IP_rgb2dvi]
# RTL used by BD module references (DivideBy2N, div16_8_recip,
# dds_axi_interface, hdmi_tx + hdmi_audio_regs + hdmi_rx, pl_io, fsync_gen,
# dz_regs, dz_osc2). The two dds_axi_interface files are only for projects
# of BD sources from before dz_osc2 (2026-10-29).
set rtl_dir $repo/hw/rtl
set rtl [list \
    $rtl_dir/DivideBy2N.v \
    $rtl_dir/div16_8_recip.v \
    $rtl_dir/dds_axi_interface_logic.vhd \
    $rtl_dir/dds_axi_inteface.vhd \
    $rtl_dir/hdmi_tx/hdmi_tx.v \
    $rtl_dir/hdmi_tx/hdmi_tx_encoder.v \
    $rtl_dir/hdmi_tx/hdmi_tx_packets.v \
    $rtl_dir/hdmi_tx/hdmi_tx_rom.v \
    $rtl_dir/hdmi_tx/hdmi_tx_serdes.v \
    $rtl_dir/hdmi_tx/hdmi_audio_regs.v \
    $rtl_dir/hdmi_tx/hdmi_rx.v \
    $rtl_dir/pl_io/pl_io.v \
    $rtl_dir/pl_io/pl_io_core.v \
    $rtl_dir/pl_io/dz_i2s.v \
    $rtl_dir/pl_io/dz_async_fifo.v \
    $rtl_dir/pl_io/dz_bram_fifo.v \
    $rtl_dir/fsync_gen.v \
    $rtl_dir/dz_regs/dz_regs.v \
    $rtl_dir/dz_osc/dz_osc2.v \
    $rtl_dir/dz_osc/dz_osc_ch.v \
    $rtl_dir/dz_osc/dz_sine_rom.v]
set xdc [list $repo/hw/xdc/ebaz4205.xdc]

# --- project -------------------------------------------------------------------
create_project -force $variant $out -part $part
set_property target_language Verilog [current_project]
set_property ip_repo_paths $ip_repos [current_project]
update_ip_catalog
add_files -norecurse $rtl
add_files -fileset constrs_1 -norecurse $xdc
update_compile_order -fileset sources_1

source $bdtcl
set bd [get_files [current_bd_design].bd]
validate_bd_design
save_bd_design
set wrapper [make_wrapper -files $bd -top]
add_files -norecurse $wrapper
set_property top [file rootname [file tail $wrapper]] [current_fileset]
update_compile_order -fileset sources_1
# DZ_SYNTH_MODE=global: synthesize the whole BD in synth_1 (no out-of-context
# run per IP), so DZ_SYNTH_DIRECTIVE reaches every IP and optimisation can
# cross IP boundaries. Default: out of context per IP (Vivado's default).
if {[info exists ::env(DZ_SYNTH_MODE)] && $::env(DZ_SYNTH_MODE) eq "global"} {
    set_property synth_checkpoint_mode None $bd
    puts "INFO: BD synthesis global (one run)"
}
generate_target all $bd
# the out-of-context run of each IP exists only from here (else launch_runs
# makes them later, and DZ_SYNTH_* would reach synth_1 only)
if {[get_property synth_checkpoint_mode $bd] ne "None"} {
    create_ip_run $bd
}

# --- hw_map.h: PS-visible address map, one source of truth for C/scripts --------
source $repo/hw/hw_map.tcl
write_hw_map $out/hw_map.h $variant

if {$phase eq "project"} {
    close_project
    puts "INFO: project ready in $out (phase=project, no synthesis)"
    return
}

# --- build ---------------------------------------------------------------------
# The fabric is ~95 % full and FCLK2 (VDMA memory side, 145 MHz) has almost no
# slack inside the capture VDMA's S2MM datamover (build pwm 2026-10-27: -0.39
# ns with the default flow). Post-route phys_opt fixes such paths in place.
set_property STEPS.PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.IS_ENABLED true [get_runs impl_1]
set_property STEPS.POST_ROUTE_PHYS_OPT_DESIGN.ARGS.DIRECTIVE AggressiveExplore [get_runs impl_1]
# Directives (2026-10-29, dz_osc2 at 100 % slices). Defaults = the best of
# a comparison on build osc (routing AggressiveExplore in all; FCLK0 / FCLK2
# / FCLK3): ExtraPostPlacementOpt +0.191 / +0.268 / +0.619; Explore +0.431 /
# +0.006; default -0.017 (FCLK2); ExtraTimingOpt -0.333; AltSpreadLogic_high
# -0.426. The environment overrides them for a new comparison after a design
# change ("" = Vivado's default): DZ_PLACE_DIRECTIVE, DZ_ROUTE_DIRECTIVE,
# DZ_SYNTH_DIRECTIVE (e.g. AreaOptimized_high, PerformanceOptimized;
# default: Vivado's), DZ_SYNTH_FLATTEN (rebuilt / full / none).
# Synthesis comparison (same design, these impl defaults; LUT / slices /
# FCLK0 / FCLK2): default 13760 / 4400 / +0.191 / +0.268; AreaOptimized_high
# 12824 / 4390 / +0.028 / +0.008; global 13656 / 4392 / +0.344 / -0.073;
# global + AreaOptimized_high 12687 / 4386 / +0.001 / +0.008. Area synthesis
# saves ~7 % LUT but no slices (packing limits them) and eats the margins:
# kept off. Global mode needs a rename first: dvi2rgb and axi_dynclk both
# define an entity SyncAsync (different content; one library = a black box).
set directives [list \
    DZ_SYNTH_DIRECTIVE synth_1 SYNTH_DESIGN.ARGS.DIRECTIVE         "" \
    DZ_SYNTH_FLATTEN   synth_1 SYNTH_DESIGN.ARGS.FLATTEN_HIERARCHY "" \
    DZ_PLACE_DIRECTIVE impl_1  PLACE_DESIGN.ARGS.DIRECTIVE         ExtraPostPlacementOpt \
    DZ_ROUTE_DIRECTIVE impl_1  ROUTE_DESIGN.ARGS.DIRECTIVE         AggressiveExplore]
foreach {var run step def} $directives {
    set v $def
    if {[info exists ::env($var)]} { set v $::env($var) }
    if {$v eq ""} continue
    # synthesis settings go to every synthesis run (the per-IP runs too)
    set runs [expr {$run eq "synth_1" ? [get_runs -filter {IS_SYNTHESIS}] : [get_runs $run]}]
    foreach r $runs { set_property STEPS.$step $v $r }
    puts "INFO: $step = $v ([llength $runs] run(s))"
}
launch_runs impl_1 -to_step write_bitstream -jobs 8
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {
    error "impl_1 failed - see $out/$variant.runs/impl_1/runme.log"
}
set stamp [clock format [clock seconds] -format %Y%m%d]
set base  $out/${variant}_$stamp
file copy -force [glob $out/$variant.runs/impl_1/*.bit] $base.bit
# fpga_manager format: raw bin, no bit swap (absolute paths: Vivado cwd varies)
write_cfgmem -force -format bin -interface SMAPx32 -disablebitswap \
    -loadbit "up 0 $base.bit" $base.bit.bin
open_run impl_1
write_hw_platform -fixed -include_bit -force $base.xsa
report_timing_summary -file $base.timing.rpt
report_utilization    -file $base.util.rpt
close_project
puts "INFO: wrote $base.{bit,bit.bin,xsa}"
