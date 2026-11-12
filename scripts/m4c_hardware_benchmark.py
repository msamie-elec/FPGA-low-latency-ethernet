#!/usr/bin/env python3
"""M4C final finite hardware-native benchmark on Board A UART.

Sends one profile byte A/B/C and reads one 40-byte hardware-generated report.
The burst itself occurs in the FPGA, without per-packet Windows/UART pacing.
Run with Board A v0.9, Board B hardware-verified v0.8B, RJ45 between boards.
"""
from __future__ import annotations
import argparse
import csv
import json
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
import struct
import sys
import time

SIZE = 40
FORMAT = '>4s9I'
PROFILES = {'A': 10000, 'B': 2000, 'C': 1000}
FIELDS = ('sent', 'unique_replies', 'duplicate_replies', 'unexpected_replies',
          'invalid_replies', 'late_launches', 'min_gap_cycles',
          'max_gap_cycles', 'send_span_cycles')


@dataclass(frozen=True)
class Measurement:
    profile: str
    sent: int
    unique_replies: int
    duplicate_replies: int
    unexpected_replies: int
    invalid_replies: int
    late_launches: int
    min_gap_cycles: int
    max_gap_cycles: int
    send_span_cycles: int

    @property
    def missing(self) -> int:
        return max(0, self.sent - self.unique_replies)

    @property
    def delivery_percent(self) -> float:
        return 100 * self.unique_replies / self.sent if self.sent else 0.0

    @property
    def observed_request_rate_pps(self) -> float | None:
        # Count N-1 intervals from first to final request. Not wire-side PHY
        # assertion timing or response throughput.
        if self.sent < 2 or not self.send_span_cycles:
            return None
        return (self.sent - 1) * 100_000_000 / self.send_span_cycles


