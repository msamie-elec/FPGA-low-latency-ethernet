#!/usr/bin/env python3
"""v0.5 M2B candidate hardware acceptance: UDP request -> FPGA -> UDP+UART.

The FPGA transmits broadcast IPv4 UDP replies from 192.168.77.2:5000 to
192.168.77.255:5001. Python binds specifically to the wired adapter
192.168.77.1:5001 and verifies exact response bytes vs independent oracle.
UART remains checked as a safety regression of the v0.4B path.
Not compatible with a v0.4B bitstream (which has no Ethernet transmitter).
"""
import argparse
import socket
import sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'software'))
from model import TopOfBook
try:
    from .uart_board_test import samples, expected_response
except ImportError:
    from uart_board_test import samples, expected_response


def main():
    a=argparse.ArgumentParser(description=__doc__)
    a.add_argument('--com',default='COM4')
    a.add_argument('--pc-ip',default='192.168.77.1')
    a.add_argument('--broadcast',default='192.168.77.255')
    a.add_argument('--count',type=int,default=10)
    a.add_argument('--timeout',type=float,default=3.0)
    a.add_argument('--baud',type=int,default=115200)
    args=a.parse_args()
    if not 1 <= args.count <= 10:
        a.error('count must be 1..10')
    try:
        import serial
    except ImportError:
        a.error('missing pyserial: python -m pip install pyserial')
    model=TopOfBook()
    with socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as replies,\
         socket.socket(socket.AF_INET,socket.SOCK_DGRAM) as requests:
        # A directed-broadcast packet has destination 192.168.77.255,
        # not the unicast interface address. Bind wildcard to receive it;
        # filter the expected FPGA source address below.
        replies.bind(('0.0.0.0',5001))
        replies.settimeout(args.timeout)
        requests.setsockopt(socket.SOL_SOCKET,socket.SO_BROADCAST,1)
        requests.bind((args.pc_ip,0))
        with serial.Serial(args.com,args.baud,timeout=args.timeout) as uart:
            uart.reset_input_buffer()
            print(f'M2B FPGA Ethernet reply target {args.pc_ip}:5001; UART {args.com}')
            print('Use ONLY with v0.5 bitstream. Press/release BTN0 before launch.')
            for i,record in enumerate(samples()[:args.count]):
                want=expected_response(record,model)
                requests.sendto(record,(args.broadcast,5000))
                uart_bytes=uart.read(len(want))
                udp_bytes,remote=replies.recvfrom(2048)
                if uart_bytes!=want or udp_bytes!=want:
                    raise RuntimeError(f'FAIL {i}: expected={want.hex()} uart={uart_bytes.hex()} udp={udp_bytes.hex()} peer={remote}')
                if remote[0]!='192.168.77.2' or remote[1]!=5000:
                    raise RuntimeError(f'FAIL {i}: unexpected Ethernet source {remote}')
                print(f'PASS packet {i:02d}: UDP+UART={want.hex()} from {remote}')
    print(f'PASS {args.count}/{args.count} v0.5 bidirectional Ethernet packets with matching UART mirror')


if __name__=='__main__':
    main()
