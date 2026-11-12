#!/usr/bin/env python3
"""Tabulate M4A host-side burst acceptance experiments.

Input files are the .summary.json outputs of m4a_burst_probe.py.  Results do
not prove a specific FPGA throughput ceiling because Windows and the NIC can
also buffer or discard packets; no ILA/PHY wire capture is present.
"""
from __future__ import annotations
import argparse
import csv
import json
from pathlib import Path


def consolidate(paths):
    rows=[]
    for p in paths:
        obj=json.loads(Path(p).read_text(encoding='utf-8'))
        if obj.get('tool') != 'm4a_burst_probe_v1':
            raise ValueError(f'Unsupported result format: {p}')
        count = obj['sent_count']
        valid = obj['valid_response_count']
        if count < 0 or valid < 0 or valid > count:
            raise ValueError(f'Invalid counts in {p}')
        rows.append(dict(file=str(p), gap_ms=obj['requested_send_gap_ms'],
            sent=count, received=valid, delivery_percent=round(valid*100/max(count,1),3),
            missing=obj['missing_response_count'],
            duplicates=obj['duplicate_response_count'],
            corrupt=obj['corrupt_response_count'],
            unexpected=obj['unexpected_response_count'],
            host_send_rate_pps=obj['observed_host_send_rate_packets_s']))
    return rows


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('summaries',nargs='+',type=Path)
    ap.add_argument('--out',type=Path,default=Path('build/hardware/m4a_probe_matrix.csv'))
    a=ap.parse_args()
    rows=consolidate(a.summaries)
    a.out.parent.mkdir(parents=True,exist_ok=True)
    with a.out.open('w',newline='',encoding='utf-8') as fd:
        w=csv.DictWriter(fd,fieldnames=list(rows[0]))
        w.writeheader(); w.writerows(rows)
    print('Requested gap (ms) | Sent | Valid replies | Delivery % | Missing | Host send rate (pkt/s)')
    for r in sorted(rows,key=lambda x:x['gap_ms'],reverse=True):
        print(f"{r['gap_ms']:>18g} | {r['sent']:>4} | {r['received']:>13} | "
              f"{r['delivery_percent']:>10.2f} | {r['missing']:>7} | {r['host_send_rate_pps']}")
    print(f'Matrix: {a.out}')
    print('These are host-observed burst deliveries, NOT a validated FPGA or wire-rate ceiling.')

if __name__=='__main__':
    main()
