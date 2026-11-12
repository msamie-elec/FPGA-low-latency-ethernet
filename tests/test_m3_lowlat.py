from pathlib import Path
import csv, hashlib

ROOT=Path(__file__).resolve().parents[1]

def test_board_b_original_frozen():
    orig=(ROOT/'rtl/ethernet_udp_a7.sv').read_bytes()
    assert hashlib.sha256(orig).hexdigest()=='578e53275f7a15a55f27ee61f91ea2721ee92728f3abf4811f69e93edd4264cd'

def test_new_endpoint_and_parallel_fsm():
    rtl=(ROOT/'rtl/ethernet_udp_a7_lowlat.sv').read_text()
    assert 'module ethernet_udp_a7_lowlat' in rtl
    assert rtl.count('tx_req_toggle <= ~tx_req_toggle;')==3
    assert rtl.count('uart_start_toggle <= ~uart_start_toggle;')==3
    assert 'WAIT_OUTPUTS' in rtl and 'UART_WAIT_BUSY' in rtl
    assert 'tx_ack_sync == tx_req_toggle' in rtl and 'uart_done_toggle == uart_start_toggle' in rtl
    assert 'rx_ack_toggle <= req_sync;' in rtl

def test_new_endpoint_unchanged_constraints():
    a=(ROOT/'boards/arty_a7/ethernet_m2c_endpoint.xdc').read_bytes()
    b=(ROOT/'boards/arty_a7/ethernet_m3_endpoint.xdc').read_bytes()
    assert a==b

def test_latency_regression_bench_present():
    bench=(ROOT/'tb/tb_m3_board_pair.sv').read_text()
    assert "rtt >= 32'd25000" in bench
    assert 'board_b.uart_done_toggle === board_b.uart_start_toggle' in bench

def test_baseline_is_200_passed_physical_records():
    with (ROOT/'docs/baselines/m2c_v06_hardware_rtt_200.csv').open() as fp:
        rows=list(csv.DictReader(fp))
    assert len(rows)==200
    assert all(r['passed']=='True' and r['status']=='P' for r in rows)
    s=[float(r['rtt_us']) for r in rows if r['command']=='S']
    assert 1100 < sum(s)/len(s) < 1300
