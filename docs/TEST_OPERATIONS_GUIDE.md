# Hardware and simulation test operations — operator runbook

**Version under test:** Board A M4C v0.9 + Board B M4B v0.8B, two Arty A7-35T boards and a *direct* RJ45 cable. Commands labelled **PowerShell** run in a Windows terminal at the repository root. Commands labelled **Vivado Tcl** run inside the *Vivado Tcl Console*, with the `EthAB.xpr` project open. `READY` is **not a command**: it is typed as an answer to a specific Python test's live prompt.

## Test strategy — what every stage does (and does not) prove

| Gate | Action | Evidence / expected indication | Does **not** prove |
|---|---|---|---|
| Reference tests | Python `pytest` | PASS/FAIL for reference/host scripts | Ethernet hardware behaviour |
| RTL verification | Seven Icarus benches | `PASS final M4B/M4C RTL regression: 7 HDL testbenches` | PHY electrical fidelity |
| Two-board XSim | Simulate `tb_m4c_board_pair` | `PASS tb_m4c_board_pair`, three 8-request profiles | Physical board/wire behaviour |
| FPGA synthesis/route | Build each top with its own XDC | Specific top/XDC, positive constrained setup/hold, zero DRC | Complete CDC/PHY signoff |
| Bitstreams + program | `board_A.bit` onto A; `board_B.bit` onto B | Correct JTAG target, FPGA status Programmed | Loss-free UDP traffic |
| Profile A smoke | 1,000 FPGA-paced requests at 100 µs spacing | 1,000 unique, zero missing/dup/invalid/late | High-rate traffic |
| Profiles B/C | Repeat with 20 µs / 10 µs targets | Per-run counters and FPGA-measured launch rates | Sustained wire line-rate |
| Reset first-vs-warm | BTN0 on **both** then `READY` | Independent first/warm CSV/JSON, first bursts not retried | True power-on reliability |
| True power-cycle | Restore USB, reprogram if JTAG-only, then `READY` | Per-cycle evidence after reconnection | Hardware recovery time without external timestamps |

## 1. Preparation (PowerShell, not Vivado)

Extract the **correct PR branch ZIP** to a short fresh Windows path, such as `C:\FPGA\Net`. Do not mix files from v2, v3, v4 and v5. Open a PowerShell terminal in that root. Ensure Vivado 2025.2.1 is installed; for non-Vivado tests install Python and optional Icarus (`iverilog`, `vvp`).

```powershell
python -m pip install pytest pyserial
python -m serial.tools.list_ports -v
python -m pytest -q tests
python scripts/run_final_rtl.py
```

If `iverilog`/`vvp` are not installed, the second regression reports that dependency; it is not a Vivado synthesis failure. The tool runs seven named benches and generates temporary vectors under `tests/generated` and build products under ignored `build/`.

## 2. Generate ONE Vivado project (Windows)

In Windows Explorer, double-click `vivado/create_project.cmd`. This launches batch project creation, validates the reopened XPR, and opens the Vivado GUI. **Alternative in a Vivado-enabled terminal:**

```bat
vivado -mode batch -source vivado/create_project.tcl
```

Then open `build/v/EthAB/EthAB.xpr` via **Vivado → File → Project → Open**. It is intentionally generated, not committed. This single project holds two **separate** synthesis tops and two alternative XDC sets.

In the **Vivado Tcl Console** (NOT PowerShell), change to your extracted root before sourcing scripts:

```tcl
cd {C:/FPGA/Net}
source vivado/board_config.tcl
fpga_select_board A
report_compile_order -constraints
```

Check that **A.xdc** appears as the effective synthesis **and** implementation constraint. The source file is `boards/arty_a7/ethernet_m4c_generator.xdc`. Do not assume a named constraint set is populated. To switch to B, use `fpga_select_board B` (not the top-module dropdown alone) and check **B.xdc**. Switching *invalidates* prior synthesis/implementation; the helper archives previously completed runs where eligible.

## 3. Simulate both designs together (Vivado GUI + Tcl)

