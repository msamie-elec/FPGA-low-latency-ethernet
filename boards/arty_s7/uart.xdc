# Arty S7-25 / S7-50 (verify actual board PCB revision)
# Uses 12 MHz user clock, NOT 100 MHz DDR clock.
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name clk_12mhz -period 83.333 [get_ports clk]
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

# FPGA-side TX/RX direction: board net "uart_txd_in" carries PC TX -> FPGA RX;
# board net "uart_rxd_out" carries FPGA TX -> PC RX.
# S7 pin selection follows Digilent S7 schematic net names; NOT yet hardware-tested.
set_property -dict { PACKAGE_PIN V12 IOSTANDARD LVCMOS33 } [get_ports uart_rx_i]
set_property -dict { PACKAGE_PIN R12 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]
