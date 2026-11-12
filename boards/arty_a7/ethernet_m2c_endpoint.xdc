# Arty A7-35T Rev D/E: 100 MHz onboard and Ethernet DP83848J MII
# Master pin reference: Digilent Arty A7 master XDC.
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports clk]
create_clock -name sys_100mhz -period 10.000 [get_ports clk]
set_property -dict { PACKAGE_PIN D9 IOSTANDARD LVCMOS33 } [get_ports btn0]
set_property -dict { PACKAGE_PIN H5 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN J5 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports {led[2]}]
set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {led[3]}]
# FPGA UART TX to host, confirmed by physical v0.3 UART test
set_property -dict { PACKAGE_PIN D10 IOSTANDARD LVCMOS33 } [get_ports uart_tx_o]
# PHY REF_CLK is an FPGA output; DP83848J receives a 25MHz reference clock.
set_property -dict { PACKAGE_PIN G18 IOSTANDARD LVCMOS33 } [get_ports eth_ref_clk]
set_property -dict { PACKAGE_PIN C16 IOSTANDARD LVCMOS33 } [get_ports eth_rstn]
set_property -dict { PACKAGE_PIN F15 IOSTANDARD LVCMOS33 } [get_ports eth_rx_clk]
set_property -dict { PACKAGE_PIN G16 IOSTANDARD LVCMOS33 } [get_ports eth_rx_dv]
set_property -dict { PACKAGE_PIN C17 IOSTANDARD LVCMOS33 } [get_ports eth_rxerr]
set_property -dict { PACKAGE_PIN D18 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[0]}]
set_property -dict { PACKAGE_PIN E17 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[1]}]
set_property -dict { PACKAGE_PIN E18 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[2]}]
set_property -dict { PACKAGE_PIN G17 IOSTANDARD LVCMOS33 } [get_ports {eth_rxd[3]}]
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports eth_tx_clk]
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports eth_tx_en]
set_property -dict { PACKAGE_PIN H14 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[0]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[1]}]
set_property -dict { PACKAGE_PIN J13 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[2]}]
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {eth_txd[3]}]
create_clock -name eth_rx_25mhz -period 40.000 [get_ports eth_rx_clk]
create_clock -name eth_tx_25mhz -period 40.000 [get_ports eth_tx_clk]
# Clock relationships will be declared after the generated PHY REFCLK.
# Generated REFCLK is driven by a /4 register divider, not a timing input.
# Future: sign off PHY ref-clock waveform and MII input setup/hold using board data.

# v0.4B exploratory timing constraints; REQUIRES post-route sign-off.
# DP83848J 100 Mb/s MII receive: RX_CLK->RXD/RX_DV/RX_ER Tco 10..30 ns.
# These bounds exclude PCB data/clock trace skew and other board uncertainty;
# therefore they are a first analysis pass, NOT final board-level values.
set mii_rx_ports [get_ports {eth_rx_dv eth_rxerr eth_rxd[0] eth_rxd[1] eth_rxd[2] eth_rxd[3]}]
if {[llength $mii_rx_ports] != 6} {error "Expected exactly six MII receive ports"}
set_input_delay -clock [get_clocks eth_rx_25mhz] -min 10.000 $mii_rx_ports
set_input_delay -clock [get_clocks eth_rx_25mhz] -max 30.000 $mii_rx_ports

# The REF_CLK output is a clock derived from the 100 MHz input by a /4
# register divider. Declare it at its source flop; timing analysis must verify
# that the clock propagates through the output buffer to eth_ref_clk.
# This models frequency/phase, but NOT a guarantee of PHY X1 clock quality.
create_generated_clock -name phy_ref_25mhz \
    -source [get_ports clk] -divide_by 4 [get_pins {div4_reg[1]/Q}]

# MII TX output is registered on the falling edge of PHY TX_CLK;
# PHY samples data on the next rising edge. Provisional 100Mbps timing:
# TXD/TX_EN setup >=10 ns, hold >=0 ns at the PHY. These values omit
# PCB skew and IO/timing uncertainty, so require post-route validation.
set mii_tx_ports [get_ports {eth_tx_en eth_txd[0] eth_txd[1] eth_txd[2] eth_txd[3]}]
if {[llength $mii_tx_ports] != 5} {error "Expected five MII transmit ports"}
set_output_delay -clock [get_clocks eth_tx_25mhz] -max 10.000 $mii_tx_ports
set_output_delay -clock [get_clocks eth_tx_25mhz] -min 0.000 $mii_tx_ports
# Place the falling-edge MII output registers in the Artix-7 I/O logic
# rather than routing them from fabric FFs. This is an implementation fix
# for the previously measured -0.873ns TX setup slack, not a relaxation
# of the DP83848J 10ns setup / 0ns hold specifications.
# Vivado must verify IOB packing and positive routed TX setup/hold slack.
set_property IOB TRUE $mii_tx_ports

# Independent RX/TX PHY clocks and system clock. This explicitly groups
# generated 25MHz PHY REFCLK with its parent 100MHz oscillator domain.
set_clock_groups -asynchronous \
    -group [get_clocks {sys_100mhz phy_ref_25mhz}] \
    -group [get_clocks eth_rx_25mhz] \
    -group [get_clocks eth_tx_25mhz]
