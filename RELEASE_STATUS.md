# Release status — v1.0 candidate (updated 13 November 2026)

**Current candidate: v1.0 FPGA Ethernet portfolio demonstrator.** Physical benchmark evidence is dated 11 November 2026. GitHub pull request #1 is still **draft/unmerged**. The opening v0.5A candidate warning in the previous status file was historical, not the status of this candidate.

- **Hardware:** TWO Digilent Arty A7-35T FPGAs, with a direct 100 Mb/s Ethernet connection.
- **Board A:** v0.9 M4C hardware-controlled packet generator / reply scoreboard.
- **Board B:** v0.8B M4B buffered Ethernet/UDP market-data endpoint.
- **Final physical benchmark:** 9,000/9,000 correct unique replies over nine 1,000-request finite bursts at programmed and FPGA-measured launch rates of 10k, 50k and 100k requests/s. No missing, duplicate, invalid replies or late launches in these trials.
- **Low-load median two-board RTT:** 12.85 microseconds for the v0.8B endpoint. **Not** core-only/one-way processing latency.
- **Routed timing:** Both reported post-route designs have positive constrained setup/hold slack, **not** complete external PHY I/O qualification or formal CDC proof.
- **One-XPR local acceptance, 12–13 Nov:** Both RTL tops were synthesized, routed, checked and archived as individual bitstreams in the user's local Windows Vivado 2025.2.1 `v2` working copy. Board A WNS/WHS +0.576/+0.052 ns, Board B +0.737/+0.046 ns, zero final routed DRC violations. The user's local simulator also passed the combined two-board testbench. See the [detailed record](docs/VIVADO_2026-11-13_ACCEPTANCE.md). These particular November bitstreams have *not* been rerun as a new physical benchmark.
- **Interactive Vivado generator:** `vivado/create_project.tcl` creates one editable `.xpr`; `board_config.tcl` switches top and matching XDC; `build_targets.tcl` creates two separately archived bitstreams. The branch-head generator's improved XDC recovery guard is CI/mock-tested but **still needs a fresh installed-Vivado acceptance run** before merge. No functional RTL or frozen historical XDC changed.

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
