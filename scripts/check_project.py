#!/usr/bin/env python3
"""Lightweight wiring/constraints sanity checks; NOT an HDL compiler or lint replacement."""
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[1]
mods={}
for p in (ROOT/'rtl').glob('*.sv'):
    source=re.sub(r'//[^\n]*|/\*.*?\*/','',p.read_text(),flags=re.S)
    for m in re.finditer(r'\bmodule\s+(\w+)\s*(?:#\s*\(.*?\))?\s*\((.*?)\)\s*;',source,re.S):
        name,ports=m.groups()
        mods[name]=(p,{x.group(1) for item in ports.split(',') if (x:=re.search(r'(\w+)\s*$',item.strip()))})
assert 'feed_parser' in mods and 'top_of_book' in mods
for module,path in [('feed_parser','rtl/feed_pipeline.sv'),('top_of_book','rtl/feed_pipeline.sv'),
                    ('feed_pipeline','rtl/board_uart_demo.sv'),('uart_rx','rtl/board_uart_demo.sv'),
                    ('uart_tx','rtl/board_uart_demo.sv')]:
    source=(ROOT/path).read_text()
    pat=rf'\b{module}\b\s*(?:#\s*\(.*?\))?\s+\w+\s*\((.*?)\)\s*;'
    inst=re.search(pat,source,re.S)
    assert inst, f'No {module} instance in {path}'
    connected=set(re.findall(r'\.(\w+)\s*\(',inst.group(1)))
    extras=connected-mods[module][1]
    assert not extras,f'{module} unknown ports: {extras}'
    required=mods[module][1]-connected
    assert not required,f'{module} unconnected ports: {required}'
print('PASS static instance port names')
for board in ('arty_a7','arty_s7'):
    xdc=(ROOT/f'boards/{board}/uart.xdc').read_text()
    for signal in ('clk','btn[0]','led[0]','led[1]','led[2]','led[3]',
                   'uart_rx_i','uart_tx_o'):
        assert f'[get_ports {{{signal}}}]' in xdc or f'[get_ports {signal}]' in xdc,(board,signal)
    assert 'create_clock' in xdc
print('PASS UART board constraints presence')

# Explicit pin-direction regression: simulation alone did NOT catch the old A7
# wiring mistake because testbenches have no notion of physical package pins.
for board, rx_pin, tx_pin in (("arty_a7", "A9", "D10"),
                              ("arty_s7", "V12", "R12")):
    xdc = (ROOT/f"boards/{board}/uart.xdc").read_text()
    for signal, pin in (("uart_rx_i",rx_pin),("uart_tx_o",tx_pin)):
        pattern=rf'PACKAGE_PIN\s+{pin}\s+IOSTANDARD\s+LVCMOS33\s+\}}\s*\[get_ports\s+{signal}\]'
        assert re.search(pattern,xdc), f"{board} {signal} must use {pin}"
for name in ('board_uart_demo', 'board_uart_a7', 'board_uart_s7'):
    assert {'uart_rx_i','uart_tx_o'} <= mods[name][1], (name,mods[name][1])
top=(ROOT/'rtl/board_uart_demo.sv').read_text()
assert '.rx_pin(uart_rx_i)' in top and '.tx_pin(uart_tx_o)' in top
assert 'uart_txd_in' not in top and 'uart_rxd_out' not in top
print('PASS A7/S7 UART physical pin direction and top-level wiring')