def parse_telemetry(data: bytes, expected_profile: str, packet_count: int) -> Measurement:
    if len(data) != SIZE:
        raise ValueError(f'Expected 40 UART bytes, got {len(data)}: {data.hex()}')
    header, *values = struct.unpack(FORMAT, data)
    if header[0] != ord('B') or header[1] != ord(expected_profile):
        raise ValueError(f'Wrong response magic/profile: {header.hex()}')
    if header[2] != 1 or header[3] != 0:
        raise ValueError(f'Wrong response version/reserved field: {header.hex()}')
    m = Measurement(expected_profile, *values)
    if m.sent != packet_count:
        raise ValueError(f'FPGA transmitted {m.sent} records, expected {packet_count}')
    if m.unique_replies > m.sent:
        raise ValueError('Unique reply count exceeds transmitted packet count')
    if m.min_gap_cycles > m.max_gap_cycles and m.sent > 1:
        raise ValueError('Invalid min/max inter-request gap measurements')
    return m


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--com', required=True, help='Board A COM port (previously COM4)')
    p.add_argument('--profile', choices=['A', 'B', 'C', 'all'], default='all')
    p.add_argument('--repeat', type=int, default=3)
    p.add_argument('--packets', type=int, default=1000)
    p.add_argument('--timeout-s', type=float, default=8)
    p.add_argument('--gap-between-runs-s', type=float, default=.1)
    p.add_argument('--require-all', action='store_true', help='Nonzero exit on ANY missing/invalid/duplicate reply')
    p.add_argument('--csv', default='build/hardware/m4c_hardware_benchmark.csv')
    args = p.parse_args(argv)
    if args.repeat < 1 or args.repeat > 100 or args.packets < 1 or args.packets > 65535:
        p.error('repeat=1..100 and packets=1..65535')
    if args.timeout_s <= 0 or args.gap_between_runs_s < 0:
        p.error('timeout must be positive; run gap must not be negative')
    try:
        import serial
    except ImportError:
        p.error('pyserial is required: python -m pip install pyserial')
    profiles = ('A','B','C') if args.profile=='all' else (args.profile,)
    path = Path(args.csv)
    path.parent.mkdir(parents=True, exist_ok=True)
    all_rows = []
    failed = False
    print('M4C v0.9 FPGA-native benchmark — Board A hardware sends the bursts')
    print('Board A v0.9 via UART, Board B unchanged v0.8B; direct RJ45; '
          'press/release BTN0 on both and verify link BEFORE run.')
    print('Profiles: A=100us, B=20us, C=10us target send-request spacing; '
          'the FPGA reports actual 100MHz cycle gaps.')
    # A serial timeout should comfortably include 100ms worst profile +
    # drain + 40-byte UART telemetry; 8s is a conservative default.
    with serial.Serial(args.com,115200,timeout=args.timeout_s) as port, \
         path.open('w',newline='',encoding='utf-8') as fd:
        port.reset_input_buffer()
        columns=['captured_utc','profile','repeat_index','requested_period_cycles','requested_period_us'] \
                + list(FIELDS) + ['missing','delivery_percent', 'observed_request_rate_pps',
                                  'min_gap_us','max_gap_us','send_span_us','passed_loss_free']
        w=csv.DictWriter(fd,fieldnames=columns)
        w.writeheader()
        for profile in profiles:
            for rep in range(1,args.repeat+1):
                port.write(profile.encode('ascii'))
                port.flush()
                raw=port.read(SIZE)
                try:
                    m=parse_telemetry(raw,profile,args.packets)
                except Exception as exc:
                    print(f'FAIL profile={profile} repetition={rep}: {exc}',file=sys.stderr)
                    raise
                loss_free=(m.missing==0 and m.duplicate_replies==0 and
                           m.unexpected_replies==0 and m.invalid_replies==0)
                row={'captured_utc':datetime.now(timezone.utc).isoformat(),
                     'profile':profile,'repeat_index':rep,
                     'requested_period_cycles':PROFILES[profile],
                     'requested_period_us':PROFILES[profile]/100,**{k:getattr(m,k) for k in FIELDS},
                     'missing':m.missing,
                     'delivery_percent':round(m.delivery_percent,4),
                     'observed_request_rate_pps':m.observed_request_rate_pps,
                     'min_gap_us':m.min_gap_cycles/100,
                     'max_gap_us':m.max_gap_cycles/100,
                     'send_span_us':m.send_span_cycles/100,
                     'passed_loss_free':loss_free}
                w.writerow(row); fd.flush()
                all_rows.append(row)
                print(f'{profile} run {rep}/{args.repeat}: '
                      f'sent={m.sent}, unique={m.unique_replies}, missing={m.missing}, '
                      f'dup={m.duplicate_replies}, invalid={m.invalid_replies}, '
                      f'late={m.late_launches}, delivery={m.delivery_percent:.2f}%, '
                      f'actual request rate={m.observed_request_rate_pps or 0:.1f} pkt/s')
                if not loss_free: failed=True
                if args.gap_between_runs_s:
                    time.sleep(args.gap_between_runs_s)
    summary = {'tool':'m4c_hardware_benchmark_v1','run_utc':datetime.now(timezone.utc).isoformat(),
               'board_a':'v0.9 M4C generator candidate','board_b':'v0.8B FIFO endpoint, unchanged',
               'clock_hz':100000000,'packet_count_per_run':args.packets,
               'note':'Hardware TX request intervals and reply counts only. TX pins and wire-rate need external instrumentation. '
                      'Missing replies cannot be assigned solely to Board B without its counters.',
               'results':all_rows}
    path.with_suffix('.summary.json').write_text(json.dumps(summary,indent=2)+'\n',encoding='utf-8')
    print(f'CSV: {path} | Summary: {path.with_suffix(".summary.json")}')
    if failed and args.require_all:
        print('FAIL strict loss-free requirement; record the limitation; do not launch redesign automatically')
        return 2
    print('PASS benchmark acquisition (individual profile results above may include loss)')
    return 0


if __name__=='__main__':
    sys.exit(main())
