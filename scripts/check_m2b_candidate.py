#!/usr/bin/env python3
"""Structural contract and integration checks for M2B. Not timing/simulation sign-off."""
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
rtl_tx=(ROOT/'rtl'/'mii_udp_tx.sv').read_text()
rtl_top=(ROOT/'rtl'/'ethernet_udp_a7.sv').read_text()
rtl_old=(ROOT/'rtl'/'ethernet_uart_a7.sv').read_text()
xdc=(ROOT/'boards/arty_a7/ethernet_m2b.xdc').read_text()
tcl=(ROOT/'scripts/build_ethernet_m2b.tcl').read_text()
checks={
    'Dedicated M2B top preserves v0.4B top': 'module ethernet_uart_a7' in rtl_old and 'module ethernet_udp_a7' in rtl_top,
    'Transmit MII and PHY TX_CLK pin': 'PACKAGE_PIN H16' in xdc and '[get_ports eth_tx_clk]' in xdc,
    'Source-synchronous TX output constraints': 'set_output_delay -clock [get_clocks eth_tx_25mhz]' in xdc,
    '25MHz clock domain defined': 'create_clock -name eth_tx_25mhz -period 40.000' in xdc,
    'TX mailbox handshaking': 'req_toggle_async' in rtl_tx and 'ack_toggle<=req_sync;' in rtl_tx,
    'TX CRC32': "32'hEDB88320" in rtl_tx and 'crc_byte(crc,stream_byte)' in rtl_tx,
    'All MII pads driven': '.eth_tx_en(eth_tx_en)' in rtl_top and '.eth_txd(eth_txd)' in rtl_top,
    'UART mirror still present': 'uart_tx #' in rtl_top and 'TX_WAIT_READY' in rtl_top,
    'Bidirectional build TCL': 'set_property top ethernet_udp_a7' in tcl and 'mii_udp_tx.sv' in tcl,
    'TX length is captured before controlling FSM': 'state<=VALIDATE' in rtl_tx and "(held_len == 4'd1)" in rtl_tx and "(response_len == 4'd1)" not in rtl_tx,
    'IOB packing requested on TX outputs': 'set_property IOB TRUE $mii_tx_ports' in xdc,
    'Vivado release gate checks WNS and critical CDC': 'get_timing_paths -setup' in tcl and 'critical CDC-1 count' in tcl,
}
for title,passed in checks.items():
    print(('PASS' if passed else 'FAIL'),title)
if not all(checks.values()):
    raise SystemExit(1)
print('PASS M2B structural checks; this is not a substitute for Icarus/Vivado/physical tests')
