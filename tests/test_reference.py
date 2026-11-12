"""Executable, non-RTL checks; see README for HDL simulation status."""
import random
import subprocess
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'software'))
from model import encode, decode, process, TopOfBook


def test_known_case():
    frames = [encode('B', 1, 1, 10000, 5), encode('A', 1, 2, 10003, 3),
              encode('A', 1, 3, 10020, 3), encode('B', 2, 4, 10018, 5)]
    assert process(frames) == ([(1, 10000, 0, 0), (2, 10000, 10003, 1),
                                (3, 10000, 10020, 0)], 0)


def test_boundaries_and_malformed():
    record = encode('A', 255, 2**32-1, 2**32-1, 2**32-1)
    assert decode(record).sequence == 2**32 - 1
    for bad in (b'', record[:-1], b'X' + record[1:], record[:-1] + b'\x01'):
        try:
            decode(bad)
        except ValueError:
            pass
        else:
            raise AssertionError('accepted malformed record')
    assert process([record[:-1], record])[1] == 1


def test_random_python_cpp_oracle(tmp_path):
    rng = random.Random(0x20261027)
    records = []
    for i in range(1200):
        record = encode(rng.choice(['A', 'B']), rng.choice([1, 1, 1, 2]), i,
                        rng.randint(1, 20000), rng.randint(0, 10))
        if i % 47 == 0:  # deliberately malformed header
            record = b'X' + record[1:]
        elif i % 59 == 0:  # malformed reserved byte
            record = record[:-1] + b'\x01'
        records.append(record)
    expected, errors = process(records)
    binary = tmp_path / 'feed_reference'
    subprocess.run(['g++', '-std=c++17', '-O2', '-Wall', '-Wextra', '-Werror',
                    str(ROOT / 'software' / 'feed_reference.cpp'), '-o', str(binary)], check=True)
    proc = subprocess.run([str(binary)], input='\n'.join(r.hex() for r in records) + '\n',
                          capture_output=True, text=True, check=True)
    actual = [tuple(map(int, line.split(','))) for line in proc.stdout.splitlines()]
    assert actual == expected
    assert proc.stderr.strip() == f'Rejected records: {errors}'
