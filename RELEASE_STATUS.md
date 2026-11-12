# CURRENT STATUS 11 NOVEMBER 2026

**v0.5A: Post-implementation CDC/TX timing repair candidate — NOT FPGA
HARDWARE APPROVED.** Original v0.5 Vivado routed reports show -0.873 ns
TX setup WNS and 147 critical CDC-1 warnings. v0.5A adds TX-domain length
capture/validation and IOB placement constraints to address these without
reducing the PHY timing budget. See `README_V05A_FIRST.md` and
`docs/v0_5a_cdc_tx_timing_audit.md` for steps and limitations.


**v0.4B: User-verified physical Ethernet-to-UART milestone M2A (1/1 and 10/10).**
The complete evidence and limits are documented in
`docs/M2A_HARDWARE_PASS_2026-11-11.md`.

**v0.5: Unverified engineering candidate for Ethernet UDP transmission M2B.**
It requires Icarus simulation, Vivado build/CDC/timing review and then
physical testing before hardware acceptance. The verified v0.4B source and
build script are retained, and the new top is named `ethernet_udp_a7`.
See `docs/v0_5_m2b_candidate.md`.

The following entries are historical and describe the status at the time
of their respective source revisions.

---

# v0.4B: Post-audit CDC and preliminary Ethernet timing corrections

Candidate source revision; see docs/v0_4b_cdc_timing_patch.md. The verified UART-only v0.3 hardware baseline is not changed. New v0.4B RTL / postroute timing have not yet been executed on Vivado.

# Release status — v0.3 UART pin-direction correction / 29 October 2026

**Scope:** updated main-market-data project, still a UART demonstrator; Ethernet
MAC/IPv4/UDP is not implemented. Do not represent this as a complete trading
FPGA or an independently proven low-latency Ethernet processor.

## Root cause and change

v0.2 connected the UART RX module to D10 and UART TX module to A9. On the
Arty A7, D10 is FPGA TX -> PC RX and A9 is PC TX -> FPGA RX. The separate
v0.4 echo diagnostic corrected this, and the user reported 5/5 exact byte
echoes with LD4 heartbeat and LD5/LD7 indicators. This release carries that
**hardware-proven pin direction** into the MAIN application RTL and XDC.

Changed: `rtl/board_uart_demo.sv`, both UART XDC files, UART TB, static
checks and documentation. The Arty S7 pin direction follows Digilent's
schematic labels but has **not** been verified on S7 hardware.

Unchanged: `feed_parser.sv`, `top_of_book.sv`, `feed_pipeline.sv`,
`uart_rx.sv`, `uart_tx.sv`, reference models, protocol and host test program.

## Verification gates

- v0.2 main design: user reported both accelerated RTL benches passing,
  Vivado A7-35 synthesis/implementation/bitstream completed, internal 100MHz
  setup WNS +2.737 ns and WHS +0.106 ns. Physical main UART test failed
  (0 bytes), before correction.
- v0.4 isolated echo diagnostic: user reported simulation PASS at
  100MHz/115200 baud, Vivado build/program and real hardware five-byte echo
  PASS with expected LEDs. This is evidence for the physical UART pin mapping,
  **not** main-project report correctness.
- v0.3 main project: software/reference/static checks repeated in preparation.
  RTL synthesis and board test must be rerun on the corrected source; new
  implementation timing/resource numbers are not yet available.
- Physical A7 main application acceptance: `python scripts/uart_board_test.py
  --port COM4` must report **10/10 exact responses** with BTN0 reset first.
- Full project acceptance (future): Ethernet MAC/MII, IPv4/UDP frame checking,
  two-board testing, reproducible latency and throughput measurements.

See `docs/hardware_test.md` for PowerShell commands and safety checks.

## v0.4A Ethernet RX candidate — 30 October 2026

The original v0.3 UART top and its verified 10/10 hardware-test result remain the reference baseline. A **new** Ethernet MII RX / IPv4 UDP broadcast / CRC / CDC mailbox top-level was added without altering the verified feed parser or top-of-book engine. It returns responses over USB-UART; **Ethernet TX has not been implemented**. Python protocol/structural tests: 10 passed, but **HDL simulation, Vivado implementation and Ethernet hardware verification are pending**. See `docs/ethernet_v0_4a.md` and `docs/v0_4a_verification_matrix.md` before attempting bring-up.
