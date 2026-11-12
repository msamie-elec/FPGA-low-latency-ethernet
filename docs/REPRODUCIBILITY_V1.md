# Reproduction guide - two Arty A7-35T boards

## Requirements

- Two Digilent Arty A7-35T FPGAs (exact device/board revision must match constraints), RJ45 Cat5e/Cat6 patch lead, and two separate USB JTAG/UART connections.
- AMD Vivado 2025.2.1, Icarus Verilog (`iverilog`, `vvp`), Python with `pytest` and `pyserial`.
- Windows PowerShell examples below assume a checked-out project root; substitute your own path. Board A/Board B historical COM4/COM3 values are not guaranteed after replugging USB.

## Install and verify from project root

```powershell
python -m pip install pytest pyserial
python -m pytest -q tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\\scripts\\run_m4b_sim.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\\scripts\\run_m4c_sim.ps1"
python scripts/check_m4c_candidate.py
```

The source-freeze checker tracks legacy candidate source integrity and may require its original baseline files; it is not a substitute for complete Vivado functional signoff. The main 52-test Python regression and M4C RTL simulation passed on the Windows reference system before hardware validation.

## Build Board A + Board B independently

```powershell
& "C:\\AMDDesignTools\\2025.2.1\\Vivado\\bin\\vivado.bat" -mode batch -source scripts/build_m4c_generator.tcl
python scripts/audit_m4c_reports.py

& "C:\\AMDDesignTools\\2025.2.1\\Vivado\\bin\\vivado.bat" -mode batch -source scripts/build_m4b_endpoint.tcl
python scripts/audit_m4b_reports.py
```

Do **not** program a board unless the relevant routed timing, CDC and I/O reports have been reviewed and the physical board/bitstream target is confirmed. The previously verified `v0.8B` Board B can be retained unchanged; it need not be rebuilt for the benchmark.

## Hardware

- Confirm the USB-JTAG identity of each physical board, rather than relying on COM numbers alone. In the reference tests Board A was COM4 and Board B was COM3, but these assignments may change after USB reconnection.
- Connect **Board A RJ45 directly to Board B RJ45**. This is not the earlier UE300C host-generated test configuration.
- Program Board A top `ethernet_generator_a7_m4c` and Board B top `ethernet_udp_a7_buffered`.
- Connect both USB cables for power, JTAG and serial. Press and release BTN0 on both, verify physical link, allow stabilisation.

## Run finite benchmark

```powershell
python scripts/m4c_hardware_benchmark.py --com COM4 --profile A --repeat 1 --require-all --csv build/hardware/m4c_smoke.csv
python scripts/m4c_hardware_benchmark.py --com COM4 --profile all --repeat 3 --csv build/hardware/m4c_final_3x3.csv
```

Compare all CSV records with the matching `.summary.json`, including min/max launch gaps, response counts, duplicates, invalid responses and late launches. The exact frozen user-hardware M4C evidence is checked into `evidence/m4c/`, and the aggregated verification outcome is in `evidence/REVIEWED_RESULTS.json`.

The version-specific RTL test benches and build scripts remain in `tb/` and `scripts/`. Build artifacts and bitstreams are not committed. See `docs/LIMITATIONS_V1.md` before reusing any performance numbers.
