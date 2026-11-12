# M4B buffered endpoint engineering candidate. Not approved without post-route
# CDC/timing review and hardware tests. Vivado 2025.2.1.
set root [file normalize [file join [file dirname [info script]] ..]]
set output [file join $root build vivado_ethernet_m4b_endpoint]
file mkdir [file dirname $output]
create_project -force ethernet_m4b_endpoint $output -part xc7a35ticsg324-1L
set_property target_language Verilog [current_project]
foreach f {feed_parser.sv top_of_book.sv feed_pipeline.sv uart_tx.sv
           m4b_async_fifo.sv m4b_sync_fifo.sv mii_udp_rx_m4b.sv
           mii_udp_tx_m4b.sv ethernet_udp_a7_buffered.sv} {
    add_files [file join $root rtl $f]
}
add_files -fileset constrs_1 [file join $root boards arty_a7 ethernet_m4b_endpoint.xdc]
set_property top ethernet_udp_a7_buffered [get_filesets sources_1]
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match *Complete* [get_property STATUS [get_runs synth_1]]]} {
    error "M4B synthesis unsuccessful"
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match *Complete* [get_property STATUS [get_runs impl_1]]]} {
    error "M4B implementation unsuccessful"
}
open_run impl_1
set reports [file join $root build reports ethernet_m4b_endpoint]
file mkdir $reports
report_utilization -file [file join $reports utilization.rpt]
report_timing_summary -file [file join $reports timing_summary.rpt]
report_methodology -file [file join $reports methodology.rpt]
report_cdc -details -all_checks_per_endpoint -file [file join $reports cdc.rpt]
report_clock_interaction -file [file join $reports clock_interaction.rpt]
check_timing -verbose -file [file join $reports check_timing.rpt]
set txouts [get_ports {eth_tx_en eth_txd[0] eth_txd[1] eth_txd[2] eth_txd[3]}]
report_timing -delay_type max -max_paths 10 -to $txouts -file [file join $reports tx_setup.rpt]
report_timing -delay_type min -max_paths 10 -to $txouts -file [file join $reports tx_hold.rpt]
report_power -file [file join $reports power_estimate.rpt]
set refclks [get_clocks -quiet -of_objects [get_ports eth_ref_clk]]
if {[llength $refclks] == 0} {
    error "M4B: missing generated PHY reference clock"
}
set wsp [get_timing_paths -setup -max_paths 1]
set whp [get_timing_paths -hold -max_paths 1]
if {[llength $wsp] == 0 || [llength $whp] == 0} {
    error "M4B: no setup/hold timing paths"
}
set ws [get_property SLACK $wsp]
set wh [get_property SLACK $whp]
set fd [open [file join $reports cdc.rpt] r]
set cdctxt [read $fd]
close $fd
if {![regexp {CDC Report} $cdctxt]} {error "M4B: unexpected CDC report format"}
set cdc1 0
regexp {CDC-1[ \t]+Critical[ \t]+([0-9]+)} $cdctxt -> cdc1
puts "M4B gate: WNS=$ws ns, WHS=$wh ns, CDC-1=$cdc1"
if {$ws < 0 || $wh < 0 || $cdc1 > 0} {
    error "M4B NOT APPROVED: WNS=$ws, WHS=$wh, CDC-1=$cdc1. Investigate FIFO CDC paths."
}
close_design
puts "M4B reports: $reports"
puts "M4B candidate bitstream: $output/ethernet_m4b_endpoint.runs/impl_1/ethernet_udp_a7_buffered.bit"
puts "NOTICE: physical programming still requires report inspection and human approval."
