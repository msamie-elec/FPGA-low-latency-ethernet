#!/usr/bin/env python3
"""Read-only packaging consistency report for the incremental M2A project."""
from pathlib import Path
r=Path(__file__).resolve().parents[1]
for p in ['rtl/feed_pipeline.sv','rtl/mii_udp_rx.sv','rtl/ethernet_uart_a7.sv',
    'boards/arty_a7/ethernet_m2a.xdc','scripts/build_ethernet_m2a.tcl',
    'scripts/ethernet_to_uart_test.py','docs/ethernet_v0_4a.md']:
    assert (r / p).is_file(), p
print('PASS M2A source artifact completeness')
