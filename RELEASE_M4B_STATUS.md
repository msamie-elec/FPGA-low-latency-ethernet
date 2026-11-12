# M4B v0.8B release status — 11 November 2026

**Not approved for FPGA programming.** New buffered RTL and a four-part Icarus
simulation suite are provided as an engineering candidate. Tests have not yet
run in Icarus or Vivado in this authoring environment.

### Baselines preserved

- v0.7 source RTL and constraints: all 24 original files match the frozen
  SHA-256 manifest from M4A.
- v0.6 hardware: 200/200 two-board responses, median valid-report RTT
  1,228.36 µs before UART decoupling.
- v0.7 hardware: 200/200 two-board responses, median RTT 12.75 µs.
- M4A host throughput: stable 5 ms and 2 ms intervals 200/200 under tested
  conditions. Windows offered-rate values are not wire-rate measurements.

### Tests still required

1. Icarus: async FIFO, sync FIFO, 22-frame MII burst with CRC validation,
   two-board RTT compatibility (see `scripts/run_m4b_sim.ps1`).
2. Vivado: synthesis, route, fully qualified CDC, output IOB packing and
   positive constrained setup/hold; board-level timing review outstanding.
3. Hardware: FPGA-to-FPGA response matching and RTT; host-to-FPGA 5/2/1 ms
   calibration, then overload and reset tests.
4. M4C: FPGA-native programmable packet generator to measure actual sustained
   packet rate and loss without Windows scheduling.

### Design behaviour under overload

Valid input frame accepted when RX FIFO has space; otherwise frame dropped and
`debug_rx_overflows` increases. Core stalls when Ethernet TX FIFO is full;
Ethernet responses are never intentionally discarded after acceptance into the
processing core. UART diagnostic copy is dropped when its FIFO is full, with
`debug_uart_drops` increasing. Counters saturate at 0xffff.

### Source files added

- `rtl/m4b_async_fifo.sv`
- `rtl/m4b_sync_fifo.sv`
- `rtl/mii_udp_rx_m4b.sv`
- `rtl/mii_udp_tx_m4b.sv`
- `rtl/ethernet_udp_a7_buffered.sv`
- `boards/arty_a7/ethernet_m4b_endpoint.xdc`
- `scripts/build_m4b_endpoint.tcl`, `scripts/run_m4b_sim.ps1`
- `scripts/check_m4b_candidate.py`, `scripts/audit_m4b_reports.py`
- `scripts/m4b_vectors.py`, four M4B SystemVerilog testbenches.
