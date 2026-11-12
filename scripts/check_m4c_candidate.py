#!/usr/bin/env python3
"""M4C source freeze and structural smoke checks; NOT substitute for simulation."""
import hashlib, json
from pathlib import Path
R=Path(__file__).resolve().parents[1]
freeze=json.loads((R/'docs/baselines/M4C_source_freeze.json').read_text())['files']
for path, digest in freeze.items():
    assert hashlib.sha256((R/path).read_bytes()).hexdigest()==digest, f'Source modified: {path}'
for path in ('rtl/ethernet_generator_a7_m4c.sv','scripts/m4c_hardware_benchmark.py',
             'scripts/build_m4c_generator.tcl','scripts/run_m4c_sim.ps1',
             'boards/arty_a7/ethernet_m4c_generator.xdc','tb/tb_m4c_board_pair.sv',
             'docs/M4C_BENCHMARK_PROTOCOL.md','docs/PORTFOLIO_V1_RELEASE_PLAN.md'):
    assert (R/path).is_file(), f'Missing {path}'
s=(R/'rtl/ethernet_generator_a7_m4c.sv').read_text()
for check in ('mii_feed_tx u_feed_tx','mii_reply_rx u_reply_rx',
              'seen_reply','unique_count','late_count','send_span',
              'PERIOD_A_CYCLES=10000','PERIOD_B_CYCLES=2000',
              'PERIOD_C_CYCLES=1000','tx_ack_sync==tx_req_toggle'):
    assert check in s, check
assert 'set_output_delay' in (R/'boards/arty_a7/ethernet_m4c_generator.xdc').read_text()
print(f'PASS frozen original RTL/XDC integrity: {len(freeze)} files')
print('PASS M4C structural precheck; RTL simulation and Vivado still required')
