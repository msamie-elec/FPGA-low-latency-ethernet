# SPDX-License-Identifier: MIT
# Invocation: vivado -mode batch -source scripts/build_vivado.tcl -tclargs a7-35
# Legal board values: a7-35, a7-100, s7-25, s7-50.
if {$argc != 1} { error "Specify one of a7-35 a7-100 s7-25 s7-50" }
set board [lindex $argv 0]
set boards [dict create \
    a7-35  {xc7a35ticsg324-1L board_uart_a7 arty_a7} \
    a7-100 {xc7a100tcsg324-1 board_uart_a7 arty_a7} \
    s7-25  {xc7s25csga324-1 board_uart_s7 arty_s7} \
    s7-50  {xc7s50csga324-1 board_uart_s7 arty_s7}]
if {![dict exists $boards $board]} { error "Unknown board $board" }
lassign [dict get $boards $board] part top folder
set root [file normalize [file join [file dirname [info script]] ..]]
set output [file join $root build vivado_$board]
file mkdir [file dirname $output]
create_project -force fpga_feed_$board $output -part $part
set_property target_language Verilog [current_project]
foreach f {feed_parser.sv top_of_book.sv feed_pipeline.sv uart_rx.sv uart_tx.sv board_uart_demo.sv} {
    add_files [file join $root rtl $f]
}
add_files -fileset constrs_1 [file join $root boards $folder uart.xdc]
set_property top $top [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match *Complete* [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis unsuccessful; inspect run logs"
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match *Complete* [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation/bitstream unsuccessful; inspect run logs"
}
open_run impl_1
set reports [file join $root build reports $board]
file mkdir $reports
report_utilization -file [file join $reports utilization.rpt]
report_timing_summary -file [file join $reports timing_summary.rpt]
report_power -file [file join $reports power_estimate.rpt]
close_design
puts "Vivado reports: $reports"
puts "Bitstream: $output/fpga_feed_$board.runs/impl_1/${top}.bit"
