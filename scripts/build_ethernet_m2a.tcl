# SPDX-License-Identifier: MIT
# Run from v0.4 project root: vivado -mode batch -source scripts/build_ethernet_m2a.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set output [file join $root build vivado_ethernet_m2a]
file mkdir [file dirname $output]
create_project -force ethernet_m2a $output -part xc7a35ticsg324-1L
set_property target_language Verilog [current_project]
foreach f {feed_parser.sv top_of_book.sv feed_pipeline.sv uart_tx.sv mii_udp_rx.sv ethernet_uart_a7.sv} {
    add_files [file join $root rtl $f]
}
add_files -fileset constrs_1 [file join $root boards arty_a7 ethernet_m2a.xdc]
set_property top ethernet_uart_a7 [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match *Complete* [get_property STATUS [get_runs synth_1]]]} {
    error "Synthesis unsuccessful; inspect logs"
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match *Complete* [get_property STATUS [get_runs impl_1]]]} {
    error "Implementation unsuccessful; inspect logs"
}
open_run impl_1
set reports [file join $root build reports ethernet_m2a]
file mkdir $reports
report_utilization -file [file join $reports utilization.rpt]
report_timing_summary -file [file join $reports timing_summary.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_cdc -details -all_checks_per_endpoint -file [file join $reports cdc.rpt]
report_clock_interaction -file [file join $reports clock_interaction.rpt]
check_timing -verbose -file [file join $reports check_timing.rpt]
report_power -file [file join $reports power_estimate.rpt]
# Verify the PHY clock is attached to the physical output port.
set refclks [get_clocks -quiet -of_objects [get_ports eth_ref_clk]]
puts "PHY reference clocks at eth_ref_clk: $refclks"
if {[llength $refclks] == 0} {
    error "No derived clock reaches eth_ref_clk: review create_generated_clock/clock output routing"
}
close_design
puts "M2A reports: $reports"
puts "M2A bitstream: $output/ethernet_m2a.runs/impl_1/ethernet_uart_a7.bit"
