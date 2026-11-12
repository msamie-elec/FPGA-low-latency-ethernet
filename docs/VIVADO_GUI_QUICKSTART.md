# Vivado GUI quick start — v1.0 dual-FPGA design

**This is TWO independent FPGA bitstreams and two Vivado projects, not a single-board application.** The verified physical setup uses **2 × Digilent Arty A7-35T** (Artix-7 part xc7a35ticsg324-1L) connected directly through a Cat5e/Cat6 RJ45 patch cable at 100 Mb/s. Historical Arty S7 UART files are not supported targets for the final Ethernet design.

## Inspect RTL hierarchy — no physical boards required

Use AMD **Vivado 2025.2.1**. Clone/download the repository to a writable folder. On Windows **double-click vivado/create_gui_projects.cmd**, or run from a Vivado-enabled shell at the repository root:

    vivado -mode batch -source vivado/create_gui_projects.tcl -tclargs both

This creates two *source-managed* editable GUI projects without running synthesis:

| Open this generated .xpr in Vivado | Design Sources synthesis top | Constraint file |
|---|---|---|
| build/vivado_gui/board_a_generator/board_a_generator.xpr | ethernet_generator_a7_m4c | boards/arty_a7/ethernet_m4c_generator.xdc |
| build/vivado_gui/board_b_endpoint/board_b_endpoint.xpr | ethernet_udp_a7_buffered | boards/arty_a7/ethernet_m4b_endpoint.xdc |

Select **File → Project → Open** in Vivado, then expand **Design Sources**. The other board's RTL is added as **Simulation Sources only**, so the two independent synthesis hierarchies remain separate. Both projects include tb_m4c_board_pair.sv for a virtual link between the FPGA designs.

Auto-generated projects live in ignored build/ because XPR files may capture local paths and tool state. Re-run the portable Tcl after relocating the checkout.

### Board A (traffic generator and validator)

- Top: ethernet_generator_a7_m4c
- Ethernet MII request TX: mii_feed_tx
- Ethernet reply RX: mii_reply_rx
- Host UART interface: uart_rx / uart_tx
- Timing scheduler and sequence scoreboard are implemented inside the top module.

### Board B (buffered market-data endpoint)

- Top: ethernet_udp_a7_buffered
- Ethernet/FCS/IPv4/UDP RX: mii_udp_rx_m4b
- Dual-clock receive/transmit queues: m4b_async_fifo, instantiated twice
- Processing core: feed_pipeline, feed_parser, top_of_book
- Ethernet UDP reply TX: mii_udp_tx_m4b
- Independent diagnostic UART queue: m4b_sync_fifo and uart_tx

Processing uses a 100 MHz FPGA clock; Ethernet PHY MII RX/TX uses 25 MHz clock domains. This is a deliberately fixed-format laboratory UDP design, not a general-purpose network stack.

## Simulate

In either Vivado project select **Run Simulation → Run Behavioral Simulation** and enter **run all** in the XSim Tcl console. Simulation top: tb_m4c_board_pair, idealized direct MII connection, three A/B/C profiles with eight packets each. Expected success banner:

    PASS tb_m4c_board_pair: three hardware-paced profiles and reply scoreboard

Run the six final RTL tests in Icarus on Windows or Linux:

    python scripts/run_final_rtl.py

This requires iverilog and vvp on PATH; it executes the five M4B benches and the M4C dual-board bench. The new Vivado GUI generation workflow has **not yet been exercised in an installed Vivado session in this packaging update** and should be checked on Vivado 2025.2.1.

## Build two bitstreams

Either use Vivado GUI **Run Synthesis → Run Implementation → Generate Bitstream**, or reproduce the original verified batch builds and reports independently:

    vivado -mode batch -source scripts/build_m4c_generator.tcl
    vivado -mode batch -source scripts/build_m4b_endpoint.tcl

Review routed timing, CDC and external PHY interface warnings **before programming**. Positive slack does not imply formal CDC/PHY qualification. See [limitations](LIMITATIONS_V1.md).

## Physical two-board setup

    Laptop / Host PC
       | USB power, JTAG, UART               | USB power, JTAG, UART
       v                                     v
    Board A (Arty A7) <==== RJ45 ======> Board B (Arty A7)
    Hardware-paced TX      100 Mb/s           Buffered RX/processing
    Reply scoreboard      direct cable       Ethernet UDP reply TX

Program **Board A** with the M4C generator bitstream and **Board B** with the M4B buffered endpoint bitstream. Press and release BTN0 on both; verify Ethernet link. COM4 and COM3 are historical serial-port examples, not fixed mappings. The laptop only sends test control over UART and reads results: traffic is FPGA-paced.

    python scripts/m4c_hardware_benchmark.py --com COM4 --profile A --repeat 1 --require-all --csv build/hardware/m4c_smoke.csv
    python scripts/m4c_hardware_benchmark.py --com COM4 --profile all --repeat 3 --csv build/hardware/m4c_final_3x3.csv

See [reproduction](REPRODUCIBILITY_V1.md), [benchmark protocol](M4C_BENCHMARK_PROTOCOL.md), and [verification](VERIFICATION_AND_PERFORMANCE_V1.md).

**Measurement limits:** ~12.85 µs measured *two-board low-load RTT*; 9,000/9,000 valid replies over nine finite test bursts at FPGA request-launch rates up to 100,000/s. These are not one-way core latency, continuously sustained packet rates, Ethernet wire timestamps, or production qualification claims.
