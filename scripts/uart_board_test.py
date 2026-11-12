#!/usr/bin/env python3
"""Exercise a programmed Arty over its USB-UART port. Requires pyserial.

Request: exactly one 16-byte record. Response: 'R' + 13 data bytes,
'E' (malformed) or 'I' (ignored). The host waits for each entire reply.
NOT a low-latency transport or a substitute for actual Ethernet testing.
"""
import argparse
import struct
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'software'))
from model import encode, decode, TopOfBook


def samples():
    return [
        encode('B', 1, 1, 10000, 5),
        encode('A', 1, 2, 10003, 8),
        encode('A', 1, 3, 10020, 7),
        encode('B', 2, 4, 10018, 7),
        encode('A', 1, 5, 10019, 0),
        encode('B', 1, 6, 10016, 1),
        encode('B', 1, 7, 10022, 1),
        encode('B', 1, 8, 10010, 1),
        encode('A', 1, 9, 10011, 1),
        encode('A', 1, 10, 10000, 1, b'\x01\x00'),
    ]


def expected_response(record, book):
    try:
        update = decode(record)
    except ValueError:
        return b'E'
    report = book.push(update)
    if report is None:
        return b'I'
    return b'R' + struct.pack('>IIIB', *report)


def test(serial_port, records):
    book = TopOfBook()
    ok = 0
    for i, frame in enumerate(records):
        want = expected_response(frame, book)
        serial_port.write(frame)
        serial_port.flush()
        actual = serial_port.read(len(want))
        if actual != want:
            raise RuntimeError(f'Record {i}: expected {want.hex()}, got {actual.hex()} '
                               '(check board type, constraints, reset and UART settings)')
        print(f'PASS record {i:02d}: {actual.hex()}')
        ok += 1
    return ok


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--port', required=True, help='e.g. COM4 or /dev/ttyUSB1')
    ap.add_argument('--baud', type=int, default=115200)
    ap.add_argument('--timeout', type=float, default=2.0)
    args = ap.parse_args()
    try:
        import serial
    except ImportError:
        ap.error('pyserial missing: run python -m pip install pyserial')
    with serial.Serial(args.port, baudrate=args.baud, timeout=args.timeout) as port:
        # Press the board reset button BEFORE starting. Opening a port is not a reset.
        print('Testing board: press/release BTN0 now if it was used previously.')
        count = test(port, samples())
    print(f'PASS {count} board transactions (independent Python reference oracle)')


if __name__ == '__main__':
    main()
