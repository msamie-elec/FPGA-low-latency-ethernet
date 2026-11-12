#!/usr/bin/env python3
"""Deterministic Ethernet MII validation frames (preamble + MAC frame + FCS)."""
import binascii
import ipaddress
import struct
from pathlib import Path
import sys
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'software'))
from model import encode


RECORDS = [encode('B', 1, 1, 10000, 5), encode('A', 1, 2, 10003, 8)]


def ip_checksum(data: bytes):
    assert len(data) % 2 == 0
    acc = sum(int.from_bytes(data[i:i + 2], 'big') for i in range(0, len(data), 2))
    while acc >> 16:
        acc = (acc & 0xffff) + (acc >> 16)
    return (~acc) & 0xffff


def ethernet_frame(payload: bytes, dest_port: int = 5000):
    if len(payload) != 16:
        raise ValueError('exactly 16 bytes per UDP payload')
    src = ipaddress.IPv4Address('192.168.77.1').packed
    dst = ipaddress.IPv4Address('192.168.77.255').packed
    header = bytearray(struct.pack('!BBHHHBBH4s4s', 0x45, 0, 44, 0x1234, 0, 64, 17, 0, src, dst))
    header[10:12] = ip_checksum(header).to_bytes(2, 'big')
    udp = struct.pack('!HHHH', 40000, dest_port, 24, 0) + payload
    eth = b'\xff' * 6 + b'\x02\x12\x34\x56\x78\x9a' + b'\x08\x00'
    mac = (eth + header + udp).ljust(60, b'\x00')
    return mac + struct.pack('<I', binascii.crc32(mac))


def mii_frame(payload: bytes, dest_port: int = 5000):
    return b'\x55' * 7 + b'\xd5' + ethernet_frame(payload, dest_port)


def generate(root: Path):
    out = root / 'tests' / 'generated'
    out.mkdir(parents=True, exist_ok=True)
    vectors = {
        'mii_bid.hex': mii_frame(RECORDS[0]),
        'mii_ask.hex': mii_frame(RECORDS[1]),
        'mii_bad_fcs.hex': mii_frame(RECORDS[0])[:-1] + b'\x00',
        'mii_wrong_port.hex': mii_frame(RECORDS[0], 5001),
    }
    for name, frame in vectors.items():
        (out / name).write_text(''.join(f'{byte:02x}\n' for byte in frame))
    return vectors


if __name__ == '__main__':
    for name, data in generate(Path(__file__).resolve().parents[1]).items():
        print(f'{name}: {len(data)} bytes; final FCS {data[-4:].hex()}')
