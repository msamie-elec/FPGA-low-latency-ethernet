# Upwork portfolio case study — FPGA Ethernet hardware acceleration

**Title:** Low-Latency FPGA Ethernet Processing — RTL, UDP, CDC, FIFO and Hardware Verification

## The engineering challenge

Develop and validate a hardware-based network data processor that receives synthetic market-data records over 100 Mbps Ethernet, processes them inside an FPGA, and generates Ethernet responses. The design required clock-domain crossing between the 25 MHz MII receive/transmit interfaces and a 100 MHz processing engine.

## Solution delivered

Designed the RTL parser and market-data processing pipeline; integrated the Arty A7 Ethernet PHY MII interface and bidirectional UDP packet handling; implemented cross-clock request/acknowledge paths followed by bounded asynchronous FIFOs; developed independent Python and C++ reference checks, Icarus simulation testbenches, Vivado build/timing constraints and real two-board regression tests.

## Results demonstrated

- 200/200 successful direct FPGA-to-FPGA functional transactions on two Digilent Arty A7-35T boards.
- Reduced mean valid-report hardware round-trip time from ~1,228 µs to ~12.75 µs by decoupling Ethernet response generation from slow diagnostic UART serialization.
- Maintained ~12.85 µs mean hardware round-trip time after introducing buffering and independent UART diagnostics.
- Demonstrated short-burst behaviour with explicitly recorded delivery limits; final hardware-native throughput profile results will be added **only after measured**.

## Services this work illustrates

FPGA architecture and RTL design; SystemVerilog/Verilog implementation; Ethernet and UDP protocol interfacing; CDC and FIFO engineering; simulation and testbench automation; Vivado synthesis, place-and-route and timing analysis; Python-driven hardware validation; performance bottleneck identification and optimisation.

**Honest scope:** The figures refer to a fixed synthetic packet protocol on a development board, not production networking or pure datapath processing latency. Engineering sign-off would require broader CDC, physical timing and reliability qualification.

**Suggested visuals:** (1) two-board RJ45/USB hardware photograph; (2) block diagram; (3) v0.6 vs v0.7 RTT chart; (4) final hardware throughput table. Use only personally owned/authorised images and evidence.
