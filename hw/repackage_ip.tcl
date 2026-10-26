# repackage_ip.tcl - repackage a local IP after an RTL edit (replaces the old
# tools/vivado/dvi2rgb_rebuild.tcl, which needed the legacy Vivado/ project).
#
#   vivado -mode batch -source hw/repackage_ip.tcl -tclargs <ipdir> [ports <top>]
#
#   <ipdir>  an IP repo folder with component.xml, relative to the repo root:
#            IP_dvi2rgb, IP_rgb2dvi, IP_axi_dynclk, ip_repo/mixer_1_0
#   ports <top>  the RTL edit added, removed or resized ports of module <top>
#            (e.g. ports mixer_v1_0): read <ipdir>/hdl/*.v and merge the port
#            list into component.xml (file groups stay as they are)
#
# It changes only <ipdir>/component.xml: new file checksums and core_revision
# + 1 (and the port list with "ports"). Then rebuild:  vivado -mode batch -source hw/build.tcl -tclargs <variant> build
# The BD Tcl names each IP by VLNV only (no revision), so a fresh build uses
# the new revision; no upgrade_ip step is necessary.
# Review `git diff <ipdir>` before the build: only your RTL edit and the
# component.xml checksums/revision should change.

set repo  [file normalize [file join [file dirname [info script]] ..]]
set ipdir [lindex $argv 0]
if {$ipdir eq ""} { error "usage: -tclargs <ipdir>  (e.g. IP_dvi2rgb)" }
set ipdir [file normalize [file join $repo $ipdir]]
if {![file exists $ipdir/component.xml]} { error "missing $ipdir/component.xml" }
set top ""
if {[lindex $argv 1] eq "ports"} { set top [lindex $argv 2] }

if {$top ne ""} {
  # merge_project_changes reads the ports from the current project's top
  create_project -in_memory -part xc7z010clg400-1
  add_files [glob $ipdir/hdl/*.v]
  set_property top $top [current_fileset]
  update_compile_order -fileset sources_1
}
ipx::open_core $ipdir/component.xml
set core [ipx::current_core]
if {$top ne ""} {
  set n [llength [ipx::get_ports -of_objects $core]]
  ipx::merge_project_changes ports $core
  puts "INFO: ports $n -> [llength [ipx::get_ports -of_objects $core]]"
}
set rev  [get_property core_revision $core]
set_property core_revision [expr {$rev + 1}] $core
ipx::update_checksums $core
ipx::check_integrity $core
ipx::save_core $core
puts "INFO: [get_property vlnv $core] core_revision $rev -> [expr {$rev + 1}]"
ipx::unload_core $core
puts "INFO: next: git diff [file tail $ipdir]; then hw/build.tcl <variant> build"
