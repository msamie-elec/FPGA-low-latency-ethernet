"""Drive Board A's UART for deterministic one-at-a-time two-FPGA RTT checks.

Board B must run v0.5A endpoint bitstream. Board A must run M2C generator.
The UART telemetry frame is exactly 24 bytes and contains a 100MHz RTT
counter measured *on A*. Board B's v0.5A sends UART BEFORE Ethernet,
therefore RTT includes B UART diagnostic delay and is NOT wire-to-wire latency.
"""
from __future__ import annotations

import argparse
import csv
import statistics
import struct
import sys
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'software'))
from model import TopOfBook, decode  # noqa: E402
from m2c_vectors import record_for_command  # noqa: E402

TELEMETRY_SIZE = 24


def expected_response(book: TopOfBook, command: str, seq: int) -> bytes:
    record = record_for_command(command, seq)
    try:
        event = decode(record)
    except ValueError:
        return b'E'
    report = book.push(event)
    if report is None:
        return b'I'
    return b'R' + struct.pack('!III', *report[:3]) + bytes([report[3]])


def commands(count: int, pattern: str):
    for index in range(1, count + 1):
        if pattern == 'standard':
            yield 'S'
        elif index % 17 == 0:
            yield 'E'
        elif index % 11 == 0:
            yield 'I'
        else:
            yield 'S'


def parse_telemetry(raw: bytes) -> tuple[int, str, bytes, int]:
    if len(raw) != TELEMETRY_SIZE or raw[:1] != b'M':
        raise ValueError(f'bad 24-byte FPGA telemetry {raw.hex()}')
    seq = int.from_bytes(raw[1:5], 'big')
    status = chr(raw[5])
    rtt = int.from_bytes(raw[20:24], 'big')
    return seq, status, raw[6:20], rtt


def run():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--com', required=True, help='Board A UART port, NOT Board B')
    parser.add_argument('--count', type=int, default=1)
    parser.add_argument('--pattern', choices=['standard', 'mixed'], default='mixed')
    parser.add_argument('--interval-ms', type=float, default=0)
    parser.add_argument('--timeout-s', type=float, default=2.0)
    parser.add_argument('--csv', default='build/hardware/m2c_dual_board_rtt.csv')
    args = parser.parse_args()
    if not (1 <= args.count <= 10000):
        parser.error('count must be in 1..10000')
    if args.interval_ms < 0:
        parser.error('interval must be >=0')
    try:
        import serial
    except ImportError:
        parser.error('pyserial missing: python -m pip install pyserial')
    path = ROOT / args.csv
    path.parent.mkdir(parents=True, exist_ok=True)
    book = TopOfBook()
    rtts = []
    print(f'M2C A/B dual-board: {args.count} sequential transactions; '
          f'Board A UART={args.com}; pattern={args.pattern}')
    print('Before run: programme both boards, connect RJ45 directly, '
          'press/release BTN0 on BOTH boards.')
    print('RTT = 100MHz cycles on FPGA A: includes B UART emission, TX/RX CDC, '
          'and PHY frame transfer, excludes laptop and A telemetry UART.')
    with serial.Serial(args.com, 115200, timeout=args.timeout_s) as port, \
         path.open('w', newline='', encoding='utf-8') as fd:
        port.reset_input_buffer()
        writer = csv.DictWriter(fd, fieldnames=['sequence','command','status',
            'expected_hex','received_hex','rtt_cycles_100mhz','rtt_us',
            'passed'])
        writer.writeheader()
        for i, command in enumerate(commands(args.count, args.pattern), 1):
            expected = expected_response(book, command, i)
            port.write(command.encode('ascii'))
            port.flush()
            raw = port.read(TELEMETRY_SIZE)
            if len(raw) != TELEMETRY_SIZE:
                raise RuntimeError(f'packet {i}: no 24-byte telemetry '
                                   f'({len(raw)} bytes received, {raw.hex()})')
            seq, status, response, cycles = parse_telemetry(raw)
            actual = response[:len(expected)]
            correct = (seq == i and status == 'P' and actual == expected and
                       response[len(expected):] == bytes(14-len(expected)))
            writer.writerow(dict(sequence=i, command=command, status=status,
                expected_hex=expected.hex(), received_hex=response.hex(),
                rtt_cycles_100mhz=cycles, rtt_us=cycles/100,
                passed=correct))
            fd.flush()
            if not correct:
                raise RuntimeError(f'packet {i}: FPGA seq={seq} status={status} '
                                   f'reply={response.hex()} expected={expected.hex()}')
            rtts.append(cycles)
            if i in (1,args.count) or i % 25 == 0:
                print(f'PASS {i}/{args.count} command={command} '
                      f'response={expected.hex()} RTT={cycles/100:.2f} us')
            if args.interval_ms:
                time.sleep(args.interval_ms/1000)
    print(f'PASS {args.count}/{args.count} physical two-FPGA transactions')
    print(f'Hardware A counter RTT us: min={min(rtts)/100:.2f}, '
          f'median={statistics.median(rtts)/100:.2f}, max={max(rtts)/100:.2f}')
    print(f'CSV: {path}')
    print('NOTE: v0.5A B serial-diagnostic gating prevents low-latency claims.')


if __name__ == '__main__':
    run()
