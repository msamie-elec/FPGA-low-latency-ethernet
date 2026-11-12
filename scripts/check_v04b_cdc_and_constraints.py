#!/usr/bin/env python3
"""Static hygiene checks for v0.4B; NOT proof of metastability safety."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
rtl = (ROOT/'rtl/ethernet_uart_a7.sv').read_text()
xdc = (ROOT/'boards/arty_a7/ethernet_m2a.xdc').read_text()
assert 'bad_meta <= rx_reject_toggle' in rtl
assert 'bad_sync <= bad_meta' in rtl
assert 'if (bad_sync != bad_seen)' in rtl
assert 'if (bad_sync != bad_meta)' not in rtl
assert rtl.count('bad_meta') >= 3
for snippet in ('set_input_delay -clock [get_clocks eth_rx_25mhz] -min 10.000',
                'set_input_delay -clock [get_clocks eth_rx_25mhz] -max 30.000',
                'create_generated_clock -name phy_ref_25mhz',
                'get_pins {div4_reg[1]/Q}'):
    assert snippet in xdc, snippet
print('PASS static v0.4B CDC fanout, MII input-delay and reference-clock checks')
