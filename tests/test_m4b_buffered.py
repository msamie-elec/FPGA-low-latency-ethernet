"""M4B software/reference regressions; no claim of RTL simulation."""
from pathlib import Path
import importlib.util
import sys

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/'scripts'))
from m4b_vectors import vectors
from m2c_vectors import build_frame,record_for_command


def test_m4b_vectors_reference_packet_sequence():
    raw,bad=vectors()
    assert len(raw)==72*22 and len(bad)==72
    for n in range(22):
        command='S' if n<20 else ('I' if n==20 else 'E')
        expected=build_frame(record_for_command(command,n+1),from_a=True)
        assert raw[72*n:72*(n+1)]==expected


def test_m4b_corrupt_frame_is_bad_fcs_only():
    _,bad=vectors()
    expected=build_frame(record_for_command('S',23),from_a=True)
    assert bad[:-1]==expected[:-1]
    assert bad[-1]!=expected[-1]


def test_m4b_new_source_set_exists():
    files=['m4b_async_fifo.sv','m4b_sync_fifo.sv','mii_udp_rx_m4b.sv',
           'mii_udp_tx_m4b.sv','ethernet_udp_a7_buffered.sv']
    assert all((ROOT/'rtl'/f).is_file() for f in files)
    assert (ROOT/'vivado'/'create_project.tcl').is_file()
    assert (ROOT/'boards'/'arty_a7'/'ethernet_m4b_endpoint.xdc').is_file()


def test_m4b_queue_depths_are_bounded_and_power_of_two():
    source=(ROOT/'rtl/ethernet_udp_a7_buffered.sv').read_text()
    for token in ['RX_DEPTH=16','TX_DEPTH=16','UART_DEPTH=8']:
        assert token in source


def test_m4b_uart_independence_by_source_handshake():
    src=(ROOT/'rtl/ethernet_udp_a7_buffered.sv').read_text()
    assert 'WAIT_PUSH: if(tx_wr_ready)' in src
    assert 'dbg_push=send_pending && tx_wr_ready' in src
    assert 'dbg_push && !dbg_ready' in src
    assert 'WAIT_OUTPUTS' not in src
