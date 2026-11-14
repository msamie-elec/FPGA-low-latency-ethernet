# Simulation configuration and waveform views

This directory is the **home for Vivado XSim simulation setup and waveform presentation**, not a second copy of the RTL, testbenches or physical hardware tests.

## What lives where?

| Folder | Source of truth | Typical contents |
|---|---|---|
| `rtl/` | Synthesizable logic for Board A and Board B | SystemVerilog design sources |
| `tb/` | HDL stimuli, monitors and assertions | `tb_m4c_board_pair.sv` and other testbenches |
| **`sim/`** | **Simulation configuration and reusable waveform presentation** | `waves/setup_demo.tcl`, explanatory instructions |
| `tests/` | Repeatable automated verification code (host-model, protocol, Tcl-source checks) | Python `test_*.py` and mock Tcl |
| `scripts/` | Runnable test drivers and utilities | `run_final_rtl.py`, `m4c_hardware_benchmark.py`, `m4c_cold_start.py` |
| `build/` | Disposable **generated** results, not source | `build/v/` Vivado XPR/simulation, `build/out/` bitstreams/reports, `build/hardware/` physical CSV/JSON |
| `evidence/` | Reviewed, permanent original test captures | Selected source-verified hardware CSV/JSON, baseline results |

## The waveform directory

- **`sim/waves/setup_demo.tcl` is the canonical *source* script**. It creates a five-group waveform view for the dual-board `tb_m4c_board_pair` simulation. It does not drive inputs or change RTL.
- **`sim/waves/dual_board_demo.wcfg` is generated locally** by that script when executed in Vivado. It is a *saved XSim wave layout*, not a testbench, runtime trace, result or proof. The filename is ignored by Git to avoid committing derivative layout copies. Regenerate it from `setup_demo.tcl` whenever testbench signals or groupings change.
- XSim's actual signal transitions are produced when the simulation runs; the `.wcfg` merely describes how to display them. Generated simulator databases remain under the ignored Vivado `build/` worktree.

## Generate and use the waveform layout

From the repository root, create/open the Vivado project and launch **Behavioral Simulation**, with `tb_m4c_board_pair` as the simulation top. Then type these commands into **Vivado's Tcl Console** (not PowerShell):

```tcl
source sim/waves/setup_demo.tcl
restart
run all
```

The five signal groups display (1) test control/profile results, (2) request A → B, (3) Board B validation/processing, (4) reply B → A, (5) Board A response/scoreboard. Confirm the simulation reports `PASS tb_m4c_board_pair` and `all_profiles_pass=1`; inspect request/response sequence agreement in the wave viewer. For walkthroughs, see [Waveform demo](../docs/WAVEFORM_DEMO.md) and [test operations](../docs/TEST_OPERATIONS_GUIDE.md).

**Avoid duplication:** keep waveform-generation logic only in `sim/waves/setup_demo.tcl`. Generated `.wcfg` files and simulator traces stay local, while curated screenshots/explanations go in `docs/` or `evidence/` where warranted. Physical FPGA benchmark CSV/JSON never belong in `sim/` or `tests/`.
