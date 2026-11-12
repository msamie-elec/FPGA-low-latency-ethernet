> **Historical planning record.** The M4C physical benchmark is now completed; see [final verification](VERIFICATION_AND_PERFORMANCE_V1.md), [publication checklist](../portfolio/PUBLICATION_CHECKLIST.md), and [v1.0 release notes](RELEASE_NOTES_V1.md).

# Project 1 — v1.0 GitHub and Upwork release plan

**Project title:** FPGA Low-Latency Ethernet Market-Data Processor — Dual Artix-7 Demonstrator

**Hard stop:** Finish the three M4C burst profiles and final evidence audit, produce the release below, then move to the FPGA DSP and digital-communications project. **No M4D or more feature milestones.** If some profile loses packets, report the measured boundary instead of redesigning for guaranteed zero loss. Only fix defects that invalidate the stated experiment or its reproducibility.

## Verified evidence available before M4C

- UART v0.3 physical FPGA market-data regression: 10/10 passed.
- Ethernet RX-to-UART v0.4B: 200/200 paced physical transactions passed.
- Bidirectional UDP+UART v0.5A: 200/200 paced physical transactions passed.
- Direct two-FPGA v0.6: 200/200 sequential transactions passed; valid-report mean RTT approximately 1,228.37 µs (includes UART-first diagnostic delay).
- v0.7 parallel UDP/UART architecture: 200/200 passed; approximately 12.745 µs mean FPGA-to-FPGA RTT (with clock-counter resolution of 10 ns).
- v0.8B buffered endpoint: 200/200 sequential transactions passed; approximately 12.845 µs mean RTT. Added 16-deep RX/TX FIFOs and independent diagnostic queue.
- Host-based M4B zero-intentional-gap run of 1,000 packets: 982 valid UDP replies, 18 missing in one contiguous interval. This is NOT a guaranteed wire-rate or sustained FPGA throughput measurement.

## Remaining acceptance gates

1. M4C source and Python regression pass; Board A two-board RTL testbench passes on Windows.
2. M4C Vivado synthesis, routing, timing and CDC audit reviewed. No negative constrained setup/hold slack; zero unexplained CDC-1; review TX output setup and asynchronous mailbox limitations.
3. Controlled physical A/B FPGA test succeeds, or any benchmark limitation is documented accurately. Collect 3 × 1,000 packets for each of three requested intervals; distinguish requested spacing from actual measured launch gaps.
4. Capture final hardware evidence with SHA-256 checksums, bitstream identity, exact board/COM mapping, date and Vivado tool version.
5. Perform public-repository safety scan: remove user-specific paths, confidential client assets, secrets, third-party copyrighted documents, and raw private logs; verify license for all included files.
6. Publish ONE understandable `v1.0` GitHub release with README, architecture, build/test commands, result tables and known limitations. Intermediate builds are historical, not the primary source tree.
7. Create an Upwork portfolio entry with 2–4 screenshots/diagrams and a short narrated demonstration. **Do not claim commercial production readiness or unmeasured performance.**
8. Archive project and begin Project 2 (DSP + digital communications) rather than further Ethernet redesign.

## Suggested public repository layout

```
fpga-low-latency-ethernet/
  README.md
  LICENSE
  rtl/                 # Board A M4C and Board B M4B entrypoints, reusable IP
  tb/                  # deterministic RTL simulations
  boards/arty_a7/      # synthesizable FPGA constraints
  software/            # Python/C++ independent models
  scripts/             # simulation, Vivado and host test scripts
  tests/               # Python regression suite
  docs/                # architecture, verification, results, limitations
  evidence/            # selected shareable anonymised report excerpts
```

## Recommended evidence figures

- Physical connection: two Arty A7 boards, each on USB to laptop, direct Cat6 Ethernet between them.
- Architecture: 25 MHz MII RX -> 16-entry dual-clock FIFO -> 100 MHz processing -> 16-entry TX FIFO -> MII TX; separate UART diagnostic queue.
- Hardware RTT comparison: v0.6 valid report 1,228.37 µs; v0.7 12.745 µs; v0.8B 12.845 µs. Explain UART-first delay.
- M4C profile matrix: offered/requested period, actual sent gap and unique responses (only fill with measured values).
- FPGA resource/timing report excerpts for the FINAL tested bitstream (no synthetic signoff claims).

## Public claim guardrails

Use **'measured dual-FPGA round-trip time'**; not 'pure processing latency'.
Use **'short-burst response delivery'**; not 'sustained line-rate throughput' unless separately established.
Use **'CDC checks performed in Vivado with reported limitations'**; not 'formally proven CDC-safe'.
Use **'synthetic market-data stream'**; not a production exchange feed or certified trading signal.

## Close-out

**When all eight acceptance activities are complete, mark Project 1 CLOSED and start Project 2.** Future enhancements are optional research issues, not prerequisites for the portfolio release.
