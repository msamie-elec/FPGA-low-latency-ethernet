# Vivado GUI quick start — ONE project, TWO FPGA boards

**Physical requirement:** two Digilent Arty A7-35T FPGAs directly connected over 100 Mb/s Ethernet. The repository creates **ONE editable Vivado GUI project** containing both independent RTL tops, two mutually exclusive XDC constraint sets and a combined two-board simulation. Each board still requires a separate bitstream. Historical Arty S7 UART examples are not supported for the final Ethernet implementation.

## Step 1: Generate and open ONE Vivado .xpr

**Avoid Windows path-length errors:** Extract the repository to a short location such as `C:\FPGA\Net` rather than a deeply nested Projects folder. The generator creates the short `build/v/EthAB/EthAB.xpr` path.

With Vivado 2025.2.1 installed, Windows users can double-click vivado/create_project.cmd. Alternatively, from a Vivado-enabled shell:

    vivado -mode batch -source vivado/create_project.tcl

Open this single generated project in Vivado using File > Project > Open:

    build/v/EthAB/EthAB.xpr

The XPR is generated under ignored build/ for portability. Creation alone runs no synthesis or implementation.

**XDC compatibility:** The verified legacy XDC files under `boards/arty_a7/` are hash-frozen and are NOT modified. During project generation, Vivado-compatible XDC copies are written to `build/v/xdc/A.xdc` and `build/v/xdc/B.xdc`. They retain every pin, clock and timing constraint unchanged; the only omissions are two unsupported Tcl `if` port-count guards, and they add `set_property CFGBVS VCCO [current_design]` and `set_property CONFIG_VOLTAGE 3.3 [current_design]`, as required by Digilent's Arty A7 Rev E schematic (configuration-bank 0 at 3.3 V). The checks now live in `vivado/check_mii_ports.tcl` and run after synthesis in the automated dual-target build. Existing older `v2` local projects can instead remove those two guards directly from each XDC and rerun synthesis.

**Windows launch and failure behaviour:** The corrected launcher verifies the project was generated **and reopened** successfully, then starts Vivado GUI with the generated XPR. If it prints an error, leave the project unbuilt and inspect the console; a partial XPR is not a valid project. The earlier Tcl error `[Common 17-163] Missing value for option 'name'` was caused by a bare `save_project` call in the first packaging candidate. Vivado automatically saves project changes; the invalid command has been removed from both the project generator and board selector. If you downloaded a ZIP before that correction, obtain the updated branch or remove the lone `save_project` lines from both Tcl files.

## Step 2: Switch the design hierarchy AND constraints together

In Vivado Tcl Console, change directory to the repository root and run:

    source vivado/board_config.tcl
    fpga_select_board A

Expand Design Sources to inspect Board A. To inspect Board B, run:

    fpga_select_board B

The helper switches BOTH the synthesis top and the matching XDC set. Do not manually change the top alone without also changing the constraints. Old synth_1/impl_1 runs are reset when changing targets; completed bitstreams and available reports are archived before switching.

| Target | Board A traffic generator | Board B buffered endpoint |
|---|---|---|
| Synthesis top | ethernet_generator_a7_m4c | ethernet_udp_a7_buffered |
| Constraint set | constrs_board_a | constrs_board_b |
| Active GUI XDC | build/v/xdc/A.xdc | build/v/xdc/B.xdc |
| Frozen source XDC | ethernet_m4c_generator.xdc | ethernet_m4b_endpoint.xdc |
| FPGA part | xc7a35ticsg324-1L | xc7a35ticsg324-1L |
| Archived output | board_A.bit | board_B.bit |

**Board A hierarchy:** 100 MHz request scheduler and sequence scoreboard in the top; MII feed transmitter mii_feed_tx, reply receiver mii_reply_rx, UART modules uart_rx and uart_tx.

**Board B hierarchy:** Ethernet RX mii_udp_rx_m4b, 16-entry asynchronous RX FIFO, 100 MHz feed_pipeline with feed_parser / top_of_book, 16-entry asynchronous reply FIFO into mii_udp_tx_m4b, and separate 8-entry synchronous UART diagnostic FIFO plus uart_tx.

Both synthesis top modules appear in Design Sources, but **only the selected module is synthesized as top**. The other is not instantiated by it.

### Verify effective XDC files before synthesis or implementation

The **constraint set name alone is not proof the XDC is applied**. The first Windows acceptance run found Board B could be selected with `constrs_board_b` yet have an empty constraint compile order, resulting in all 22 ports unassigned, unconstrained clocks and meaningless timing (`inf`). The corrected board selector now verifies/repairs the generated XDC association and **refuses to continue** if no effective synthesis/implementation constraints are found.

