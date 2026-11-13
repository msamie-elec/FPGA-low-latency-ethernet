#!/usr/bin/env python3
"""Operator-assisted, non-destructive first-burst reliability test for M4C.

Runs Board A's EXISTING 1,000-request A/B/C FPGA-paced benchmark, collecting
its 40-byte UART telemetry. Does not program/reset the boards automatically.
"""
from __future__ import annotations

import argparse
import csv
from datetime import datetime, timezone
import json
from pathlib import Path
import sys
import time

from m4c_hardware_benchmark import FIELDS, PROFILES, SIZE, parse_telemetry


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


COLUMNS = [
    'captured_utc', 'cycle', 'mode', 'phase', 'profile', 'status', 'error',
    'uart_bytes', 'raw_uart_hex', 'discarded_uart_hex', 'elapsed_s',
    'requested_period_us', *FIELDS, 'missing', 'delivery_percent',
    'observed_request_rate_pps', 'passed_loss_free',
]


def acquire(port, *, cycle: int, mode: str, phase: str, profile: str) -> dict:
    """One command and one 40-byte reply; never auto-retry a failed first run."""
    pending = port.in_waiting
    stale = port.read(pending) if pending else b''
    port.reset_input_buffer()
    row = dict.fromkeys(COLUMNS, '')
    row.update(captured_utc=utc_now(), cycle=cycle, mode=mode, phase=phase,
               profile=profile, status='ERROR', discarded_uart_hex=stale.hex(),
               requested_period_us=PROFILES[profile] / 100)
    raw = b''
    began = time.monotonic()
    try:
        port.write(profile.encode('ascii'))
        port.flush()
        raw = port.read(SIZE)
        measurement = parse_telemetry(raw, profile, 1000)
        loss_free = (measurement.missing == 0 and
                     measurement.duplicate_replies == 0 and
                     measurement.unexpected_replies == 0 and
                     measurement.invalid_replies == 0)
        row.update({name: getattr(measurement, name) for name in FIELDS})
        row.update(missing=measurement.missing,
                   delivery_percent=round(measurement.delivery_percent, 4),
                   observed_request_rate_pps=measurement.observed_request_rate_pps,
                   passed_loss_free=loss_free,
                   status='PASS' if loss_free else 'FAIL')
    except Exception as exc:
        row['error'] = f'{type(exc).__name__}: {exc}'
    row.update(elapsed_s=round(time.monotonic() - began, 6),
               uart_bytes=len(raw), raw_uart_hex=raw.hex())
    return row


def make_session(root: Path) -> Path:
    stamp = datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%S%fZ')
    session = root / f'cold_start_{stamp}'
    session.mkdir(parents=True, exist_ok=False)
    return session


def write_summary(path: Path, *, mode: str, profile: str,
                  rows: list[dict], completed: bool) -> None:
    first = [r for r in rows if r['phase'] == 'first']
    warm = [r for r in rows if r['phase'] == 'warm']
    payload = {
        'tool': 'm4c_cold_start_v1', 'captured_utc': utc_now(),
        'mode': mode, 'profile': profile, 'packet_count_per_burst': 1000,
        'completed': completed,
        'first_run_passes': sum(r['status'] == 'PASS' for r in first),
        'first_run_trials': len(first),
        'warm_run_passes': sum(r['status'] == 'PASS' for r in warm),
        'warm_run_trials': len(warm),
        'note': ('Operator confirms reset/link before each first burst. '
                 'The script does not measure power-on-to-link-ready time, PHY wire timestamps, '
                 'sustained throughput, or the precise delay from BTN0 release to command. '
                 'A manual BTN0 reset is not a true electrical power cycle. '
                 'Errors and missing UART bytes are not silently retried.'),
        'runs': rows,
    }
    temp = path.with_name(path.name + '.tmp')
    temp.write_text(json.dumps(payload, indent=2) + '\n', encoding='utf-8')
    temp.replace(path)


