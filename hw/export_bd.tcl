# export_bd.tcl - save a block design back to its Tcl source (hw/bd/<variant>.tcl).
#
#   vivado -mode batch -source hw/export_bd.tcl -tclargs <variant> [<project.xpr>]
#
#   <variant>      writes hw/bd/<variant>.tcl
#   <project.xpr>  project to read the BD from. Default:
#                  build/<variant>/<variant>.xpr  (the project hw/build.tcl made)
#
# THE RULE: hw/bd/<variant>.tcl is the source of truth. hw/build.tcl deletes
# and recreates build/<variant>/ on every run. After you edit a BD in the GUI,
# run this script (or, in the GUI Tcl console:
#   write_bd_tcl -force -include_layout <repo>/hw/bd/<variant>.tcl )
# then review `git diff hw/bd/` and commit.
#
# The source project is never opened directly: its .xpr + .srcs are copied to
# build/_export/ and the copy is opened read-write. (A -read_only open fails on
# the legacy BD - axi_dynclk_0 has an empty CLK_DOMAIN that Vivado must
# re-propagate - and a copy also avoids lock fights with an open GUI.)
# Save the BD in the GUI first: the export reads what is on disk.

set repo    [file normalize [file join [file dirname [info script]] ..]]
set variant [lindex $argv 0]
if {$variant eq ""} { error "usage: -tclargs <variant> \[<project.xpr>\]" }
set xpr [expr {[llength $argv] > 1 ? [lindex $argv 1] \
                                   : "$repo/build/$variant/$variant.xpr"}]
set xpr  [file normalize $xpr]
set name [file rootname [file tail $xpr]]
set srcs [file dirname $xpr]/$name.srcs
set out  $repo/hw/bd/$variant.tcl
set work $repo/build/_export

foreach f [list $xpr $srcs] {
    if {![file exists $f]} { error "missing $f" }
}

file delete -force $work
file mkdir $work $repo/hw/bd
file copy $xpr  $work/$name.xpr
file copy $srcs $work/$name.srcs

open_project $work/$name.xpr
# Relative IPRepoPath entries in the legacy .xpr ($PPRDIR/..) break in the copy.
set_property ip_repo_paths [list \
    $repo/ip_repo/if $repo/ip_repo/mixer_1_0 $repo/IP_axi_dynclk \
    $repo/IP_dvi2rgb $repo/IP_rgb2dvi] [current_project]
update_ip_catalog

set bds [get_files -quiet *.bd]
if {[llength $bds] != 1} { error "expected exactly one .bd in $xpr, found: $bds" }
open_bd_design $bds
report_ip_status -file $work/ip_status.txt
set stale [get_ips -quiet -filter {UPGRADE_VERSIONS != ""}]
if {[llength $stale]} {
    puts "WARNING: IP with available upgrades (not exported as upgraded): $stale"
}
# Validate the copy first: an unvalidated export gets BD::TCL 103-2053 on every
# rebuild, and a design that fails validation must not become the source.
if {[catch {validate_bd_design} msg]} { error "validate_bd_design failed: $msg" }
write_bd_tcl -force -include_layout $out
close_project
puts "INFO: wrote $out from $xpr"
puts "INFO: next: git diff hw/bd/$variant.tcl"
