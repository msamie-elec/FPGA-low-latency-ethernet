# Arty A7-35 / A7-100 (verify actual board PCB revision)
# Digilent master XDC: https://github.com/Digilent/digilent-xdc
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name clk_100mhz -period 10.000 [get_ports clk]
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]

# FPGA-side TX/RX direction: board net "uart_txd_in" carries PC TX -> FPGA RX;
# board net "uart_rxd_out" carries FPGA TX -> PC RX.
# A7 confirmed with v0.4 five-byte echo on physical Arty A7-35T.
set_property -dict { PACKAGE_PIN A9 IOSTANDARD LVCMOS33 } [get_ports uart_rx_i]
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]