def main(argv=None) -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--com', required=True, help='Board A UART (e.g. COM4); recheck mapping')
    p.add_argument('--profile', choices=tuple(PROFILES), default='C')
    p.add_argument('--cycles', type=int, default=10)
    p.add_argument('--mode', choices=('reset', 'power-cycle'), default='reset')
    p.add_argument('--warm-runs', type=int, default=1)
    p.add_argument('--timeout-s', type=float, default=8)
    p.add_argument('--gap-s', type=float, default=.2)
    p.add_argument('--out-root', default='build/hardware/cold_start')
    args = p.parse_args(argv)
    if not 1 <= args.cycles <= 100 or not 0 <= args.warm_runs <= 10:
        p.error('cycles must be 1..100; warm-runs must be 0..10')
    if args.timeout_s <= 0 or args.gap_s < 0:
        p.error('timeout-s must be positive, gap-s must be nonnegative')
    try:
        import serial
    except ImportError:
        p.error('Install pyserial first: python -m pip install pyserial')

    session = make_session(Path(args.out_root))
    csv_path, summary_path = session / 'results.csv', session / 'summary.json'
    rows: list[dict] = []
    print(f'Cold-start evidence directory (never reused): {session}')
    print('Use Board A v0.9, Board B v0.8B and their matching bitstreams; '
          'direct RJ45, both USB connected. No RTL or bitstream changes.')
    print('Important: press/release BTN0 on BOTH boards (reset mode), or remove '
          'and restore BOTH USB supplies then reprogram both bitstreams if JTAG-only '
          '(power-cycle mode). Verify expected bitstream identity and link.')
    print('For each cycle, confirm both PHY links are established BEFORE typing READY.')

    def record(row: dict, writer, output) -> None:
        rows.append(row)
        writer.writerow(row)
        output.flush()
        write_summary(summary_path, mode=args.mode, profile=args.profile,
                      rows=rows, completed=False)
        print(f"  cycle={row['cycle']} {row['phase']}: {row['status']} "
              f"received={row['uart_bytes']}/40 missing={row['missing']} "
              f"unique={row['unique_replies']} {row['error']}")

    def run_cycle(i: int, writer, output, fixed_port=None) -> None:
        instruction = ('press/release BTN0 on both boards' if args.mode == 'reset'
                       else 'power-cycle both boards, then reprogram if needed')
        answer = input(f'Cycle {i}/{args.cycles}: {instruction}; wait for PHY link; '
                       'type READY then Enter to run FIRST burst: ').strip()
        if answer != 'READY':
            raise KeyboardInterrupt('Operator did not confirm READY')
        if fixed_port is None:
            # USB serial ports may disappear during a power cycle; reopen afterwards.
            with serial.Serial(args.com, 115200, timeout=args.timeout_s) as port:
                run_bursts(i, writer, output, port)
        else:
            run_bursts(i, writer, output, fixed_port)

    def run_bursts(i: int, writer, output, port) -> None:
        record(acquire(port, cycle=i, mode=args.mode, phase='first', profile=args.profile),
               writer, output)
        for j in range(1, args.warm_runs + 1):
            if args.gap_s:
                time.sleep(args.gap_s)
            record(acquire(port, cycle=i, mode=args.mode, phase='warm', profile=args.profile),
                   writer, output)

    interrupted = False
    with csv_path.open('x', newline='', encoding='utf-8') as output:
        writer = csv.DictWriter(output, fieldnames=COLUMNS)
        writer.writeheader(); output.flush()
        try:
            if args.mode == 'reset':
                # Keep UART open while the operator resets both FPGAs.
                with serial.Serial(args.com, 115200, timeout=args.timeout_s) as port:
                    for i in range(1, args.cycles + 1):
                        run_cycle(i, writer, output, port)
            else:
                for i in range(1, args.cycles + 1):
                    run_cycle(i, writer, output)
        except (KeyboardInterrupt, EOFError) as exc:
            interrupted = True
            print(f'Operator stopped test: {exc}', file=sys.stderr)
        except Exception as exc:
            interrupted = True
            print(f'Test stopped by I/O failure: {type(exc).__name__}: {exc}', file=sys.stderr)
    write_summary(summary_path, mode=args.mode, profile=args.profile,
                  rows=rows, completed=not interrupted and
                  sum(r['phase'] == 'first' for r in rows) == args.cycles)
    first_rows = [r for r in rows if r['phase'] == 'first']
    passes = sum(r['status'] == 'PASS' for r in first_rows)
    print(f'First-burst passes: {passes}/{len(first_rows)}; CSV: {csv_path}; JSON: {summary_path}')
    return 0 if not interrupted and len(first_rows) == args.cycles and passes == args.cycles and all(
        r['status'] == 'PASS' for r in rows) else 2


if __name__ == '__main__':
    sys.exit(main())
