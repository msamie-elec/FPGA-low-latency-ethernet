#!/usr/bin/env python3
"""M2A board test: PC --UDP broadcast--> Arty FPGA --USB UART--> PC.

Requires Python pyserial; Ethernet adapter on dedicated subnet:
  PC IP: 192.168.77.1/24 (configure manually), destination 192.168.77.255:5000
Arty is a passive broadcast listener; NO IP address, ARP or UDP response.
Run only after simulation and Vivado pin/timing checks.
"""
import argparse
import socket
import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'software'))
from model import encode, decode, TopOfBook
from uart_board_test import expected_response, samples


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--com', default='COM4', help='FPGA USB-UART COM port')
    ap.add_argument('--pc-ip', default='192.168.77.1', help='Windows wired Ethernet IPv4 address')
    ap.add_argument('--broadcast', default='192.168.77.255', help='broadcast for that wired network')
    ap.add_argument('--baud', type=int, default=115200)
    ap.add_argument('--timeout', type=float, default=3.0)
    ap.add_argument('--count', type=int, default=10)
    args = ap.parse_args()
    if not 1 <= args.count <= 10:
        ap.error('count must be 1..10')
    try:
        import serial
    except ImportError:
        ap.error('install pyserial: python -m pip install pyserial')
    expected_book = TopOfBook()
    records = samples()[:args.count]
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as udp:
        udp.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        udp.bind((args.pc_ip, 0))  # fails early if wired static IP not configured
        with serial.Serial(args.com, args.baud, timeout=args.timeout) as uart:
            uart.reset_input_buffer()
            print(f'FPGA RX Ethernet broadcast {args.broadcast}:5000; responses on {args.com}')
            print('Press/release BTN0 before launching; check Ethernet jack link LED.')
            for index, record in enumerate(records):
                want = expected_response(record, expected_book)
                udp.sendto(record, (args.broadcast, 5000))
                got = uart.read(len(want))
                if got != want:
                    raise RuntimeError(f'FAILED {index}: expected {want.hex()} got {got.hex()} '
                                       '(check wired network broadcast/PHY clock/LED5 and UART LD7)')
                print(f'PASS ethernet packet {index:02d}: {got.hex()}')
    print(f'PASS {len(records)} Ethernet-to-UART FPGA transactions')


if __name__ == '__main__':
    main()
