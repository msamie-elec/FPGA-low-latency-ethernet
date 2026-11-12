"""Independent Python byte-vector oracle for fixed synthetic M2C Ethernet frames.

Both Arty boards use broadcast destination MAC/IP; no switch or ARP required.
The example generator is intentionally a narrow laboratory protocol, not a MAC.
"""
from __future__ import annotations

import ipaddress
import struct
import zlib
from pathlib import Path


MAC_BROADCAST = b'\xff' * 6
SOURCE_A = b'\x02\x11\x22\x33\x44\x66'
SOURCE_B = b'\x02\x11\x22\x33\x44\x55'
PREAMBLE = b'\x55' * 7 + b'\xd5'


def ipv4_checksum(data: bytes) -> int:
    if len(data) % 2:
        data += b'\x00'
    total = sum(int.from_bytes(data[i:i + 2], 'big') for i in range(0, len(data), 2))
    while total >> 16:
        total = (total & 0xffff) + (total >> 16)
    return (~total) & 0xffff


def build_frame(payload: bytes, *, from_a: bool) -> bytes:
    """Build preamble + 60-byte minimum Ethernet frame + 4-byte FCS."""
    if from_a and len(payload) != 16:
        raise ValueError('A requests must contain 16 feed bytes')
    if not from_a and len(payload) not in (1, 14):
        raise ValueError('B replies must contain 1 or 14 bytes')
    src_ip = ipaddress.IPv4Address('192.168.77.3' if from_a else '192.168.77.2').packed
    dst_ip = ipaddress.IPv4Address('192.168.77.255').packed
    ip = bytearray(struct.pack('!BBHHHBBH4s4s', 0x45, 0, 28 + len(payload),
                               0x42, 0, 64, 17, 0, src_ip, dst_ip))
    ip[10:12] = struct.pack('!H', ipv4_checksum(ip))
    udp = struct.pack('!HHHH', 5002 if from_a else 5000,
                      5000 if from_a else 5001, 8 + len(payload), 0)
    eth = (MAC_BROADCAST + (SOURCE_A if from_a else SOURCE_B) + b'\x08\x00'
           + ip + udp + payload)
    eth = eth.ljust(60, b'\x00')
    return PREAMBLE + eth + struct.pack('<I', zlib.crc32(eth))


def record_for_command(command: str, seq: int) -> bytes:
    if command not in 'SIE':
        raise ValueError(command)
    kind = ord('X' if command == 'E' else ('B' if seq & 1 else 'A'))
    symbol = 2 if command == 'I' else 1
    price = 10000 + (seq & 15)
    return (bytes([kind, symbol]) + struct.pack('!III', seq, price, 1)
            + b'\x00\x00')


def report_payload(seq: int = 1, bid: int = 10000, ask: int = 0, signal: int = 0) -> bytes:
    return b'R' + struct.pack('!III', seq, bid, ask) + bytes([signal])


def write_vectors(root: Path) -> None:
    generated = root / 'tests' / 'generated'
    generated.mkdir(parents=True, exist_ok=True)
    examples = {
        'm2c_a_standard.hex': build_frame(record_for_command('S', 1), from_a=True),
        'm2c_a_ignored.hex': build_frame(record_for_command('I', 2), from_a=True),
        'm2c_a_error.hex': build_frame(record_for_command('E', 3), from_a=True),
        'm2c_b_report.hex': build_frame(report_payload(), from_a=False),
        'm2c_b_ignored.hex': build_frame(b'I', from_a=False),
        'm2c_b_error.hex': build_frame(b'E', from_a=False),
    }
    bad = bytearray(examples['m2c_b_report.hex'])
    bad[-1] ^= 1
    examples['m2c_b_bad_fcs.hex'] = bytes(bad)
    for filename, raw in examples.items():
        (generated / filename).write_text(''.join(f'{b:02x}\n' for b in raw))
    print('PASS generated', len(examples), 'independent 72-byte MII byte vectors')


if __name__ == '__main__':
    write_vectors(Path(__file__).resolve().parents[1])
