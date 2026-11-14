# Reproduce the final dual-Arty Ethernet FPGA demonstrator

## Scope

This guide is for the **curated GitHub Download ZIP** of the v1.0 portfolio candidate. It contains just the final M4C Board A generator and M4B Board B endpoint plus useful simulation, verification, host measurement and engineering evidence. Experimental M2/M3 designs are not required.

**Hardware:** two Digilent Arty A7-35T boards (part `xc7a35ticsg324-1L`), a direct RJ45 patch cable, and separate USB/JTAG/UART connections for each board. **Tool:** AMD Vivado 2025.2.1. Vivado simulations/builds do **not** require hardware attached. Optional: Python 3, `pytest`, Icarus Verilog (`iverilog` and `vvp`), `g++`, `pyserial` for host measurement.

## Extract and generate one Vivado GUI project (Windows)

1. On the feature branch (before merge), click **Code → Download ZIP**. After merge use `main`.
2. Extract to a **short, new folder**, for example `C:\FPGA\Net`. Avoid overwriting any old `Low-latency-ethernet_v2` or the earlier archived bitstreams.
3. Double-click `vivado\create_project.cmd`, or from a Vivado-enabled command prompt run:

   ```bat
   vivado -mode batch -source vivado/create_project.tcl
   ```

4. Open `build\v\EthAB\EthAB.xpr` in Vivado 2025.2.1. The Sources panel contains two independent top hierarchies. The **simulation** top `tb_m4c_board_pair` instantiates **both** FPGAs in a simulated Ethernet MII connection.
5. Select the desired hardware synthesis top and its XDC as a **pair** via Vivado Tcl Console (change directory to the extracted repository first):

   ```tcl
   source vivado/board_config.tcl
   fpga_select_board A
   # or, after archiving a completed A build
   fpga_select_board B
   report_compile_order -constraints
   ```

   The effective constraint-set compile order must contain precisely the relevant board's generated XDC in both synthesis and implementation. **Never trust a constraint-set name alone.** The physical interface uses two generated XDC copies `build/v/xdc/A.xdc` and `build/v/xdc/B.xdc`, derived from the final hardware source XDCs.

## Verify on a PC without two boards

```bat
python -m pip install pytest
python -m pytest -q tests
python scripts/run_final_rtl.py
```

The final Icarus command generates its own protocol frames (including the M4B burst and corrupted FCS) and runs **seven HDL benches**: two FIFOs, M4B RX overflow, M4B endpoint burst, MII feed TX, MII reply RX and the full M4C two-board test. The Python suite checks host telemetry, model, frame building, sources and one-XPR packaging. The independent C++ reference model test requires `g++`.

For an end-to-end GUI simulation use **Flow Navigator → Run Simulation → Run Behavioral Simulation** and run to the testbench's `$finish`. Look for the `PASS tb_m4c_board_pair` output. Simulation is an idealised MII link, not an analogue PHY/wire test.

## Build and preserve the two FPGA bitstreams

In an AMD Vivado-enabled command prompt, after creating the project:

```bat
vivado -mode batch -source vivado/build_targets.tcl -tclargs both
```

The same project synthesizes/routes **one board at a time**. The build helper switches both top and constraints, then archives reports and bitstreams separately:

- `build/out/A/board_A.bit` — generator, top `ethernet_generator_a7_m4c`.
- `build/out/B/board_B.bit` — endpoint, top `ethernet_udp_a7_buffered`.

The output directory is generated locally and not committed. Check top, constraints, implemented DRC, setup/hold/pulse-width margins, CDC warnings and external PHY I/O timing before programming. **Do not waive NSTD/UCIO or missing clocks to make a bitstream.** See [13 November Vivado acceptance](VIVADO_2026-11-13_ACCEPTANCE.md) for the previous local results and limitations. That acceptance validates the earlier local `v2` GUI run; the downloaded branch-head generator must still pass its own clean Windows Vivado test.

## Physical experiment (two boards)

- Identify each FPGA's hardware-manager JTAG serial and corresponding COM port. COM numbers can change between PCs; the original reference run used A=COM4, B=COM3.
- Physically connect A RJ45 **directly to** B RJ45. Attach both USB cables for power, JTAG and UART.
- Program each board with its **own** bitstream; never interchange the images.
- Press/release BTN0 on both, allow link negotiation and reset settling, and verify the physical link before sending profile commands.
- Install `pyserial` and run the host's telemetry benchmark:

  ```bat
  python -m pip install pyserial
  python scripts/m4c_hardware_benchmark.py --com COM4 --profile A --repeat 1 --require-all --csv build/hardware/m4c_smoke.csv
  python scripts/m4c_hardware_benchmark.py --com COM4 --profile all --repeat 3 --csv build/hardware/m4c_final_3x3.csv
  ```

The FPGA reports finite request-launch gaps and matching replies, **not** instrumented PHY pin times or continuous sustainable line rate. The independently reviewed historical hardware evidence is bundled in `evidence/`. The new output bitstreams must not be described as physically benchmarked until a new physical run is actually completed.

## Project records

[Architecture](ARCHITECTURE_V1.md) · [benchmark protocol](M4C_BENCHMARK_PROTOCOL.md) · [verification and performance](VERIFICATION_AND_PERFORMANCE_V1.md) · [current GUI guide](VIVADO_GUI_QUICKSTART.md) · [limitations](LIMITATIONS_V1.md).

**ZIP hygiene:** only the files needed for this current workflow and relevant evidence/docs are bundled. Older milestones and intermediate scripts remain in repository history/online Git and are excluded from the GitHub archive using `.gitattributes export-ignore`.

## Fresh operator follow-up — local `Low-latency-ethernet_v5` on 13 November 2026

After the earlier `v2` acceptance, the operator extracted a fresh GitHub feature ZIP as local `v5`, ran the combined behavioral simulation, completed synthesis/implementation for both top/XDC combinations, generated separate `board_A.bit` and `board_B.bit` and physically exercised the two boards. The photographed PowerShell runs included Profile B `--repeat 10`, Profile C `--repeat 10` (one attempt with initial failures and a later passing attempt), and the separate ten-cycle BTN0 first/warm study. This **extends** the earlier local acceptance but is still operator-observed evidence, not a CI Vivado run or formally reviewed complete raw report bundle.

Exact commands and how to distinguish **PowerShell**, **Vivado Tcl** and interactive **READY** are now consolidated in [TEST_OPERATIONS_GUIDE.md](TEST_OPERATIONS_GUIDE.md); physical pin meanings are in [XDC_AND_IO_REFERENCE.md](XDC_AND_IO_REFERENCE.md). Preserve the fresh CSV/JSON and the earlier failed attempt; **do not claim raw v5 data is committed** until those exact outputs are uploaded and reviewed.
