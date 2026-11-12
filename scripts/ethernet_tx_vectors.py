#!/usr/bin/env python3
"""Independent Python golden UDP reply MII frame generator (v0.5 M2B).

Generates byte-accurate golden tests including preamble, IP checksum, FCS,
Ethernet minimum-frame padding, for 1-byte and 14-byte response payloads.
"""
from __future__ import annotations
import binascii
import ipaddress
import struct
from pathlib import Path
try:
    from .ethernet_vectors import ip_checksum
except ImportError:
    from ethernet_vectors import ip_checksum

SRC_MAC = bytes.fromhex('021122334455')
SRC_IP = ipaddress.IPv4Address('192.168.77.2')
DST_IP = ipaddress.IPv4Address('192.168.77.255')


def reply_frame(payload: bytes) -> bytes:
    if len(payload) not in (1, 14):
        raise ValueError('reply must be 1 or 14 bytes')
    ip_total = 20 + 8 + len(payload)
    ip_header = bytearray(struct.pack('!BBHHHBBH4s4s',
        0x45, 0, ip_total, 0x0042, 0, 64, 17, 0, SRC_IP.packed, DST_IP.packed))
    ip_header[10:12] = ip_checksum(ip_header).to_bytes(2, 'big')
    udp_header = struct.pack('!HHHH', 5000, 5001, 8 + len(payload), 0)
    mac_frame = (b'\xff'*6 + SRC_MAC + b'\x08\x00' +
                 ip_header + udp_header + payload).ljust(60, b'\x00')
    return b'\x55'*7 + b'\xd5' + mac_frame + struct.pack('<I', binascii.crc32(mac_frame))


def generate(root: Path):
    out = root/'tests'/'generated'
    out.mkdir(parents=True, exist_ok=True)
    payloads = {
        'mii_tx_report.hex': b'R' + struct.pack('!IIIB', 1, 10000, 0, 0),
        'mii_tx_report2.hex': b'R' + struct.pack('!IIIB', 2, 10000, 10003, 1),
        'mii_tx_ignored.hex': b'I',
        'mii_tx_error.hex': b'E',
    }
    for name, payload in payloads.items():
        frame = reply_frame(payload)
        assert len(frame) == 72
        (out/name).write_text(''.join(f'{v:02x}\n' for v in frame), encoding='ascii')
    return payloads


if __name__ == '__main__':
    for name, payload in generate(Path(__file__).resolve().parents[1]).items():
        print(name, 'payload', payload.hex(), 'preamble+frame bytes',len(reply_frame(payload)))
