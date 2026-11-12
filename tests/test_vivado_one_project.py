"""Packaging tests; these do NOT establish an AMD Vivado implementation pass."""
from pathlib import Path
import shutil
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[1]

def test_one_xpr_has_both_frozen_tops_and_separate_constraints():
    tcl = (ROOT / "vivado/create_project.tcl").read_text(encoding="utf-8")
    for name in (
        "ethernet_generator_a7_m4c.sv", "ethernet_udp_a7_buffered.sv",
        "mii_feed_tx.sv", "mii_reply_rx.sv", "feed_parser.sv",
        "top_of_book.sv", "feed_pipeline.sv", "m4b_async_fifo.sv",
        "m4b_sync_fifo.sv", "mii_udp_rx_m4b.sv", "mii_udp_tx_m4b.sv",
    ):
        assert name in tcl and (ROOT / "rtl" / name).is_file()
    assert "constrs_board_a" in tcl and "constrs_board_b" in tcl
    assert "tb_m4c_board_pair" in tcl
    assert (ROOT / "boards/arty_a7/ethernet_m4c_generator.xdc").is_file()
    assert (ROOT / "boards/arty_a7/ethernet_m4b_endpoint.xdc").is_file()

def test_board_switch_and_output_preservation_using_tcl_mock():
    if not shutil.which("tclsh"):
        pytest.skip("Tcl interpreter unavailable; real Vivado testing remains pending")
    run = subprocess.run(
        ["tclsh", str(ROOT / "tests/vivado_project_mock.tcl"), str(ROOT)],
        cwd=ROOT, capture_output=True, text=True, timeout=40
    )
    assert run.returncode == 0, run.stdout + "\n" + run.stderr
    assert "PASS: TCL MOCK ONLY" in run.stdout

def test_mii_xdc_uses_supported_commands_and_preserves_port_timing():
    for name in ("ethernet_m4c_generator.xdc", "ethernet_m4b_endpoint.xdc"):
        xdc = (ROOT / "boards" / "arty_a7" / name).read_text(encoding="utf-8")
        assert not any(line.lstrip().startswith("if ") for line in xdc.splitlines())
        assert "set_input_delay -clock" in xdc
        assert "set_output_delay -clock" in xdc
        assert "create_generated_clock" in xdc
        assert "set_property IOB TRUE $mii_tx_ports" in xdc
    assert (ROOT / "vivado/check_mii_ports.tcl").is_file()
    build = (ROOT / "vivado/build_targets.tcl").read_text(encoding="utf-8")
    assert "source [file join $root vivado check_mii_ports.tcl]" in build

