# M2B v0.5A physical acceptance — verified evidence

The user ran the v0.5A bidirectional Ethernet test on 11 November 2026 with an Arty A7-35T, TP-Link UE300C and Windows laptop. The test reported 200/200 physical UDP+UART transactions PASS with 5ms host pacing. The uploaded CSV is preserved verbatim in `docs/evidence/m2b_bidirectional_reliability_200pass.csv`.

Verified CSV: 200 data rows, all `pass=1`, no recorded failure reason, UDP source `192.168.77.2` port 5000 for all rows, every UDP response byte-for-byte equals UART and Python expected result. Counts: 167 `R`, 20 `I`, 13 `E`.

**Known limitation:** This supports an acceptance claim for the tested physical bidirectional functionality, not for PHY power/waveform/board-skew timing sign-off, CDC proofs, max throughput, burst handling, FPGA-only latency or two-board communication.

Original user's verified working project: `T:\` / v0.5A. The M2C package includes unmodified v0.5A RTL for Board B but **no pre-built FPGA bitstream**, which remains in the user's Vivado build directory. M2C Board A has NOT yet been hardware tested.
