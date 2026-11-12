#!/usr/bin/env python3
"""Static cross-check for v0.4A hardware connections and source list."""
from pathlib import Path
import re
ROOT=Path(__file__).resolve().parents[1]
xdc=(ROOT/'boards/arty_a7/ethernet_m2a.xdc').read_text()
pins={'clk':'E3','btn0':'D9','uart_tx_o':'D10','eth_ref_clk':'G18',
      'eth_rstn':'C16','eth_rx_clk':'F15','eth_rx_dv':'G16','eth_rxerr':'C17',
      'eth_rxd[0]':'D18','eth_rxd[1]':'E17','eth_rxd[2]':'E18','eth_rxd[3]':'G17',
      'eth_tx_en':'H15','eth_txd[0]':'H14','eth_txd[1]':'J14',
      'eth_txd[2]':'J13','eth_txd[3]':'H17',
      'led[0]':'H5','led[1]':'J5','led[2]':'T9','led[3]':'T10'}
for signal,pin in pins.items():
    regex=rf'PACKAGE_PIN\s+{pin}\s+IOSTANDARD\s+LVCMOS33\s+\}}\s+\[get_ports\s+\{{?{re.escape(signal)}\}}?\]'
    assert re.search(regex,xdc), f'{signal} must be on {pin}'
print('PASS Arty A7 MII/clock/UART/LED pin mapping:',len(pins),'pins')
top=(ROOT/'rtl/ethernet_uart_a7.sv').read_text()
assert 'feed_pipeline u_core' in top and 'mii_udp_rx u_mii' in top
assert 'uart_tx #(' in top and 'eth_tx_en = 1\'b0' in top
assert 'assign eth_ref_clk = div4[1]' in top
print('PASS PHY clock, receive-only mode and existing processing core')
flow=(ROOT/'scripts/build_ethernet_m2a.tcl').read_text()
for file in ['mii_udp_rx.sv','ethernet_uart_a7.sv','feed_pipeline.sv','uart_tx.sv']:
    assert file in flow
assert 'create_clock -name eth_rx_25mhz -period 40.000' in xdc
print('PASS Tcl source list and external MII receive clock constraint')
