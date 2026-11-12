"""Fail-closed static sanity checks; does not replace RTL/Vivado/board tests."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
gen = (root/'rtl/ethernet_generator_a7_m2c.sv').read_text()
tx = (root/'rtl/mii_feed_tx.sv').read_text()
rx = (root/'rtl/mii_reply_rx.sv').read_text()
board = (root/'boards/arty_a7/ethernet_m2c_generator.xdc').read_text()
base = (root/'boards/arty_a7/ethernet_m2b.xdc').read_text()
endpoint = (root/'boards/arty_a7/ethernet_m2c_endpoint.xdc').read_text()
assert endpoint == base, 'The endpoint must preserve the v0.5A constraints exactly'
assert 'module ethernet_udp_a7' in (root/'rtl/ethernet_udp_a7.sv').read_text()
assert 'uart_rx_i' in gen and 'uart_tx_o' in gen
assert 'PACKAGE_PIN A9' in board and 'PACKAGE_PIN D10' in board
assert 'create_generated_clock' in board and 'set_output_delay' in board
assert 'set_property IOB TRUE' in board
assert all(token in tx for token in ('32\'h00004D03', "7'd43: stream_byte=8'h8a", "7'd45: stream_byte=8'h88", "7'd19: stream_byte=8'h66", 'held_data<=feed_data'))
assert all(token in rx for token in ("16'd22", "16'd9", "8'h89", "32'hdebb20e3"))
assert all(token in gen for token in ('rx_req_sync', 'rx_ack_toggle', 'tx_ack_sync', 'telemetry', 'REPLY_TIMEOUT_CYCLES'))
assert 'rtl/ethernet_generator_a7_m2c.sv' not in (root/'scripts/build_m2c_endpoint.tcl').read_text()
for board_name, top in [('generator','ethernet_generator_a7_m2c'), ('endpoint','ethernet_udp_a7')]:
    tcl=(root/f'scripts/build_m2c_{board_name}.tcl').read_text()
    assert f'set_property top {top}' in tcl
    assert f'ethernet_m2c_{board_name}.xdc' in tcl
    assert 'report_cdc' in tcl and 'report_timing_summary' in tcl
    assert 'worst_slack < 0 || $cdc1 > 0' in tcl
    print(f'PASS M2C {board_name} Vivado build and release gate present')
for file in sorted((root/'tests/generated').glob('m2c_*.hex')):
    assert len(bytes.fromhex(file.read_text())) == 72, file
print('PASS M2C baseline isolation, PHY TX constraints, CDC synchronisers, Python vectors')
print('NOTICE: static checks are not RTL simulation, Vivado timing closure or physical proof')
