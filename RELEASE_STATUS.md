# Release status — v1.0 (current; 12 November 2026)

**Current release: v1.0 FPGA Ethernet portfolio demonstrator. Physical evidence dated 11 November 2026.** The opening v0.5A candidate warning in the previous status file was historical, not the status of this release.

- **Hardware:** TWO Digilent Arty A7-35T FPGAs, with a direct 100 Mb/s Ethernet connection.
- **Board A:** v0.9 M4C hardware-controlled packet generator / reply scoreboard.
- **Board B:** v0.8B M4B buffered Ethernet/UDP market-data endpoint.
- **Final physical benchmark:** 9,000/9,000 correct unique replies over nine 1,000-request finite bursts at programmed and FPGA-measured launch rates of 10k, 50k and 100k requests/s. No missing, duplicate, invalid replies or late launches in these trials.
- **Low-load median two-board RTT:** 12.85 microseconds for the v0.8B endpoint. **Not** core-only/one-way processing latency.
- **Routed timing:** Both reported post-route designs have positive constrained setup/hold slack, **not** complete external PHY I/O qualification or formal CDC proof.
- **Interactive Vivado projects:** Generate ONE editable .xpr project using vivado/create_project.tcl; use vivado/board_config.tcl to switch Board A/B top and XDC together, and vivado/build_targets.tcl for separately archived bitstreams. See docs/VIVADO_GUI_QUICKSTART.md. This packaging addition does not change validated RTL and still requires a first local Vivado GUI test.

**Start with:** [README](README.md), [Vivado GUI setup](docs/VIVADO_GUI_QUICKSTART.md), [verification and performance](docs/VERIFICATION_AND_PERFORMANCE_V1.md), [reproduction](docs/REPRODUCIBILITY_V1.md), [limitations](docs/LIMITATIONS_V1.md).

## Historical engineering stages

- v0.2–v0.3: UART synthetic feed prototype.
- M2A v0.4B: physically verified Ethernet RX → UART.
- M2B v0.5A: physically verified bidirectional UDP path.
- M2C v0.6: initial direct two-FPGA experiment.
- M3 v0.7: parallel Ethernet/UART response, major RTT improvement.
- M4A v0.8A: initial host-generated burst exploration.
- M4B v0.8B: dual-clock RX/TX FIFO buffering and separate UART diagnostics.
- M4C v0.9: FPGA-native 1,000-request benchmark with verified 9/9 test matrix.
- v1.0: frozen hardware source plus documentation and portfolio evidence.

Older README_M* and RELEASE_M* files are historical records. The intended v1.0 engineering scope is complete; hardening items remain optional future work.
