#!/usr/bin/env python3
"""Compare independent Board-A hardware RTT logs for v0.6 vs v0.7.

The CSV values are counter readings, not FPGA-only or one-way latency.
Both runs MUST use the same Board A bitstream, stimulus and reset protocol.
"""
from __future__ import annotations
import argparse, csv, math, statistics
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_BASELINE = ROOT / 'docs/baselines/m2c_v06_hardware_rtt_200.csv'
DEFAULT_NEW = ROOT / 'build/hardware/m3_dual_board_rtt.csv'

def read_csv(path):
    out=[]
    with Path(path).open(newline='',encoding='utf-8-sig') as f:
        reader=csv.DictReader(f)
        needed={'sequence','command','status','expected_hex','received_hex','rtt_cycles_100mhz','passed'}
        if not needed.issubset(reader.fieldnames or ()):
            raise ValueError(f'Invalid hardware CSV header in {path}')
        for row in reader:
            if row['passed'].lower() != 'true' or row['status'] != 'P':
                raise ValueError(f'Unpassed FPGA packet in {path}: {row}')
            if int(row['rtt_cycles_100mhz'])<=0:
                raise ValueError(f'Invalid RTT counter in {path}: {row}')
            out.append(row)
    if not out: raise ValueError(f'Empty hardware log: {path}')
    return out

def percentile(values, q):
    seq=sorted(values)
    pos=(len(seq)-1)*q
    lo=int(math.floor(pos)); hi=int(math.ceil(pos))
    return seq[lo]*(hi-pos) + seq[hi]*(pos-lo) if hi!=lo else seq[lo]

def by_type(rows,key):
    return [int(x['rtt_cycles_100mhz'])/100 for x in rows if x['command']==key]

def compare(old,new):
    if len(old)!=len(new): raise ValueError('Record counts differ; run the same --count on both versions')
    for a,b in zip(old,new):
        for f in ('sequence','command','expected_hex'):
            if a[f]!=b[f]: raise ValueError(f'Input/expected mismatch at seq {a["sequence"]}: field {f}')
        if a['received_hex'] != b['received_hex']:
            raise ValueError(f'Responses differ at seq {a["sequence"]}')
    print(f'PASS paired {len(old)} packet records, all expected responses identical')
    print(f'{"Type":<9} {"Count":>5} {"v0.6 mean us":>14} {"v0.7 mean us":>14} {"Reduction us":>14} {"Reduction %":>12} {"v0.7 p95 us":>14}')
    for key in ('S','I','E'):
        a,b=by_type(old,key),by_type(new,key)
        if not a: continue
        ma,mb=statistics.mean(a),statistics.mean(b)
        diff=ma-mb
        print(f'{key:<9} {len(a):>5} {ma:>14.3f} {mb:>14.3f} {diff:>14.3f} {100*diff/ma:>11.1f}% {percentile(b,.95):>14.3f}')
    a=[int(x['rtt_cycles_100mhz'])/100 for x in old]
    b=[int(x['rtt_cycles_100mhz'])/100 for x in new]
    print(f'Overall median RTT us: v0.6={statistics.median(a):.3f}  v0.7={statistics.median(b):.3f}')
    print('No one-way latency, max throughput or PHY-only latency claim is implied.')

if __name__ == '__main__':
    q=argparse.ArgumentParser(description=__doc__)
    q.add_argument('--before',type=Path,default=DEFAULT_BASELINE)
    q.add_argument('--after',type=Path,default=DEFAULT_NEW)
    x=q.parse_args()
    compare(read_csv(x.before),read_csv(x.after))
