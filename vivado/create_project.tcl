# SPDX-License-Identifier: MIT
# ONE editable Vivado GUI project containing both Arty A7-35T designs.
# vivado -mode batch -source vivado/create_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set project_name FPGA_Low_Latency_Ethernet
set project_dir [file join $root build vivado_gui $project_name]
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
foreach name $rtl_files {
    set path [file join $root rtl $name]
    if {![file isfile $path]} {error "Missing RTL source: $path"}
}
foreach path [list $tb_file $board_a_xdc $board_b_xdc] {
    if {![file isfile $path]} {error "Missing required file: $path"}
}
file mkdir [file dirname $project_dir]
create_project -force $project_name $project_dir -part $part
set_property target_language Verilog [current_project]
foreach name $rtl_files {
    add_files -norecurse -fileset sources_1 [file join $root rtl $name]
}
# Two mutually exclusive XDC sets; NEVER apply both at the same time.
create_fileset -constrset constrs_board_a
create_fileset -constrset constrs_board_b
add_files -norecurse -fileset constrs_board_a $board_a_xdc
add_files -norecurse -fileset constrs_board_b $board_b_xdc
# Both FPGA designs are instantiated by the simulation testbench only.
set_property source_set sources_1 [get_filesets sim_1]
add_files -norecurse -fileset sim_1 $tb_file
set_property top tb_m4c_board_pair [get_filesets sim_1]
set_property top ethernet_generator_a7_m4c [get_filesets sources_1]
source [file join $root vivado board_config.tcl]
fpga_select_board A
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
save_project
close_project
puts "Created ONE Vivado project: [file join $project_dir $project_name.xpr]"
puts "GUI Tcl Console (from repo root): source vivado/board_config.tcl; fpga_select_board A or B"
puts "The physical experiment still needs TWO Arty A7-35T FPGAs, each with its own bitstream."
