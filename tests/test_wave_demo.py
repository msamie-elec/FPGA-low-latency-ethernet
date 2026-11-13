"""Verify that the downloadable waveform setup stays in sync with the testbench.

A Tcl-only mock catches layout script syntax/argument regressions. It cannot
replace a real Vivado XSim GUI validation of WCFG rendering and tracing.
"""
from pathlib import Path
import shutil
import subprocess
import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "sim/waves/setup_demo.tcl"
TB = ROOT / "tb/tb_m4c_board_pair.sv"


def test_demo_probes_are_passive_and_have_named_transaction_stages():
    tb = TB.read_text(encoding="utf-8")
    for probe in (
        "a2b_byte_valid", "a2b_payload_byte", "a2b_sequence_valid",
        "b_rx_frame_valid", "b_reply_enqueued",
        "b2a_byte_valid", "b2a_payload_byte", "b2a_sequence_valid",
        "a_reply_staged", "a_staged_reply_seq", "a_unique_replies",
        "profiles_passed", "all_profiles_pass",
    ):
        assert probe in tb
        assert probe in SCRIPT.read_text(encoding="utf-8")
    assert "module mii_demo_byte_monitor" in tb
    assert "all_profiles_pass=1;" in tb
    # The testbench module is in the simulation fileset only, not source RTL.
    gui_tcl = (ROOT / "vivado/create_project.tcl").read_text(encoding="utf-8")
    assert "add_files -norecurse -fileset sim_1 $tb_file" in gui_tcl


def test_demo_wcfg_layout_script_parses_in_tcl_mock(tmp_path):
    if not shutil.which("tclsh"):
        pytest.skip("tclsh missing: CI runs this on Linux")
    # Build a minimal WCFG command mock: just verify Tcl control flow,
    # grouping order, signal path assembly and save destination.
    bootstrap = r"""
set ::groups 0
set ::signals 0
proc create_wave_config {name} {return $name}
proc current_wave_config {name} {return $name}
proc add_wave_group {name} {incr ::groups; return $name}
proc get_objects {args} {
    if {[llength $args] != 2 || [lindex $args 0] ne "-quiet"} {
        error "Unexpected get_objects arguments: $args"
    }
    set path [lindex $args 1]
    if {![string match "/tb_m4c_board_pair/*" $path]} {
        error "Unqualified waveform path: $path"
    }
    return [list $path]
}
proc add_wave {args} {
    if {[lindex $args 0] ne "-into"} {error "Wave omitted group: $args"}
    incr ::signals
}
proc save_wave_config {path} {
    if {[file tail $path] ne "dual_board_demo.wcfg"} {
        error "Unexpected output name: $path"
    }
}
"""
    runner = tmp_path / "mock_waves.tcl"
    runner.write_text(
        bootstrap + "\nsource {" + SCRIPT.as_posix() + "}\n"
        + 'puts "PASS_WAVE_MOCK groups=$::groups signals=$::signals"\n',
        encoding="utf-8",
    )
    proc = subprocess.run(
        ["tclsh", str(runner)],
        cwd=ROOT, text=True, capture_output=True, timeout=15,
    )
    assert proc.returncode == 0, proc.stdout + "\n" + proc.stderr
    assert "PASS_WAVE_MOCK groups=5" in proc.stdout
    assert "signals=" in proc.stdout
