"""M2C software-level independent frame and telemetry checks."""
from __future__ import annotations

import sys
import zlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
sys.path.insert(0,str(ROOT/'software'))
from m2c_vectors import (build_frame,record_for_command,report_payload,
                         ipv4_checksum,write_vectors)
from m2c_dual_board_test import expected_response,commands,parse_telemetry
from model import TopOfBook


def test_m2c_packets_have_72_bytes_crc_and_correct_headers():
    for source in (True,False):
        payloads=[record_for_command('S',1),record_for_command('I',2),record_for_command('E',3)] if source else [report_payload(),b'I',b'E']
        for payload in payloads:
            pkt=build_frame(payload,from_a=source)
            assert len(pkt)==72
            assert pkt[:8]==b'\x55'*7+b'\xd5'
            assert pkt[8:14]==b'\xff'*6
            assert pkt[20:22]==b'\x08\x00'
            assert pkt[22]==0x45
            assert pkt[24:26]==(28+len(payload)).to_bytes(2,'big')
            assert ipv4_checksum(pkt[22:42])==0
            assert pkt[34:38]==bytes([192,168,77,3 if source else 2])
            assert pkt[38:42]==bytes([192,168,77,255])
            assert int.from_bytes(pkt[42:44],'big')==(5002 if source else 5000)
            assert int.from_bytes(pkt[44:46],'big')==(5000 if source else 5001)
            assert pkt[46:48]==(8+len(payload)).to_bytes(2,'big')
            assert pkt[50:50+len(payload)]==payload
            assert pkt[-4:]==zlib.crc32(pkt[8:-4]).to_bytes(4,'little')


def test_m2c_oracle_matches_existing_b_reply_vectors():
    for file,payload in [('mii_tx_report.hex',report_payload()),
                         ('mii_tx_ignored.hex',b'I'),
                         ('mii_tx_error.hex',b'E')]:
        existing=bytes.fromhex((ROOT/'tests/generated'/file).read_text())
        assert existing==build_frame(payload,from_a=False)


def test_m2c_generated_vectors():
    write_vectors(ROOT)
    for p in (ROOT/'tests/generated').glob('m2c_*.hex'):
        assert len(bytes.fromhex(p.read_text()))==72


def test_m2c_expected_responses_mixed_200_records():
    book=TopOfBook()
    replies=[expected_response(book,cmd,i) for i,cmd in enumerate(commands(200,'mixed'),1)]
    assert len(replies)==200
    assert all(r[0] in (ord('R'),ord('I'),ord('E')) for r in replies)
    assert any(r==b'E' for r in replies)
    assert any(r==b'I' for r in replies)
    assert any(r.startswith(b'R') for r in replies)
    assert all(len(r)==14 if r.startswith(b'R') else len(r)==1 for r in replies)


def test_m2c_telemetry_frame_parser():
    response=report_payload()
    buf=b'M'+(1).to_bytes(4,'big')+b'P'+response+(123456).to_bytes(4,'big')
    seq,status,data,cycles=parse_telemetry(buf)
    assert seq==1 and status=='P' and data==response and cycles==123456
    assert cycles/100==1234.56


def test_m2c_vectors_bad_fcs():
    ok=build_frame(report_payload(),from_a=False)
    bad=bytearray(ok);bad[-1]^=1
    assert bad[:-1]==ok[:-1]
    assert zlib.crc32(bytes(bad[8:-4])).to_bytes(4,'little')!=bad[-4:]
