#!/usr/bin/env python3
"""M2A v0.4B hardware reliability regression; does not modify FPGA RTL.

Host-paced >10 UDP input records, each compared to an independent Python
TopOfBook oracle on the physically returned USB-UART bytes. This is NOT an
Ethernet throughput benchmark. The M2A receiver has only a one-entry mailbox.
Press/release BTN0 before EACH fresh invocation to reset FPGA book state.
"""
import argparse
import csv
import random
import socket
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]/'software'))
from model import encode, TopOfBook
try:
    from .uart_board_test import samples, expected_response
except ImportError:
    from uart_board_test import samples, expected_response


def make_records(count: int, seed: int) -> list[bytes]:
    if count < 1:
        raise ValueError('count must be positive')
    items = samples()[:min(count, 10)]
    rng = random.Random(seed)
    for seq in range(11, count + 1):
        side = rng.choice(('A', 'B'))
        symbol = 2 if seq % 19 == 0 else 1
        quantity = 0 if seq % 23 == 0 else rng.randint(1, 30)
        reserved = b'\x01\x00' if seq % 29 == 0 else b'\x00\x00'
        record = encode(side, symbol, seq, rng.randint(9900, 10100),quantity,reserved)
        if seq % 31 == 0:
            record=b'X'+record[1:]
        items.append(record)
    return items


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--com', default='COM4')
    p.add_argument('--pc-ip',default='192.168.77.1')
    p.add_argument('--broadcast',default='192.168.77.255')
    p.add_argument('--count', type=int, default=200)
    p.add_argument('--seed',type=int,default=20261111)
    p.add_argument('--gap-ms',type=float,default=5.0)
    p.add_argument('--timeout',type=float,default=2.0)
    p.add_argument('--baud',type=int,default=115200)
    p.add_argument('--log',default='build/hardware/m2a_reliability.csv')
    args=p.parse_args()
    if not 1 <= args.count <= 20000 or args.gap_ms < 0:
        p.error('count must be 1..20000, gap-ms nonnegative')
    try:
        import serial
    except ImportError:
        p.error('missing pyserial: python -m pip install pyserial')
    records=make_records(args.count,args.seed)
    path=Path(args.log)
    path.parent.mkdir(parents=True,exist_ok=True)
    book=TopOfBook()
    bad=0
    print('IMPORTANT: press and release BTN0 ONCE before starting this script.')
    print(f'M2A host-paced hardware regression: {args.count} records, seed={args.seed}, gap={args.gap_ms}ms')
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as udp:
        udp.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1)
        udp.bind((args.pc_ip,0))
        with serial.Serial(args.com,args.baud,timeout=args.timeout) as uart:
            uart.reset_input_buffer()
            with path.open('w',newline='',encoding='utf-8') as f:
                out=csv.writer(f)
                out.writerow(['index','input_hex','expected_hex','actual_hex','pass','elapsed_ms'])
                for idx,rec in enumerate(records):
                    want=expected_response(rec,book)
                    start=time.perf_counter_ns()
                    udp.sendto(rec,(args.broadcast,5000))
                    got=uart.read(len(want))
                    elapsed=(time.perf_counter_ns()-start)/1e6
                    passed=got==want
                    out.writerow([idx,rec.hex(),want.hex(),got.hex(),int(passed),f'{elapsed:.3f}'])
                    if not passed:
                        bad+=1
                        print(f'FAIL {idx}: want={want.hex()} got={got.hex()}')
                        # STOP on first failure; continued transmission would
                        # desynchronise reference state and obscure root cause.
                        break
                    if (idx+1)%25==0 or idx==0 or idx+1==args.count:
                        print(f'PASS {idx+1}/{args.count}; latest UART={got.hex()}')
                    if args.gap_ms:
                        time.sleep(args.gap_ms/1000)
    if bad:
        print(f'FAIL M2A regression; inspect {path}; press BTN0 before retry')
        raise SystemExit(1)
    print(f'PASS {args.count}/{args.count} Ethernet-to-UART FPGA transactions; log: {path}')
    print('Timing includes Windows/Python and serial transfer; NOT FPGA-only latency.')


if __name__=='__main__':
    main()
