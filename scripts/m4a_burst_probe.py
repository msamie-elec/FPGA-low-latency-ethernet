#!/usr/bin/env python3
"""M4A physical UDP load-characterisation tool for the UNMODIFIED v0.7 Board B.

This is a HOST-DRIVEN open-loop sender/receiver, not an FPGA packet generator.
Packets contain one constant-price valid BID update, making each expected
report independent of which earlier packets the single-mailbox endpoint dropped.

The script measures per-sequence reception/correctness and host-observed timing;
loss may include Windows/NIC/kernel loss as well as FPGA loss. The FPGA's UDP
TX retains the v0.7 semantics and sends to broadcast 192.168.77.255:5001.

IMPORTANT: reset BTN0 on Board B, confirm PHY link UP, and reconnect the TP-Link
UE300C directly to Board B (NOT the FPGA-to-FPGA cable) for this test.
"""
from __future__ import annotations
import argparse
import csv
import json
import socket
import statistics
import struct
import sys
import threading
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'software'))
from model import encode

FPGA_IP = '192.168.77.2'
FPGA_SOURCE_PORT = 5000
REPLY_PORT = 5001
REQUEST_PORT = 5000
BID_PRICE = 10000


def payload(sequence: int) -> bytes:
    """Use a constant-price bid: accepted responses don't depend on prior loss."""
    if not 1 <= sequence <= 0xffffffff:
        raise ValueError('sequence must be 1..2^32-1')
    return encode('B', 1, sequence, BID_PRICE, 1)


def expected_reply(sequence: int) -> bytes:
    return b'R' + struct.pack('!III', sequence, BID_PRICE, 0) + b'\x00'


@dataclass(frozen=True)
class RxEvent:
    received_ns: int
    value: bytes
    peer: tuple[str, int]


def classify_events(sequences: list[int], events: list[RxEvent],
                    expected_ip: str = FPGA_IP) -> tuple[dict[int, RxEvent], dict]:
    """Correlate by echoed 32-bit sequence; detect errors without guessing cause."""
    wanted = set(sequences)
    correct = {}
    unexpected = []
    corrupt = []
    duplicates = []
    for event in events:
        if event.peer != (expected_ip, FPGA_SOURCE_PORT):
            unexpected.append(('unexpected_source', event))
            continue
        if len(event.value) != 14 or event.value[:1] != b'R':
            corrupt.append(('invalid_format', event))
            continue
        sequence = int.from_bytes(event.value[1:5], 'big')
        if sequence not in wanted:
            unexpected.append(('stale_or_unrequested_seq', event))
            continue
        if event.value != expected_reply(sequence):
            corrupt.append(('wrong_payload', event))
            continue
        if sequence in correct:
            duplicates.append(event)
            continue
        correct[sequence] = event
    errors = dict(
        missing=[s for s in sequences if s not in correct],
        unexpected=unexpected,
        corrupt=corrupt,
        duplicates=duplicates,
    )
    return correct, errors


def percentile(values: list[float], q: float) -> float | None:
    if not values:
        return None
    vals = sorted(values)
    position = (len(vals) - 1) * q
    low = int(position)
    high = min(low + 1, len(vals) - 1)
    fraction = position - low
    return vals[low] * (1 - fraction) + vals[high] * fraction


