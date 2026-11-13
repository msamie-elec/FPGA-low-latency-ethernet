"""M4C final release host protocol and source-integrity tests."""
from __future__ import annotations
import importlib.util
from pathlib import Path
import struct
import sys

R=Path(__file__).resolve().parents[1]
SCRIPT=R/'scripts/m4c_hardware_benchmark.py'
spec=importlib.util.spec_from_file_location('m4c_hw_bench',SCRIPT)
mod=importlib.util.module_from_spec(spec)
sys.modules[spec.name]=mod
spec.loader.exec_module(mod)


def packet(profile='A', sent=1000, received=1000, duplicates=0, unexpected=0,
           invalid=0, late=0, min_gap=10000, max_gap=10000, span=9990000):
    return struct.pack('>4s9I', b'B'+profile.encode()+b'\x01\x00',
                       sent, received, duplicates, unexpected,invalid, late,
                       min_gap,max_gap,span)


def test_successful_telemetry():
    m=mod.parse_telemetry(packet(), 'A',1000)
    assert m.unique_replies==1000 and m.missing==0
    assert m.observed_request_rate_pps==10000
    assert m.delivery_percent==100


def test_missing_replies():
    m=mod.parse_telemetry(packet(received=982), 'A', 1000)
    assert m.missing==18 and m.delivery_percent==98.2


def test_reject_wrong_header():
    import pytest
    with pytest.raises(ValueError): mod.parse_telemetry(packet('B'),'A',1000)
    with pytest.raises(ValueError): mod.parse_telemetry(packet()[:-1],'A',1000)
    with pytest.raises(ValueError): mod.parse_telemetry(b'X'+packet()[1:],'A',1000)


def test_reject_implausible_telemetry():
    import pytest
    with pytest.raises(ValueError): mod.parse_telemetry(packet(sent=999),'A',1000)
    with pytest.raises(ValueError): mod.parse_telemetry(packet(received=1001),'A',1000)
    with pytest.raises(ValueError): mod.parse_telemetry(packet(min_gap=12000,max_gap=10000),'A',1000)


def test_expected_profiles():
    assert mod.PROFILES=={'A':10000,'B':2000,'C':1000}
    assert struct.calcsize(mod.FORMAT)==40


def test_final_baseline_integrity():
    import hashlib, json
    manifest=json.loads((R/'evidence/FINAL_ACTIVE_SOURCE_SHA256.json').read_text())
    for path,digest in manifest['files'].items():
        assert hashlib.sha256((R/path).read_bytes()).hexdigest()==digest, path


def test_new_sv_ends_in_module():
    s=(R/'rtl/ethernet_generator_a7_m4c.sv').read_text()
    assert s.count('module ethernet_generator_a7_m4c')==1
    assert s.rstrip().endswith('endmodule')
    for keyword in ('uart_rx','uart_tx','mii_feed_tx','mii_reply_rx','seen_reply',
                    'send_span','tx_ack_sync==tx_req_toggle'):
        assert keyword in s