Choose **Flow Navigator → Run Simulation → Run Behavioral Simulation**. The top must be `tb_m4c_board_pair`. In the **Vivado Tcl Console**:

```tcl
source sim/waves/setup_demo.tcl
restart
run all
```

The script creates five waveform groups showing: test control → A-to-B MII request and bytes → B frame validation/response queue → B-to-A MII response and bytes → A sequence scoreboard. It locally saves `sim/waves/dual_board_demo.wcfg`; the source ZIP contains the generator script, **not** a duplicated generated waveform layout. The waveform is useful after `restart; run all`, which records transitions. Look for `all_profiles_pass=1`, the final PASS text, matching request/response sequence numbers and a scoreboard increment. See [waveform interpretation](WAVEFORM_DEMO.md).

## 4. Build two distinct images

**Option A, automated Windows Vivado-enabled shell** (close the GUI project first if it locks generated files):

```bat
vivado -mode batch -source vivado/build_targets.tcl -tclargs both
```

**Option B, interactive Vivado GUI**, from the Tcl Console with the correct repo root:

```tcl
source vivado/board_config.tcl
fpga_select_board A
report_compile_order -constraints
```

Then click **Run Synthesis → Run Implementation → Generate Bitstream**. Check reports; when status says `write_bitstream Complete!`, enter:

```tcl
fpga_archive_current
fpga_select_board B
report_compile_order -constraints
```

Repeat **Run Synthesis → Run Implementation → Generate Bitstream** for B, inspect its reports, then:

```tcl
fpga_archive_current
```

Archival copies a completed bitstream and available reports to:
```text
build/out/A/board_A.bit
build/out/B/board_B.bit
```

Inspect `build_identity.txt` for the correct top and XDC. Check DRC, constrained setup/hold/pulse width and CDC separately. Do not copy old checkpoint files into a freshly generated project or downgrade critical pin/IO DRCs. The source generator will not program either board.

## 5. Connect and program the physical boards (Vivado Hardware Manager)

1. Connect each board's USB to the laptop and **one** RJ45 cable directly between their Ethernet sockets. The laptop is **not** an Ethernet endpoint in this experiment.
2. Open **Vivado → Open Hardware Manager → Open Target → Auto Connect**. Use the board/cable identification and, if needed, USB unplug/replug to distinguish the two JTAG targets; do not assume `xc7a35t_0` identifies A.
3. Right-click the FPGA associated with the physical **traffic generator** → **Program Device** → select **`build/out/A/board_A.bit`**.
4. Program the other physical FPGA, the **endpoint**, with **`build/out/B/board_B.bit`**. Check both show **Programmed**.
5. Press **and release** BTN0 on each board, then confirm PHY link indication. A blinking FPGA heartbeat LED and steady PHY LEDs are **not** proof of UDP delivery. Do not hold BTN0 while testing.
6. In **PowerShell**, determine which COM port is Board A; the user's 13 Nov session had **COM4** for A and COM3 for B, but these numbers may change. The Python host tool talks **only to A's UART** at **115200 baud**.

## 6. Finite benchmark — no interactive READY prompt (PowerShell)

```powershell
python scripts/m4c_hardware_benchmark.py --com COM4 --profile A --repeat 1 --require-all --csv build/hardware/smoke_A.csv
python scripts/m4c_hardware_benchmark.py --com COM4 --profile B --repeat 10 --require-all --csv build/hardware/profile_B_10runs.csv
python scripts/m4c_hardware_benchmark.py --com COM4 --profile C --repeat 10 --require-all --csv build/hardware/profile_C_10runs.csv
```

Use the **actual Board A COM number**, not COM4 blindly. For each command, Board A receives one ASCII A/B/C control character over UART, generates **1,000** requests itself at a nominal interval, checks returned responses and sends the laptop **exactly 40 telemetry bytes**. **No BTN0/READY is typed during normal repetitions.** Profiles A/B/C target **100, 20 and 10 µs** request-launch spacing (10k, 50k and 100k/s). The console reports `sent`, `unique`, `missing`, `dup`, `invalid`, `late`, `delivery` and *FPGA-measured request-launch rate*; separately review `unexpected`, the min/max gaps and the CSV/JSON.

