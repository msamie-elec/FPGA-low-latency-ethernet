#!/usr/bin/env python3
"""Verify byte-for-byte preservation of the M3 v0.7 FPGA RTL and constraints."""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = ROOT/'docs/baselines/M4A_v07_rtl_xdc_sha256.json'


def verify():
    hashes=json.loads(MANIFEST.read_text(encoding='utf-8'))['files']
    actual={p.relative_to(ROOT).as_posix() for p in list((ROOT/'rtl').glob('*.sv')) +
            list((ROOT/'boards').rglob('*.xdc'))}
    if set(hashes)!=actual:
        raise RuntimeError(f'RTL/XDC file set changed: added={sorted(actual-set(hashes))}, missing={sorted(set(hashes)-actual)}')
    for name, expected in hashes.items():
        digest=hashlib.sha256((ROOT/name).read_bytes()).hexdigest()
        if digest!=expected: raise RuntimeError(f'FAIL changed FPGA source: {name}')
    print(f'PASS M4A source freeze: {len(hashes)} Verilog/constraints files byte-identical to M3 v0.7')
    print('M4A includes only host-side benchmark tools; it DOES NOT have an FPGA throughput upgrade.')


if __name__=='__main__': verify()
