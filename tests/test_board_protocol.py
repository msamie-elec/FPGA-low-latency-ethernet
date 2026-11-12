"""Host-wire expected messages, independent of an actual hardware connection."""
from pathlib import Path
import sys
ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from uart_board_test import samples, expected_response
sys.path.insert(0,str(ROOT/'software'))
from model import TopOfBook, encode


def test_uart_expected_samples():
    book=TopOfBook()
    responses=[expected_response(r,book) for r in samples()]
    assert len(responses)==10
    assert responses[0]==bytes.fromhex('52 00000001 00002710 00000000 00')
    assert responses[1]==bytes.fromhex('52 00000002 00002710 00002713 01')
    assert responses[3]==b'I'
    assert responses[4]==b'I'
    assert responses[-1]==b'E'
    assert len([r for r in responses if r.startswith(b'R')])==7


def test_spread_boundary_crossed_and_reset():
    book=TopOfBook()
    assert expected_response(encode('B',1,11,0,1),book).endswith(b'\x00')
    assert expected_response(encode('A',1,12,5,1),book).endswith(b'\x01')
    assert expected_response(encode('A',1,13,6,1),book).endswith(b'\x00')
    assert expected_response(encode('A',1,14,0,1),book).endswith(b'\x00')
    # The next model is a power/reset event with empty book state.
    fresh=TopOfBook()
    assert expected_response(encode('A',1,15,5,1),fresh).endswith(b'\x00')
