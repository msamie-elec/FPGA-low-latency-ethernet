## Arty S7-25 / S7-50 smoke test, using 12 MHz system clock (NOT DDR 100 MHz clock).
## Check actual PCB revision against Digilent master XDC before programming.
## Source: https://github.com/Digilent/digilent-xdc
set_property -dict { PACKAGE_PIN F14 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name clk_12mhz -period 83.333 [get_ports clk]
set_property -dict { PACKAGE_PIN G15 IOSTANDARD LVCMOS33 } [get_ports {btn[0]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN F13 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN E13 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