**Important:** The phrase `PASS benchmark acquisition` alone does **not** mean every individual run passed. `--require-all` sets a failure exit status when any observed run has a nonzero missing/duplicate/unexpected/invalid count. Preserve the complete CSV and `.summary.json` even for failures.

## 7. First-burst reset test — interactive READY (PowerShell)

```powershell
python scripts/m4c_cold_start.py --com COM4 --mode reset --profile C --cycles 10 --warm-runs 1
```

The script prints `Cycle 1/10: press/release BTN0 on both boards; wait for PHY link; type READY then Enter to run FIRST burst:`. **Only at that prompt**, press/release BTN0 on **both** boards, wait for link, type the literal `READY` into the **same PowerShell window** and press **Enter**. Python then runs (a) one 1,000-request *first* burst and (b) one *warm* burst automatically. **Do not press BTN0 again between first and warm.** Repeat for each prompted cycle. If the script has ended and PowerShell is showing `PS C:\...>`, typing `READY` will instead produce `CommandNotFoundException`; that is not an FPGA failure.

For the separately scoped **power-cycle-mode** experiment (one operator-confirmed 5-cycle session recorded on 14 Nov 2026; repeat as needed):

```powershell
python scripts/m4c_cold_start.py --com COM4 --mode power-cycle --profile C --cycles 5 --warm-runs 1
```

Here remove/restore **both USB power supplies** at each prompt. JTAG-programmed SRAM FPGAs may lose configuration: **reprogram both bitstreams**, verify link and COM, *then* type READY. Do not call BTN0 resets electrical power cycles. The utility is not a stopwatch for power-on-to-link, nor a PHY timestamping instrument.

## 8. Evidence preservation and troubleshooting

- Each cold-start invocation creates a **new** `build/hardware/cold_start/cold_start_<UTC stamp>/` folder with `results.csv` and `summary.json` (including failures/partial UART replies). Do **not** overwrite or delete earlier failed trials.
- Benchmark outputs default to `build/hardware/m4c_hardware_benchmark.csv`; use **distinct** `--csv` names per experiment to avoid overwrites. Each gets a `.summary.json`.
- **0 UART bytes:** Check actual COM mapping, that **Board A's v0.9 bitstream** is programmed, BTN0 released, USB cable and UART driver; only then investigate PHY/packet behaviour.
- **Ethernet LED on but no replies:** A PHY link can exist without a valid UDP exchange. Confirm A and B roles, images, RJ45, and B reset.
- **Some missing replies:** Check first-vs-warm pattern, stale UART bytes and timing/overflow assumptions. No Board B FIFO diagnostic counters are exposed in this hardware telemetry.
- **Vivado `set_property expects at least one object`:** Inspect the selected XDC, top and the line referenced. This happened when an invalid/nonmatching XDC was evaluated; do not ignore it.
- **Vivado warning about reused incremental checkpoint:** Disable incremental synthesis across the two *different* tops; do not reuse an A DCP for B.
- **Simulation waveform has no data:** Restart, rerun and ensure `tb_m4c_board_pair` and updated testbench signal names are loaded.
- **Generated bitstream missing in archive:** Check `get_property STATUS [get_runs impl_1]`, `build_identity.txt`, run errors and whether `fpga_archive_current` was called.

**Folder convention:** `tests/` holds executable automated test *definitions* and mocks; `tb/` holds HDL testbenches; `scripts/` holds operators and runners such as `m4c_cold_start.py`; **`build/hardware/` contains generated local results**, not source tests; curated, reviewed immutable copies of selected runs live in [`evidence/hardware/`](../evidence/hardware/README.md). This prevents output files from cluttering test code or being accidentally overwritten. For release documentation, copy sanitised new CSV/JSON into `evidence/` only after reviewing metadata and permission to publish. Keep `build/`, `*.bit`, generated reports and local COM/JTAG identifiers out of the curated GitHub ZIP. See [results](VERIFICATION_AND_PERFORMANCE_V1.md), [constraints](XDC_AND_IO_REFERENCE.md) and [limitations](LIMITATIONS_V1.md).
