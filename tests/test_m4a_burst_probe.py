"""Pure software regression of M4A test instrumentation; no physical board required."""
import json
import sys
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from m4a_burst_probe import (payload,expected_reply,RxEvent,classify_events,
                            file_summary,percentile)
from m4a_analyse_probes import consolidate


def ev(seq,ns=2000,ip='192.168.77.2',port=5000):
    return RxEvent(ns,expected_reply(seq),(ip,port))


def test_m4a_record_is_16_bytes_with_constant_bid_price():
    b=payload(123)
    assert len(b)==16
    assert b==b'B\x01'+(123).to_bytes(4,'big')+(10000).to_bytes(4,'big')+(1).to_bytes(4,'big')+b'\0\0'


def test_m4a_reply_bytes():
    assert expected_reply(1).hex()=='5200000001000027100000000000'
    assert len(expected_reply(0xffffffff))==14


def test_m4a_sequence_bounds():
    import pytest
    for x in [0, -1, 0x100000000]:
        with pytest.raises(ValueError): payload(x)


def test_m4a_classify_valid_and_missing():
    good, errors=classify_events([101,102],[ev(101)])
    assert list(good)==[101]
    assert errors['missing']==[102]


def test_m4a_classify_duplicate():
    good, errors=classify_events([4],[ev(4),ev(4,3000)])
    assert len(good)==1 and len(errors['duplicates'])==1


def test_m4a_classify_bad_source():
    good, errors=classify_events([5],[ev(5,ip='127.0.0.1')])
    assert not good and len(errors['unexpected'])==1


def test_m4a_classify_stale_sequence():
    good, errors=classify_events([5],[ev(6)])
    assert not good and errors['unexpected'][0][0]=='stale_or_unrequested_seq'


def test_m4a_classify_corrupt_payload():
    b=bytearray(expected_reply(5));b[7]^=1
    good, errors=classify_events([5],[RxEvent(2000,bytes(b),('192.168.77.2',5000))])
    assert not good and len(errors['corrupt'])==1


def test_m4a_classify_short_reply():
    good, errors=classify_events([5],[RxEvent(2000,b'E',('192.168.77.2',5000))])
    assert not good and errors['corrupt'][0][0]=='invalid_format'


def test_m4a_percentile():
    assert percentile([], .5) is None
    assert percentile([1,3], .5)==2
    assert percentile([1,2,3,4,5], .95)==4.8


def test_m4a_writes_complete_csv_and_summary(tmp_path):
    path=tmp_path/'data.csv'
    summary=file_summary(path,2,0,[41,42],{41:1000,42:1200},
         {41:1100,42:1300},[ev(41,4000)],'192.168.77.1',{})
    assert summary['sent_count']==2
    assert summary['valid_response_count']==1
    assert summary['missing_response_count']==1
    assert 'FPGA-only' in summary['measurement_limits']
    assert path.read_text().count('\n')==3
    assert path.with_suffix('.summary.json').exists()
    mat=consolidate([path.with_suffix('.summary.json')])
    assert len(mat)==1 and mat[0]['delivery_percent']==50


def test_m4a_v07_evidence_preserved():
    import csv
    path=ROOT/'docs/baselines/m3_v07_hardware_rtt_200.csv'
    with path.open(newline='', encoding='utf-8') as fd:
        rows=list(csv.DictReader(fd))
    assert len(rows)==200
    assert all(r['passed']=='True' and r['status']=='P' for r in rows)
    assert [int(r['sequence']) for r in rows]==list(range(1,201))
