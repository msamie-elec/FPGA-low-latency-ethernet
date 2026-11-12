#!/usr/bin/env python3
"""M4B source-integrity and structural precheck (NOT an RTL test)."""
from pathlib import Path
import hashlib, json, re, sys

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT/'docs/baselines/M4A_v07_rtl_xdc_sha256.json'

def run():
    ref=json.loads(BASE.read_text(encoding='utf-8'))['files']
    for name, digest in ref.items():
        p=ROOT/name
        if not p.exists() or hashlib.sha256(p.read_bytes()).hexdigest()!=digest:
            raise AssertionError(f'Original verified v0.7 source changed: {name}')
    print(f'PASS freeze: {len(ref)} original v0.7 RTL/XDC files preserved byte-for-byte')
    files={x:ROOT/x for x in (
        'rtl/m4b_async_fifo.sv','rtl/m4b_sync_fifo.sv',
        'rtl/mii_udp_rx_m4b.sv','rtl/mii_udp_tx_m4b.sv',
        'rtl/ethernet_udp_a7_buffered.sv',
        'boards/arty_a7/ethernet_m4b_endpoint.xdc',
        'scripts/build_m4b_endpoint.tcl',
        'scripts/run_m4b_sim.ps1',
        'tb/tb_m4b_async_fifo.sv','tb/tb_m4b_sync_fifo.sv',
        'tb/tb_m4b_rx_overflow.sv',
        'tb/tb_m4b_endpoint_burst.sv','tb/tb_m4b_board_pair.sv')}
    for name,p in files.items():
        assert p.is_file() and p.stat().st_size>500, f'Missing/incomplete {name}'
    top=files['rtl/ethernet_udp_a7_buffered.sv'].read_text()
    async_fifo=files['rtl/m4b_async_fifo.sv'].read_text()
    sync_fifo=files['rtl/m4b_sync_fifo.sv'].read_text()
    tx=files['rtl/mii_udp_tx_m4b.sv'].read_text()
    rx=files['rtl/mii_udp_rx_m4b.sv'].read_text()
    xdc=files['boards/arty_a7/ethernet_m4b_endpoint.xdc'].read_text()
    assert 'feed_pipeline u_core' in top, 'Original feed_pipeline is not reused'
    assert 'm4b_async_fifo' in top and top.count('m4b_async_fifo #')==2
    assert 'm4b_sync_fifo' in top
    assert '.READ_NEGEDGE(1\'b1)' in top
    assert 'ASYNC_REG' in async_fifo and 'rd_gray_sync' in async_fifo and 'wr_gray_sync' in async_fifo
    assert 'wg_next == rd_gray_full' in async_fifo
    assert 'used == DEPTH' in sync_fifo and 'full || pop' in sync_fifo
    assert 'fifo_full' in rx and 'overflow_count' in rx and 'invalid_frame_count' in rx
    assert 'overflow_gray <=' in rx and 'invalid_frame_gray <=' in rx
    assert 'tx_sent_gray <=' in tx and 'tx_sent_count' in tx
    assert 'debug_uart_drops' in top and 'dbg_push && !dbg_ready' in top
    assert 'send_pending && tx_wr_ready' in top and 'WAIT_PUSH: if(tx_wr_ready)' in top
    assert 'set_output_delay' in xdc and 'set_input_delay' in xdc and 'set_property IOB TRUE' in xdc
    assert 'create_generated_clock' in xdc and 'create_clock -name eth_rx_25mhz' in xdc
    for name in ('RX_DEPTH','TX_DEPTH','UART_DEPTH'):
        assert re.search(r'parameter\s+integer\s+'+name+r'\s*=\s*\d+', top)
    print('PASS new RX/TX Gray-pointer async FIFOs, bounded UART queue, registered Gray counters')
    print('PASS PHY RX/TX timing constraints, IOB placement request, original core reused')
    print('NOTICE: structural checks cannot prove RTL correctness, CDC closure or hardware throughput')

if __name__=='__main__':
    try: run()
    except Exception as exc:
        print('FAIL:',exc,file=sys.stderr);sys.exit(1)
