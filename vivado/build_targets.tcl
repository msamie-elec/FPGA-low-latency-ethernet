# SPDX-License-Identifier: MIT
# Build one or both FPGA bitstreams sequentially from ONE Vivado .xpr:
#   vivado -mode batch -source vivado/build_targets.tcl -tclargs both
# Also accepts A or B. Run generator first; never programs the boards.
set root [file normalize [file join [file dirname [info script]] ..]]
set project_name FPGA_Low_Latency_Ethernet
set xpr [file join $root build vivado_gui $project_name $project_name.xpr]
set choice [expr {[llength $argv] ? [string tolower [lindex $argv 0]] : "both"}]
if {$choice ni {a b both}} {error "Usage: -tclargs A|B|both"}
if {![file exists $xpr]} {error "Missing Vivado project: $xpr; run create_project.tcl first"}
open_project $xpr
source [file join $root vivado board_config.tcl]
if {$choice eq "both"} {set targets {A B}} else {set targets [list [string toupper $choice]]}
foreach target $targets {
    puts "BUILD START: Board $target"
    fpga_select_board $target
    # The single project reuses synth_1/impl_1. Reset before each exact build.
    reset_run impl_1
    reset_run synth_1
    launch_runs synth_1 -jobs 4
    wait_on_run synth_1
    if {![string match *Complete* [get_property STATUS [get_runs synth_1]]]} {
        error "Board $target synthesis failed; inspect the Vivado log"
    }
    launch_runs impl_1 -to_step write_bitstream -jobs 4
    wait_on_run impl_1
    if {![string match *Complete* [get_property STATUS [get_runs impl_1]]]} {
        error "Board $target implementation failed; inspect the Vivado log"
    }
    fpga_archive_current
    puts "BUILD COMPLETE: Board $target. Review CDC/timing/PHY I/O reports before programming."
}
close_project
puts "Separate outputs: [file join $root build vivado_outputs]"