In the Vivado Tcl Console, check:

    report_compile_order -constraints

Both synthesis and implementation sections must show the chosen Board A or Board B XDC. If either section is empty, **do not generate a bitstream**. In the earlier local v2 project, first attach your corrected `boards/arty_a7/ethernet_m4b_endpoint.xdc` to `constrs_board_b` and rerun both synthesis and implementation. Never downgrade NSTD-1, UCIO-1 or TIMING-17 to allow unconstrained programming.

## Step 3: Simulate BOTH FPGA designs together

Simulation Sources has a separate top, tb_m4c_board_pair, that instantiates both FPGAs and connects them over an idealized MII link. This simulation top remains the same regardless of the selected synthesis board.

In Vivado select Run Simulation > Run Behavioral Simulation and enter in the XSim console:

    run all

Look for the PASS tb_m4c_board_pair completion message. PHY analog/electrical timing is not simulated. The independent Icarus suite has six final testbenches:

    python scripts/run_final_rtl.py

This requires iverilog and vvp. GitHub Actions covers this Icarus regression but not Vivado implementation.


### Switching synthesis tops: incremental reuse and expected FIFO warnings

Vivado's default *Automatically selected checkpoint* incremental-synthesis option can try to reuse the earlier Board A `.dcp` when Board B is selected. Since these are **different designs**, choose **Settings > Synthesis > Incremental Synthesis > Disable incremental compile** before re-running `synth_1` on the other top. The `[Synth 8-6895]` unsuited-checkpoint message means Vivado falls back to standard synthesis, not that Board B RTL is invalid. Do not reuse Board A's synthesis checkpoint as Board B's reference.

Board B's historical `m4b_async_fifo.sv` uses a small distributed-style dual-clock FIFO. Vivado may report `[Synth 8-7137]` (memory inferred with set/reset handling; possible simulation mismatch) and `[Synth 8-4767]` (FIFO memory implemented in registers, not BRAM). **Do not change the hardware-verified FIFO simply to suppress warnings.** These are an acknowledged resource limitation and a warning to retain regression checks; examine the actual mapped implementation and CDC/report results. See [limitations](LIMITATIONS_V1.md).

## Step 4: Generate TWO independent bitstreams from ONE project

Recommended automated dual-target build (requires the generated XPR):

    vivado -mode batch -source vivado/build_targets.tcl -tclargs both

This builds Board A, archives its output, changes the top/XDC, then builds and archives Board B:

    build/out/A/board_A.bit
    build/out/B/board_B.bit

Alternatively, in the GUI select Board A with fpga_select_board A, use Run Synthesis > Run Implementation > Generate Bitstream, then enter:

    fpga_archive_current
    fpga_select_board B

Generate Board B's bitstream, then run fpga_archive_current. This deliberately reuses the single project's synthesis/implementation runs while preserving the two finished outputs. The original separate Vivado batch scripts remain unchanged for reproducing their historical detailed routed reports.

**IMPORTANT:** This new one-project Tcl workflow was tested through Tcl mock/structural checks but has NOT yet been run inside installed AMD Vivado here. Run the first local Vivado 2025.2.1 acceptance check and examine routed timing, clock-domain crossings, PHY I/O and methodology warnings before programming newly generated bitstreams. Positive slack or a completed bitstream alone is not full PHY/CDC qualification.

## Step 5: Program the TWO Arty A7-35T boards

    Laptop (USB/JTAG/UART)             Laptop (USB/JTAG/UART)
               |                                 |
     Board A: Arty A7-35T <-- RJ45 --> Board B: Arty A7-35T
     M4C generator/scoreboard 100 Mb/s M4B buffered endpoint

Connect the boards directly by Ethernet RJ45, and each board individually to the laptop by USB. In Vivado Hardware Manager verify the JTAG device identity before programming **Board A with board_A.bit** and **Board B with board_B.bit**. Press/release BTN0 on both and check link. COM4 and COM3 are historical examples, not guaranteed port assignments. Benchmark commands use the UART port for Board A:

    python scripts/m4c_hardware_benchmark.py --com COM4 --profile A --repeat 1 --require-all --csv build/hardware/m4c_smoke.csv
    python scripts/m4c_hardware_benchmark.py --com COM4 --profile all --repeat 3 --csv build/hardware/m4c_final_3x3.csv

The recorded 12.85 microseconds value is **low-load two-board RTT**. The highest measured 100,000 request launches/s was a **finite-burst** result, not a continuous sustained or wire-timestamped Ethernet performance guarantee. See the verification, benchmark protocol and limitations documents.
