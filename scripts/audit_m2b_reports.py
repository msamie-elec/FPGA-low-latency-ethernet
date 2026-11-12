#!/usr/bin/env python3
"""Post-route v0.5a release gate: verifies actual Vivado report findings.

Not a substitute for PHY board-skew qualification or multi-bit mailbox proofs.
Use after the build script generates build/reports/ethernet_m2b/*.rpt.
"""
from __future__ import annotations
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / 'build' / 'reports' / 'ethernet_m2b'
TIMING = REPORTS / 'timing_summary.rpt'
CDC = REPORTS / 'cdc.rpt'
CLOCKS = REPORTS / 'clock_interaction.rpt'
METHODOLOGY = REPORTS / 'methodology.rpt'

for file in (TIMING, CDC, CLOCKS, METHODOLOGY):
    if not file.is_file():
        raise SystemExit(f'FAIL: Missing report: {file}')

timing = TIMING.read_text(errors='replace')
cdc = CDC.read_text(errors='replace')
clocks = CLOCKS.read_text(errors='replace')
method = METHODOLOGY.read_text(errors='replace')

# Read the one-line Vivado summary to avoid mistaking good intra-domain WNS
# for the overall negative setup slack.
match = re.search(
    r'^\s*([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+\d+\s+\d+\s+'
    r'([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+\d+\s+\d+\s+',
    timing, re.MULTILINE
)
if not match:
    raise SystemExit('FAIL: Could not reliably parse timing summary table; inspect manually')
wns, tns, whs, ths = map(float, match.groups())
match = re.search(r'^CDC-1\s+Critical\s+(\d+)\b', cdc, re.MULTILINE)
cdc1 = int(match.group(1)) if match else 0
# Ensure a missing/unexpected CDC table is not silently treated as safe.
if 'CDC Report' not in cdc or 'CDC-3' not in cdc:
    raise SystemExit('FAIL: CDC report absent or unrecognised')

issues=[]
print(f'Vivado reported overall WNS={wns:+.3f} ns, TNS={tns:.3f} ns, '
      f'WHS={whs:+.3f} ns, THS={ths:.3f} ns')
print(f'Vivado reported CDC-1 critical crossings={cdc1}')
if wns < 0 or tns < 0 or whs < 0 or ths < 0:
    issues.append('Negative constrained setup/hold slack or negative total slack')
if cdc1:
    issues.append(f'{cdc1} critical CDC-1 crossings')
if not re.search(r'eth_tx_25mhz\s+eth_tx_25mhz',clocks):
    issues.append('TX 25 MHz clock missing from interaction report')
if 'TIMING-9' in method:
    issues.append('TIMING-9 unknown CDC warning in methodology')
for warning in issues:
    print('FAIL:', warning)
if issues:
    raise SystemExit(1)
print('PASS candidate report gate: zero critical CDC-1 and no constrained timing violations')
print('NOTICE: CDC-15 mailbox coherence, timing-18 external signals, MII board skew and power still require engineering review')
