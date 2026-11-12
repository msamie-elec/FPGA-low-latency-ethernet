from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

def test_bad_meta_only_feeds_second_stage():
    s = (ROOT/'rtl/ethernet_uart_a7.sv').read_text()
    assert 'bad_sync <= bad_meta;' in s
    assert 'if (bad_sync != bad_meta)' not in s
    assert 'if (bad_sync != bad_seen)' in s

def test_phy_input_delays_present():
    x = (ROOT/'boards/arty_a7/ethernet_m2a.xdc').read_text()
    assert 'set_input_delay -clock [get_clocks eth_rx_25mhz] -min 10.000' in x
    assert 'set_input_delay -clock [get_clocks eth_rx_25mhz] -max 30.000' in x

def test_generated_clock_declaration_present():
    x = (ROOT/'boards/arty_a7/ethernet_m2a.xdc').read_text()
    assert 'create_generated_clock -name phy_ref_25mhz' in x
