#!/usr/bin/env python3
"""Deterministic vectors; use these to cross-check independent implementations."""
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'software'))
from model import encode, process

root = Path(__file__).resolve().parents[1] / 'examples'
root.mkdir(parents=True, exist_ok=True)
records = [
    encode('B', 1, 1, 10000, 5),
    encode('A', 1, 2, 10003, 8),
    encode('A', 1, 3, 10020, 7),
    encode('B', 2, 4, 10018, 7),    # ignored: other symbol
    encode('A', 1, 5, 10019, 0),    # ignored: zero quantity
    encode('B', 1, 6, 10016, 1),
    encode('B', 1, 7, 10022, 1),    # crossed: signal false
    encode('B', 1, 8, 10010, 1),
    encode('A', 1, 9, 10011, 1),
    encode('A', 1, 10, 10000, 1, b'\x01\x00'),  # rejected
    b'\x41' * 15,                    # rejected: short
]
reports, errors = process(records)
(root / 'vectors.hex').write_text(''.join(r.hex() + '\n' for r in records))
(root / 'expected.csv').write_text('sequence,bid,ask,signal\n' + ''.join(','.join(map(str, row)) + '\n' for row in reports))
print(f'Wrote {len(records)} records, {len(reports)} reports, {errors} rejected records')
