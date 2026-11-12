#!/usr/bin/env python3
"""M3 v0.7 fail-closed structural and baseline immutability checks.

Not a substitute for simulator, Vivado, CDC proof, or hardware testing.
"""
from pathlib import Path
import hashlib
root=Path(__file__).resolve().parents[1]
low=(root/'rtl/ethernet_udp_a7_lowlat.sv').read_text()
base=(root/'rtl/ethernet_udp_a7.sv').read_text()
assert 'module ethernet_udp_a7_lowlat' in low
assert 'module ethernet_udp_a7 #(' in base
assert 'module ethernet_udp_a7_lowlat' not in base
assert 'tx_req_toggle <= ~tx_req_toggle;' in low
assert 'uart_start_toggle <= ~uart_start_toggle;' in low
assert 'UART_WAIT_READY' in low and 'WAIT_OUTPUTS' in low
assert 'uart_done_toggle == uart_start_toggle' in low
assert 'tx_ack_sync == tx_req_toggle' in low
assert 'rx_ack_toggle <= req_sync;' in low
assert 'uart_byte <= tx_data_buf[111-uart_index*8 -: 8];' in low
# Ensure UDP TX is NOT triggered by UART completion as it was in v0.5A.
ctrl=low.split('WAIT_RESULT: begin')[1].split('WAIT_OUTPUTS: begin')[0]
assert 'tx_req_toggle <= ~tx_req_toggle;' in ctrl
assert 'UART_WAIT_READY' not in ctrl
assert hashlib.sha256(base.encode()).hexdigest()=='578e53275f7a15a55f27ee61f91ea2721ee92728f3abf4811f69e93edd4264cd'
for f in ('rtl/ethernet_generator_a7_m2c.sv','rtl/mii_feed_tx.sv',
          'rtl/mii_reply_rx.sv','rtl/mii_udp_rx.sv','rtl/mii_udp_tx.sv'):
    assert (root/f).is_file()
assert (root/'boards/arty_a7/ethernet_m3_endpoint.xdc').read_bytes() == (root/'boards/arty_a7/ethernet_m2c_endpoint.xdc').read_bytes()
build=(root/'scripts/build_m3_endpoint.tcl').read_text()
assert 'ethernet_udp_a7_lowlat.sv' in build
assert 'set_property top ethernet_udp_a7_lowlat' in build
assert 'ethernet_m3_endpoint' in build
assert 'worst_hold_slack < 0' in build and '$cdc1 > 0' in build
assert 'report_timing_summary' in build and 'report_cdc' in build
assert 'eth_ref_clk' in build
sim=(root/'scripts/run_m3_sim.ps1').read_text()
for bench in ('tb_m3_board_pair','tb_ethernet_udp_a7_lowlat'):
    assert bench in sim
assert "rtt >= 32'd25000" in (root/'tb/tb_m3_board_pair.sv').read_text()
print('PASS v0.7 parallel response state machines and UART/UDP mailbox hold checks')
print('PASS original 200/200-v0.5A endpoint and M2C generator source preserved')
print('PASS Ethernet constraints, independent simulation and Vivado release gates present')
print('NOTICE: structural checks do not prove RTL timing/CDC correctness')
