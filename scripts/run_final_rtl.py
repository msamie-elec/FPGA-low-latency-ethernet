#!/usr/bin/env python3
"""Cross-platform Icarus regression for the FINAL M4B/M4C dual-FPGA design.

Requires iverilog and vvp on PATH. No Vivado or physical boards are needed.
Source lists contain only the final M4B/M4C RTL and independent unit benches.
"""
from __future__ import annotations
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "build" / "final_rtl"
M4B = [
    "rtl/m4b_async_fifo.sv", "rtl/m4b_sync_fifo.sv",
    "rtl/mii_udp_rx_m4b.sv", "rtl/mii_udp_tx_m4b.sv",
    "rtl/feed_parser.sv", "rtl/top_of_book.sv", "rtl/feed_pipeline.sv",
    "rtl/uart_tx.sv", "rtl/ethernet_udp_a7_buffered.sv",
]
M4C = M4B + [
    "rtl/uart_rx.sv", "rtl/mii_feed_tx.sv", "rtl/mii_reply_rx.sv",
    "rtl/ethernet_generator_a7_m4c.sv",
]
TESTS = [
    ("tb_m4b_sync_fifo", ["rtl/m4b_sync_fifo.sv", "tb/tb_m4b_sync_fifo.sv"]),
    ("tb_m4b_async_fifo", ["rtl/m4b_async_fifo.sv", "tb/tb_m4b_async_fifo.sv"]),
    ("tb_m4b_rx_overflow", ["rtl/mii_udp_rx_m4b.sv", "rtl/m4b_async_fifo.sv", "tb/tb_m4b_rx_overflow.sv"]),
    ("tb_m4b_endpoint_burst", M4B + ["rtl/mii_reply_rx.sv", "tb/tb_m4b_endpoint_burst.sv"]),
    ("tb_mii_feed_tx", ["rtl/mii_feed_tx.sv", "tb/tb_mii_feed_tx.sv"]),
    ("tb_mii_reply_rx", ["rtl/mii_reply_rx.sv", "tb/tb_mii_reply_rx.sv"]),
    ("tb_m4c_board_pair", M4C + ["tb/tb_m4c_board_pair.sv"]),
]

def run(command: list[str]) -> None:
    print("> " + " ".join(command), flush=True)
    subprocess.run(command, check=True, cwd=ROOT)

def main() -> int:
    if not shutil.which("iverilog") or not shutil.which("vvp"):
        print("ERROR: install Icarus Verilog (iverilog and vvp).", file=sys.stderr)
        return 2
    OUT.mkdir(parents=True, exist_ok=True)
    try:
        run([sys.executable, "scripts/m2c_vectors.py"])
        run([sys.executable, "scripts/m4b_vectors.py"])
        for name, sources in TESTS:
            missing = [s for s in sources if not (ROOT / s).is_file()]
            if missing:
                raise FileNotFoundError(f"{name}: missing {missing}")
            exe = OUT / (name + ".vvp")
            run(["iverilog", "-g2012", "-s", name, "-o", str(exe)] + sources)
            run(["vvp", str(exe)])
            print(f"PASS {name}", flush=True)
    except (OSError, subprocess.CalledProcessError) as exc:
        print(f"FAIL final RTL regression: {exc}", file=sys.stderr)
        return 1
    print(f"PASS final M4B/M4C RTL regression: {len(TESTS)} HDL testbenches")
    return 0

if __name__ == "__main__":
    sys.exit(main())
