# SPDX-License-Identifier: MIT
# Create two separate, editable Vivado GUI projects from the released RTL.
# vivado -mode batch -source vivado/create_gui_projects.tcl -tclargs both
# Accepts: both (default), board_a, board_b. Does not run synthesis.
set root [file normalize [file join [file dirname [info script]] ..]]
set requested [expr {[llength $argv] > 0 ? [lindex $argv 0] : "both"}]
if {$requested ni {both board_a board_b}} {
    error "Usage: -tclargs both|board_a|board_b"
}
set part xc7a35ticsg324-1L
set board_a_rtl {uart_rx.sv uart_tx.sv mii_feed_tx.sv mii_reply_rx.sv ethernet_generator_a7_m4c.sv}
set board_b_rtl {feed_parser.sv top_of_book.sv feed_pipeline.sv uart_tx.sv m4b_async_fifo.sv m4b_sync_fifo.sv mii_udp_rx_m4b.sv mii_udp_tx_m4b.sv ethernet_udp_a7_buffered.sv}
# The other board's RTL is SIMULATION ONLY; never part of synthesis.
set board_a_sim_extra {feed_parser.sv top_of_book.sv feed_pipeline.sv m4b_async_fifo.sv m4b_sync_fifo.sv mii_udp_rx_m4b.sv mii_udp_tx_m4b.sv ethernet_udp_a7_buffered.sv}
set board_b_sim_extra {uart_rx.sv mii_feed_tx.sv mii_reply_rx.sv ethernet_generator_a7_m4c.sv}

proc existing_rtl {root names} {
    set paths {}
    foreach name $names {
        set path [file join $root rtl $name]
        if {![file isfile $path]} {error "Missing RTL file: $path"}
        lappend paths $path
    }
    return $paths
}

proc create_board {root part id} {
    global board_a_rtl board_b_rtl board_a_sim_extra board_b_sim_extra
    if {$id eq "board_a"} {
        set project_name board_a_generator
        set top ethernet_generator_a7_m4c
        set rtl $board_a_rtl
        set sim_extra $board_a_sim_extra
        set xdc ethernet_m4c_generator.xdc
    } else {
        set project_name board_b_endpoint
        set top ethernet_udp_a7_buffered
        set rtl $board_b_rtl
        set sim_extra $board_b_sim_extra
        set xdc ethernet_m4b_endpoint.xdc
    }
    set xdc_path [file join $root boards arty_a7 $xdc]
    set tb_path [file join $root tb tb_m4c_board_pair.sv]
    if {![file isfile $xdc_path]} {error "Missing XDC: $xdc_path"}
    if {![file isfile $tb_path]} {error "Missing testbench: $tb_path"}
    set design_paths [existing_rtl $root $rtl]
    set sim_paths [existing_rtl $root $sim_extra]
    set output [file join $root build vivado_gui $project_name]
    file mkdir [file dirname $output]
    puts "Creating $project_name with synthesis top $top"
    create_project -force $project_name $output -part $part
    set_property target_language Verilog [current_project]
    foreach path $design_paths {add_files -norecurse -fileset sources_1 $path}
    add_files -norecurse -fileset constrs_1 $xdc_path
    set_property top $top [get_filesets sources_1]
    update_compile_order -fileset sources_1
    foreach path $sim_paths {add_files -norecurse -fileset sim_1 $path}
    add_files -norecurse -fileset sim_1 $tb_path
    set_property top tb_m4c_board_pair [get_filesets sim_1]
    update_compile_order -fileset sim_1
    puts "Created [file join $output $project_name.xpr]"
    close_project
}
if {$requested in {both board_a}} {create_board $root $part board_a}
if {$requested in {both board_b}} {create_board $root $part board_b}
puts "Done. Open the generated XPR files in Vivado GUI. No bitstream has been built."