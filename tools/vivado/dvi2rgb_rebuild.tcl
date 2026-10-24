# dvi2rgb_rebuild.tcl - repackage the local IP_dvi2rgb fork after an RTL edit,
# upgrade it in the live project, and (optionally) rebuild the bitstream.
#
# Run from the repo root, Vivado 2022.2, batch mode:
#
#   phase 1 (repackage + upgrade, then stop and report):
#     vivado -mode batch -source tools/vivado/dvi2rgb_rebuild.tcl -tclargs upgrade
#   phase 2 (synth_2 -> impl_2 -> .bit + .bit.bin):
#     vivado -mode batch -source tools/vivado/dvi2rgb_rebuild.tcl -tclargs build
#
# Phase 1 changes only: IP_dvi2rgb/component.xml (checksums + coreRevision),
# and whatever Vivado itself writes when it upgrades ebaz4205_dvi2rgb_1_0
# (the .xci and the BD vlnv revision). Review `git diff --stat` before phase 2.

set repo  [file normalize [pwd]]
set ipdir $repo/IP_dvi2rgb
set xpr   $repo/Vivado/Vivado.xpr
set ipname ebaz4205_dvi2rgb_1_0
set phase [lindex $argv 0]

if {![file exists $xpr] || ![file exists $ipdir/component.xml]} {
    error "run from the repo root (missing $xpr or $ipdir/component.xml)"
}

if {$phase eq "upgrade"} {
    # --- repackage: new file checksums + bumped core revision -------------
    ipx::open_core $ipdir/component.xml
    set core [ipx::current_core]
    set rev  [get_property core_revision $core]
    set_property core_revision [expr {$rev + 1}] $core
    ipx::update_checksums $core
    ipx::save_core $core
    ipx::unload_core $core
    puts "INFO: dvi2rgb core_revision $rev -> [expr {$rev + 1}]"

    # --- upgrade in the project --------------------------------------------
    open_project $xpr
    update_ip_catalog -rebuild -repo_path $ipdir
    open_bd_design [get_files ebaz4205.bd]
    report_ip_status -file $repo/tools/vivado/ip_status_before.txt
    upgrade_ip [get_ips $ipname] -log $repo/tools/vivado/ip_upgrade.log
    save_bd_design
    report_ip_status -file $repo/tools/vivado/ip_status_after.txt
    close_project
    puts "INFO: done. Check tools/vivado/ip_status_after.txt: only $ipname"
    puts "INFO: should have changed; no other IP should show 'upgrade'."

} elseif {$phase eq "build"} {
    open_project $xpr
    reset_run synth_2
    launch_runs impl_2 -to_step write_bitstream -jobs 8
    wait_on_run impl_2
    if {[get_property PROGRESS [get_runs impl_2]] ne "100%"} {
        error "impl_2 did not finish - see Vivado/Vivado.runs/impl_2/runme.log"
    }
    set stamp [clock format [clock seconds] -format %Y%m%d]
    set bit   $repo/Vivado/Vivado.runs/impl_2/ebaz4205_wrapper.bit
    set out   $repo/debaz4205_wrapper_${stamp}_dvi2ms.bit
    file copy -force $bit $out
    # fpga_manager format: raw bin, no bit swap
    write_cfgmem -force -format bin -interface SMAPx32 -disablebitswap \
        -loadbit "up 0 $out" [file rootname $out].bit.bin
    open_run impl_2
    report_timing_summary -file $repo/tools/vivado/timing_${stamp}.rpt
    close_project
    puts "INFO: wrote $out and [file rootname $out].bit.bin"

} else {
    error "usage: -tclargs upgrade | build"
}