def file_summary(out_path: Path, count: int, gap_ms: float,
                 sequences: list[int], tx_before: dict[int, int],
                 tx_after: dict[int, int], events: list[RxEvent],
                 source_ip: str, send_failures: dict[int, str]) -> dict:
    correct, errors = classify_events(sequences, events)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    fields = ['sequence','input_hex','expected_hex','sent','send_error',
              'received_valid','received_hex','host_rtt_us','tx_send_ns','rx_receive_ns']
    with out_path.open('w', newline='', encoding='utf-8') as fd:
        writer = csv.DictWriter(fd, fieldnames=fields)
        writer.writeheader()
        for s in sequences:
            hit = correct.get(s)
            sent = s in tx_before and s not in send_failures
            writer.writerow(dict(sequence=s, input_hex=payload(s).hex(),
                expected_hex=expected_reply(s).hex(), sent=int(sent),
                send_error=send_failures.get(s, ''),
                received_valid=int(hit is not None),
                received_hex=hit.value.hex() if hit else '',
                host_rtt_us=f'{(hit.received_ns-tx_before[s])/1000:.3f}'
                       if hit and s in tx_before else '',
                tx_send_ns=tx_before.get(s, ''),
                rx_receive_ns=hit.received_ns if hit else ''))
    tx_sequences = [s for s in sequences if s in tx_before and s not in send_failures]
    host_rtts = [(correct[s].received_ns - tx_before[s]) / 1000
                 for s in tx_sequences if s in correct]
    send_gaps = [(tx_before[b] - tx_before[a]) / 1000
                 for a, b in zip(tx_sequences, tx_sequences[1:])]
    send_span = (tx_after[tx_sequences[-1]] - tx_before[tx_sequences[0]]) / 1000\
                if tx_sequences else 0
    attempted_rate = (len(tx_sequences)-1) * 1_000_000 / send_span \
                     if send_span > 0 and len(tx_sequences) > 1 else None
    summary = {
        'tool': 'm4a_burst_probe_v1',
        'captured_utc': datetime.now(timezone.utc).isoformat(),
        'fpga_source': f'{FPGA_IP}:{FPGA_SOURCE_PORT}',
        'host_interface_ip': source_ip,
        'udp_reply_port': REPLY_PORT,
        'nominal_link_mbps': 100,
        'count_requested': count,
        'requested_send_gap_ms': gap_ms,
        'sent_count': len(tx_sequences),
        'send_errors': len(send_failures),
        'valid_response_count': len(correct),
        'missing_response_count': len(errors['missing']),
        'unexpected_response_count': len(errors['unexpected']),
        'corrupt_response_count': len(errors['corrupt']),
        'duplicate_response_count': len(errors['duplicates']),
        'valid_delivery_percent': round(100 * len(correct) / max(len(tx_sequences),1),3),
        'observed_host_send_span_us': round(send_span,3),
        'observed_host_send_rate_packets_s': round(attempted_rate,1) if attempted_rate is not None else None,
        'observed_send_gap_us': dict(min=min(send_gaps), median=statistics.median(send_gaps),
            p95=percentile(send_gaps,.95), max=max(send_gaps)) if send_gaps else None,
        'host_observed_rtt_us': dict(min=min(host_rtts), median=statistics.median(host_rtts),
            p95=percentile(host_rtts,.95),max=max(host_rtts)) if host_rtts else None,
        'measurement_limits': ('Open-loop Windows/Python/USB-Ethernet test. '
           'Dropped packets may be lost on host/NIC/PHY/FPGA. Host RTT is NOT '
           'FPGA-only latency. Offered rate is an OS-side measurement, not '
           'validated Ethernet wire-rate or FPGA maximum throughput.')
    }
    summary_path = out_path.with_suffix('.summary.json')
    summary_path.write_text(json.dumps(summary, indent=2) + '\n', encoding='utf-8')
    return summary


