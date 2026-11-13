# v1.0 - Final portfolio release (11 November 2026)

## Scope freeze

**Technical development closed after M4C.** Board A uses v0.9 hardware-native benchmark generator; Board B uses verified v0.8B FIFO endpoint. The v1.0 identifier refers to the *portfolio packaging and documentation*, not a new synthesis RTL version or newly designed FPGA bitstream.

## Measured acceptance

- M4C 9/9 physical FPGA-to-FPGA 1,000-packet trials passed; 9,000/9,000 replies correctly matched (three trials each at 10k/50k/100k packet requests/s).
- Additional M4C profile A smoke trial 1,000/1,000 replies.
- Hardware-reported request-launch gaps equal the programmed 100/20/10 us periods in all final trials, with zero late launches.
- M4C generator and M4B buffered endpoint both had positive constrained setup/hold slack in the supplied Vivado 2025.2.1 reports.
- Sequential hardware round-trip latency: v0.7 median 12.75 us; v0.8B median 12.85 us. Both are *hardware RTT*, not core processing latency.

## Single-XPR packaging acceptance — 12–13 November 2026

A separate local Vivado 2025.2.1 GUI acceptance run verified **one project with two selectable top-level modules and mutually exclusive XDC sets**, plus combined behavioral simulation. In this working copy, **both** FPGA designs completed synthesis, place/route and bitstream generation, and their bitstreams and routed reports were saved to **separate local archives** (`build/out/A` and `build/out/B`).

| Metric | Board A M4C | Board B M4B |
|---|---:|---:|
| Setup WNS | +0.576 ns | +0.737 ns |
| Hold WHS | +0.052 ns | +0.046 ns |
| Pulse-width worst slack | +4.500 ns | +4.500 ns |
| Routed DRC violations | 0 | 0 |
| Tool-classified unsafe CDC endpoints | 0 | 0 |
| Bitstream archive | `board_A.bit` | `board_B.bit` |

**This local success is not a new two-board physical benchmark or certification.** Board B's original empty XDC selection was corrected and both runs rebuilt; the valid results above supersede its earlier unconstrained route and unrealistic 10.193 W low-confidence estimate. Residual `TIMING-18` I/O delay warnings, `CDC-6`/`CDC-15` findings, and Board B FIFO set/reset inference warnings still require engineering review. The PR's later project generator/XDC guard is **CI-mock-tested, not newly Windows-tested**. Details and reproducible checks: [Vivado GUI acceptance](VIVADO_2026-11-13_ACCEPTANCE.md).

## Exclusions

The rate measurement is finite-burst FPGA request launch timing with matching replies, not measured line rate or indefinitely sustainable throughput. No full PHY timing signoff, CDC formal proof or exchange-protocol claims. No new Ethernet features after this release.

## Publication tasks requiring manual action

1. Review repository metadata, MIT license rights and third-party constraint provenance.
2. Add an original photo of the actual two-board physical setup and a screenshot of Vivado timing/results (crop computer names and serials as appropriate).
3. Review and merge the current GitHub pull request only after licensing/provenance review and a fresh branch-head Vivado generator acceptance test; then tag **v1.0** if the evidence is sufficient. Do not create a duplicate repository.
4. Add GitHub project link and a short demo video to Upwork/LinkedIn portfolio entries.
5. Archive the exact verified bitstreams locally, separately from the public source tree, with tool-version and build hashes.

The current GitHub branch is a **draft PR**, not a merged release or newly published public hardware qualification. Do not attach generated bitstreams or machine-specific raw reports to the public source tree.
