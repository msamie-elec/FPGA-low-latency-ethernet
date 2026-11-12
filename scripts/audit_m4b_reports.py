#!/usr/bin/env python3
"""Post-route candidate report gate. Cannot replace manual CDC/board review."""
import re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
D=ROOT/'build/reports/ethernet_m4b_endpoint'
needed=['timing_summary.rpt','cdc.rpt','methodology.rpt',
        'clock_interaction.rpt','check_timing.rpt',
        'tx_setup.rpt','tx_hold.rpt']
for name in needed:
    if not (D/name).is_file(): raise SystemExit(f'FAIL missing report: {D/name}')
t=(D/'timing_summary.rpt').read_text(errors='replace')
c=(D/'cdc.rpt').read_text(errors='replace')
m=(D/'methodology.rpt').read_text(errors='replace')
i=(D/'clock_interaction.rpt').read_text(errors='replace')
mat=re.search(r'^\s*([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+\d+\s+\d+\s+'
              r'([-+]?\d+\.\d+)\s+([-+]?\d+\.\d+)\s+\d+\s+\d+',t,re.M)
if not mat: raise SystemExit('FAIL cannot identify overall setup/hold summary')
wns,tns,whs,ths=map(float,mat.groups())
if 'CDC Report' not in c: raise SystemExit('FAIL no recognised CDC report')
c1=re.search(r'^CDC-1\s+Critical\s+(\d+)\b',c,re.M)
cdc1=int(c1.group(1)) if c1 else 0
c15=re.search(r'^CDC-15\s+Warning\s+(\d+)\b',c,re.M)
print(f'M4B timing WNS={wns:+.3f}ns TNS={tns:.3f}ns WHS={whs:+.3f}ns THS={ths:.3f}ns')
print(f'M4B CDC-1 Critical={cdc1}, CDC-15 Warning={c15.group(1) if c15 else "not reported"}')
issues=[]
if min(wns,whs)<0 or tns<0 or ths<0: issues.append('negative timing slack')
if cdc1>0: issues.append('critical CDC-1 warnings')
if not re.search(r'eth_tx_25mhz\s+eth_tx_25mhz',i): issues.append('TX clock missing')
if 'TIMING-9' in m: issues.append('TIMING-9 unknown CDC methodology')
for r in ('tx_setup.rpt','tx_hold.rpt'):
    text=(D/r).read_text(errors='replace')
    if 'eth_txd' not in text and 'eth_tx_en' not in text:
        issues.append(f'no recognizable MII TX path in {r}')
if issues:
    for problem in issues: print('FAIL:',problem)
    raise SystemExit(1)
print('PASS M4B preliminary report gate: nonnegative constrained slacks and no critical CDC-1')
print('WARNING: Gray-pointer FIFO CDC, MII IOB skew, async reset and exact overflow policy require manual review.')
print('Do NOT programme FPGA until the full reports have been reviewed.')