def run() -> None:
    ap = argparse.ArgumentParser(description=__doc__,formatter_class=argparse.RawTextHelpFormatter)
    ap.add_argument('--pc-ip', default='192.168.77.1', help='IPv4 assigned to TP-Link USB-C Ethernet adapter')
    ap.add_argument('--broadcast', default='192.168.77.255')
    ap.add_argument('--count', type=int, default=200)
    ap.add_argument('--gap-ms', type=float, default=5.0,
                    help='Host-side spacing between sends. 0 = no deliberate sleeps.')
    ap.add_argument('--drain-s', type=float, default=2.0,
                    help='Collect replies after last send for this many seconds.')
    ap.add_argument('--start-seq', type=int, default=None,
                    help='First unique record sequence; default randomised per launch')
    ap.add_argument('--csv', type=Path, default=Path('build/hardware/m4a_burst_probe.csv'))
    ap.add_argument('--require-all', action='store_true',
                    help='Exit nonzero if any missing, corrupt, unexpected or duplicate replies.')
    args = ap.parse_args()
    if args.count < 1 or args.count > 20000:
        ap.error('count must be 1..20000')
    if args.gap_ms < 0 or args.drain_s < 0.05 or args.drain_s > 60:
        ap.error('gap-ms must be >=0 and drain-s must be between 0.05 and 60')
    start = args.start_seq if args.start_seq is not None else ((time.time_ns() & 0x7fffffff) + 1)
    if start < 1 or start + args.count - 1 > 0xffffffff:
        ap.error('invalid start-seq/count combination')
    sequences = list(range(start, start + args.count))
    received = []
    stop = threading.Event()
    ready = threading.Event()
    send_failures = {}
    tx_before, tx_after = {}, {}

    print('IMPORTANT: UNMODIFIED v0.7 Board B. Wire UE300C <-> Board B directly,')
    print('set TP-Link interface to 192.168.77.1/24, reset BTN0 on Board B,')
    print('confirm 100 Mbps Ethernet link, and do NOT run m3_dual_board_test simultaneously.')
    print(f'M4A host open-loop test: count={args.count}, gap_ms={args.gap_ms},'
          f' start_seq={start}; 192.168.77.255:5000 -> {args.pc_ip}:5001')

    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as rx, \
         socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as tx:
        rx.setsockopt(socket.SOL_SOCKET, socket.SO_RCVBUF, 1024 * 1024)
        rx.bind(('0.0.0.0', REPLY_PORT))
        rx.settimeout(.05)
        tx.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        tx.bind((args.pc_ip, 0))  # fail early unless correct wired static IP is configured

        def receive_worker():
            ready.set()
            while not stop.is_set():
                try:
                    data, peer = rx.recvfrom(2048)
                except socket.timeout:
                    continue
                except OSError:
                    break
                received.append(RxEvent(time.perf_counter_ns(), data, peer))

        worker = threading.Thread(target=receive_worker, name='udp-response-capture', daemon=True)
        worker.start()
        ready.wait(1)
        for idx, seq in enumerate(sequences, 1):
            try:
                tx_before[seq] = time.perf_counter_ns()
                sent_bytes = tx.sendto(payload(seq), (args.broadcast, REQUEST_PORT))
                tx_after[seq] = time.perf_counter_ns()
                if sent_bytes != 16:
                    send_failures[seq] = f'short send {sent_bytes}'
            except OSError as exc:
                tx_after[seq] = time.perf_counter_ns()
                send_failures[seq] = repr(exc)
            if args.gap_ms and idx < args.count:
                time.sleep(args.gap_ms / 1000)
            if idx == 1 or idx % 50 == 0 or idx == args.count:
                print(f'Sent {idx}/{args.count} UDP records')
        time.sleep(args.drain_s)
        stop.set()
        worker.join(timeout=1.0)

    summary = file_summary(args.csv, args.count, args.gap_ms, sequences,
                           tx_before, tx_after, received, args.pc_ip, send_failures)
    print(f"RESULT: sent={summary['sent_count']}, valid UDP replies={summary['valid_response_count']}, "
          f"missing={summary['missing_response_count']}, "
          f"corrupt={summary['corrupt_response_count']}, "
          f"duplicates={summary['duplicate_response_count']}, "
          f"unexpected={summary['unexpected_response_count']}")
    print(f"Observed host send rate: {summary['observed_host_send_rate_packets_s']} packets/s "
          f"(not a PHY line-rate measurement)")
    print(f'CSV: {args.csv}; Summary: {args.csv.with_suffix(".summary.json")}')
    print('Do not interpret losses as FPGA-only losses or host RTT as FPGA processing time.')
    if args.require_all and (summary['valid_response_count'] != summary['sent_count'] or
          summary['send_errors'] or summary['unexpected_response_count'] or
          summary['corrupt_response_count'] or summary['duplicate_response_count']):
        raise SystemExit(2)


if __name__ == '__main__':
    run()
