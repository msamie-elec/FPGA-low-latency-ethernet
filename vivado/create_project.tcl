# SPDX-License-Identifier: MIT
# ONE editable Vivado GUI project containing both Arty A7-35T designs.
# vivado -mode batch -source vivado/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set project_name EthAB
set project_dir [file join $root build v $project_name]
set part xc7a35ticsg324-1L

# Only the FINAL frozen M4C generator + M4B buffered endpoint and their dependencies.
set rtl_files {
    uart_rx.sv uart_tx.sv
    mii_feed_tx.sv mii_reply_rx.sv ethernet_generator_a7_m4c.sv
    feed_parser.sv top_of_book.sv feed_pipeline.sv
    m4b_async_fifo.sv m4b_sync_fifo.sv
    mii_udp_rx_m4b.sv mii_udp_tx_m4b.sv ethernet_udp_a7_buffered.sv
}
set tb_file [file join $root tb tb_m4c_board_pair.sv]
set board_a_xdc [file join $root boards arty_a7 ethernet_m4c_generator.xdc]
set board_b_xdc [file join $root boards arty_a7 ethernet_m4b_endpoint.xdc]
# The original hardware-validated XDC files remain frozen/hashed.
# Create GUI-only copies with the two unsupported 'if' guards removed.
# These guards are checked in vivado/check_mii_ports.tcl after synthesis.
proc fpga_make_gui_xdc {original generated} {
    set fd [open $original r]
    set contents [read $fd]
    close $fd
    set rx_guard {if {[llength $mii_rx_ports] != 6} {error "Expected exactly six MII receive ports"}}
    set tx_guard {if {[llength $mii_tx_ports] != 5} {error "Expected five MII transmit ports"}}
    set kept {}
    set removed 0
    foreach line [split $contents "\n"] {
        if {$line eq $rx_guard || $line eq $tx_guard} {
            incr removed
            continue
        }
        lappend kept $line
    }
    if {$removed != 2} {
        error "Expected exactly two unsupported Tcl checks in frozen XDC: $original"
    }
    file mkdir [file dirname $generated]
    set fd [open $generated w]
    puts -nonewline $fd [join $kept "\n"]
    # Arty A7 Rev E: Digilent schematic sheets 6-7 show CFGBVS_0
    # tied high to VCC3V3 and configuration Bank 0 VCCO_0 at 3.3V.
    # Keep historically frozen XDC untouched. These properties only
    # describe the real board's configuration bank for Vivado DRC.
    puts $fd "\n# Arty A7 configuration bank 0 (Digilent schematic)"
    puts $fd "set_property CFGBVS VCCO \[current_design\]"
    puts $fd "set_property CONFIG_VOLTAGE 3.3 \[current_design\]"
    close $fd
}
set xdc_dir [file join $root build v xdc]
set gui_a_xdc [file join $xdc_dir A.xdc]
set gui_b_xdc [file join $xdc_dir B.xdc]
foreach name $rtl_files {
    set path [file join $root rtl $name]
    if {![file isfile $path]} {error "Missing RTL source: $path"}
}
foreach path [list $tb_file $board_a_xdc $board_b_xdc] {
    if {![file isfile $path]} {error "Missing required file: $path"}
}
set project_ready [file join $root build v project_ok.txt]
file mkdir [file dirname $project_dir]
file delete -force $project_ready
fpga_make_gui_xdc $board_a_xdc $gui_a_xdc
fpga_make_gui_xdc $board_b_xdc $gui_b_xdc
create_project -force $project_name $project_dir -part $part
set_property target_language Verilog [current_project]
foreach name $rtl_files {
    add_files -norecurse -fileset sources_1 [file join $root rtl $name]
}
# Two mutually exclusive XDC sets; NEVER apply both at the same time.
create_fileset -constrset constrs_board_a
create_fileset -constrset constrs_board_b
add_files -norecurse -fileset constrs_board_a $gui_a_xdc
add_files -norecurse -fileset constrs_board_b $gui_b_xdc
# Both FPGA designs are instantiated by the simulation testbench only.
set_property source_set sources_1 [get_filesets sim_1]
add_files -norecurse -fileset sim_1 $tb_file
set_property top tb_m4c_board_pair [get_filesets sim_1]
set_property top ethernet_generator_a7_m4c [get_filesets sources_1]
source [file join $root vivado board_config.tcl]
fpga_select_board A
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
close_project
# Reopen the exact generated XPR and verify BOTH synthesis/simulation configuration.
set final_xpr [file join $project_dir $project_name.xpr]
if {![file isfile $final_xpr]} {error "Generated XPR missing: $final_xpr"}
open_project $final_xpr
if {[get_property TOP [get_filesets sources_1]] ne "ethernet_generator_a7_m4c"} {
    error "Wrong persisted synthesis top in $final_xpr"
}
if {[get_property TOP [get_filesets sim_1]] ne "tb_m4c_board_pair"} {
    error "Wrong persisted simulation top in $final_xpr"
}
if {[get_property CONSTRSET [get_runs synth_1]] ne "constrs_board_a"} {
    error "Wrong persisted synthesis constraints in $final_xpr"
}
if {[get_property CONSTRSET [get_runs impl_1]] ne "constrs_board_a"} {
    error "Wrong persisted implementation constraints in $final_xpr"
}
# Confirm BOTH persisted constraint sets contain an actual effective XDC.
# A selected but empty set can otherwise route an entirely unconstrained FPGA.
source [file join $root vivado board_config.tcl]
fpga_ensure_board_xdc A constrs_board_a
fpga_ensure_board_xdc B constrs_board_b
close_project
set fh [open $project_ready w]
puts $fh "Project creation and reopen verification passed: $final_xpr"
close $fh
puts "SUCCESS: Created and reopened ONE Vivado project: $final_xpr"
puts "GUI Tcl Console (from repo root): source vivado/board_config.tcl; fpga_select_board A or B"
puts "The physical experiment still needs TWO Arty A7-35T FPGAs, each with its own bitstream."
