"""Independent wire-level tests for the v0.4A broadcast-MII design."""
import binascii
import struct
import sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
sys.path.insert(0, str(ROOT / 'software'))
from ethernet_vectors import RECORDS, ethernet_frame, generate, ip_checksum, mii_frame
from model import decode, TopOfBook


def test_mii_preamble_fcs_and_padding():
    for record in RECORDS:
        frame = mii_frame(record)
        assert len(frame) == 72
        assert frame[:8] == b'\x55' * 7 + b'\xd5'
        assert frame[8:14] == b'\xff' * 6
        assert frame[20:22] == b'\x08\x00'
        assert frame[50:66] == record
        assert len(frame[8:-4]) == 60
        assert int.from_bytes(frame[-4:], 'little') == binascii.crc32(frame[8:-4])


def test_ipv4_udp_header_and_checksum():
    frame = ethernet_frame(RECORDS[0])
    assert frame[14] == 0x45
    assert ip_checksum(frame[14:34]) == 0
    assert int.from_bytes(frame[16:18], 'big') == 44
    assert frame[23] == 17
    assert int.from_bytes(frame[36:38], 'big') == 5000
    assert int.from_bytes(frame[38:40], 'big') == 24


def test_bad_fcs_and_udp_port():
    correct = ethernet_frame(RECORDS[0]); bad = correct[:-1] + bytes([correct[-1] ^ 0xff])
    assert binascii.crc32(bad[:-4]) != int.from_bytes(bad[-4:], 'little')
    alternate = ethernet_frame(RECORDS[0], 5001)
    assert int.from_bytes(alternate[36:38], 'big') == 5001
    assert binascii.crc32(alternate[:-4]) == int.from_bytes(alternate[-4:], 'little')


def test_reference_decodes_ethernet_payload():
    book = TopOfBook()
    assert book.push(decode(RECORDS[0])) == (1, 10000, 0, 0)
    assert book.push(decode(RECORDS[1])) == (2, 10000, 10003, 1)


def test_generated_simulation_files(tmp_path):
    vectors = generate(tmp_path)
    for filename, packet in vectors.items():
        path = tmp_path / 'tests' / 'generated' / filename
        assert bytes.fromhex(path.read_text()) == packet
