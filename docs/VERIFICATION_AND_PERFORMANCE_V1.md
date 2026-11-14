# v1.0 Verification and performance report

**Evidence date:** 11 November 2026  
**Platform:** 2 x Digilent Arty A7-35T, 100 Mb/s direct Ethernet, Vivado 2025.2.1  
**Final DUT:** Board A v0.9 M4C benchmark generator; Board B v0.8B buffered UDP endpoint

## Executive result

The fixed final M4C benchmark matrix passed in all nine runs. Each run requested 1,000 FPGA-generated UDP synthetic-feed transactions at a controlled 100 MHz packet-request interval. Board A's sequence scoreboard received **9,000 / 9,000 unique valid responses**, with no missing, duplicate, unexpected or invalid responses, and no late request launches. A separate conservative smoke test also returned 1,000 / 1,000.

| Profile | Period cycles | Measured min/max request gap | Offered request rate | Runs | Replies | Missing | Late launches |
|---|---:|---|---:|---:|---:|---:|---:|
| A | 10,000 | 10,000 / 10,000 | 10,000/s | 3 | 3,000/3,000 | 0 | 0 |
| B | 2,000 | 2,000 / 2,000 | 50,000/s | 3 | 3,000/3,000 | 0 | 0 |
| C | 1,000 | 1,000 / 1,000 | 100,000/s | 3 | 3,000/3,000 | 0 | 0 |

For each 1,000-packet burst, `send_span_cycles = 999 x request_period_cycles`, corresponding to 99.9 ms (A), 19.98 ms (B) and 9.99 ms (C) between the first and last scheduled requests. No late launches were reported. Independent CSV and JSON records agree in all nine cases. The 40-byte UART telemetry protocol is detailed in [M4C_BENCHMARK_PROTOCOL.md](M4C_BENCHMARK_PROTOCOL.md).

### What is *not* measured

This is not a maximum packet-rate sweep, a formal sustainable-throughput bound or a PHY pin timestamp measurement. 100,000 requests/s is the highest **tested loss-free FPGA request rate in these finite bursts**, not a guarantee of continuous 100,000 packet/s operation. The Board B FIFO overflow counters and diagnostic loss counters were not captured in M4C; therefore no assertion about their hardware values is supported by these results.

## Low-load round-trip latency (separate earlier experiments)

| Architecture | Physical A/B hardware RTT | Note |
|---|---:|---|
| v0.6 Board B UART-gated reply path | 1,228.368 us **mean for valid report type** | Delayed by UART serialization |
| v0.7 Board B parallel Ethernet TX + UART | 12.75 us **median**, valid report mean 12.746 us | 200/200 physical functional pass |
| v0.8B Board B buffered FIFO endpoint | 12.85 us **median**, approx. 12.845 us overall mean | 200/200 physical functional pass |

The valid-report mean v0.6-to-v0.7 improvement was roughly **98.96%**, reflecting a significant architectural bottleneck removal rather than a claim that PHY or combinational core latency improved by 99%. The v0.8B buffering addition costs ~0.10 us RTT relative to v0.7 in the low-rate sequential experiment. RTT includes both wire traversals, Ethernet frame serialisation, clock crossings and protocol/processing response; it is **not one-way FPGA processing latency**. Do not extrapolate this low-load RTT to M4C's high-rate bursts.

## Software and RTL verification

- M4B endpoint: 45/45 Python tests passed, five HDL benches passed: sync FIFO, async FIFO, counted receive overflow, 22-frame burst / CRC, and two-board loop.
- M4C candidate: 52/52 Python tests reported passing; FPGA-native A/B RTL bench passed three simulated profiles (8 packets each, exact cycle spacing) and response scoreboard.
- M4B 22-frame simulated burst returned 22 ordered UDP/FCS replies with RX drops=0 and UART diagnostic drops=13; dropped diagnostics are distinct from lost Ethernet responses.
- Board B sequential physical hardware validation: 1/1, 25/25 and 200/200 correct.
- Host-generated zero-gap 1,000-packet test previously returned 982 replies and 18 missing; the host-generated rate is not a calibrated FPGA or PHY rate and is not directly comparable to the final deterministic M4C hardware benchmark.

## Vivado routed implementation summary

| Routed board design | WNS | WHS | LUTs | Flip-flops | Block RAM |
|---|---:|---:|---:|---:|---:|
| Board A v0.9 M4C generator | +0.576 ns | +0.052 ns | 2,485 | 2,247 | 0 |
| Board B v0.8B buffered endpoint | +0.737 ns | +0.046 ns | 2,175 | 6,119 | 0 |

**Additional local GUI workflow acceptance (12–13 Nov 2026):** The user independently opened one `EthAB.xpr` on Vivado 2025.2.1, simulated both board tops, and generated and separately archived `board_A.bit` and `board_B.bit` with post-route reports. Both had zero final implemented DRC violations, positive pulse-width worst slack (+4.500 ns), and zero failing constrained timing endpoints. In the Board B CDC report, 303 endpoints were tool-classified safe (none unsafe/unknown), though there were 7 CDC-6 and 232 CDC-15 structural warnings. Full record: [13 Nov local Vivado acceptance](VIVADO_2026-11-13_ACCEPTANCE.md). **The newer GitHub Tcl generator/automatic XDC repair has not yet been rerun in that installed Vivado environment**, and these local November bitstreams have not received a separate physical benchmark.

The implementations show positive overall constrained setup/hold slack and no critical CDC-1 report entries. However, the detailed CDC and methodology reports contain multibit data crossing and incomplete external I/O timing qualification concerns. Positive slack and zero CDC-1 warnings do not demonstrate formal asynchronous-data coherency or full PHY signoff. Both v0.8B FIFOs were implemented without BRAM. See [limitations](LIMITATIONS_V1.md).

## Data provenance and integrity

- Source primary measurements: `evidence/m4c/m4c_final_3x3.csv` + matching `.summary.json`; single-run evidence `m4c_smoke_retry.csv` and `.summary.json`.
- CSV summaries independently re-parsed; every run contains 1,000 sent, 1,000 unique replies and identical achieved min/max gaps equal to requested periods. All nine JSON result rows match the CSVs on profile, sent, unique response count and launch span.
- Vivado metrics summarized from user-supplied `m4c_generator_reports.zip` and `ethernet_m4b_endpoint_reports.zip`; raw reports are not republished here because they contain user-machine metadata.
- Full bitstreams and the exact physical JTAG serial mapping are not included in the public package; users must build and verify on their own FPGA hardware.

**Conclusion:** M4C finite-burst verification succeeded at the fixed highest tested FPGA request rate of 100,000/s, and Project 1's agreed technical scope is complete. Remaining work is only repository/portfolio publishing and optional photos/screenshots, not further Ethernet RTL feature development.

## Additional physical verification — user's fresh Windows `Low-latency-ethernet_v5` session, 13 November 2026

**Evidence level:** operator-supplied Vivado/PowerShell screenshots and the printed terminal summaries, **not** a repository-attached copy of the new `build/hardware` raw files. This 13 Nov session is **distinct** from the historical 11 Nov source CSV/JSON benchmark above. Do not silently add its counts to the earlier 9,000/9,000 release matrix or claim independent reproduction by GitHub CI.

The operator generated both role-specific bitstreams locally in Vivado 2025.2.1 using a single `EthAB.xpr`, verified their `build_identity.txt` top/XDC identities, programmed both Arty A7 boards, connected them directly by RJ45 and used Board A's USB UART for the physical benchmarks. Selected Vivado routed measurements for the same design tops are given above and in the [13 Nov acceptance record](VIVADO_2026-11-13_ACCEPTANCE.md); the recorded methodological PHY/CDC caveats remain open.

| 13 Nov physical session, Board A v0.9 + B v0.8B | Observed console result | Interpretation |
|---|---|---|
| Profile A (`--repeat 1 --require-all`) | 1,000 sent, 1,000 unique, no missing/duplicates/invalid/late; 10,000 FPGA-request launches/s | Smoke test passed |
| Profile B (`--repeat 10 --require-all`) | **10 of 10** runs: 1,000 sent / 1,000 unique each, zero missing/duplicates/invalid/late; 50,000 requests/s | 10,000 accepted requests/replies over finite bursts |
| Profile C initial `--repeat 10` attempt | **First two runs 0 unique/1,000 missing each; next eight runs 1,000 unique each** | **Observed intermittent startup/run-state failure**, not a strict loss-free pass. The tool correctly reported `FAIL strict loss-free requirement` |
| Profile C subsequent separate `--repeat 10 --require-all` run | **10 of 10** runs: 1,000 sent/unique each; zero missing/duplicates/invalid/late; 100,000 FPGA request launches/s | Successful finite-burst repeat; **does not erase the earlier failure** |
| Controlled **BTN0 manual-reset** first-vs-warm test: `--mode reset --profile C --cycles 10 --warm-runs 1` | **10/10** first bursts and **10/10** warm bursts passed, 40/40 UART bytes each, 1,000 unique replies each, zero missing reported | 20,000 request/reply observations in manually controlled link-ready reset experiment |

The reset tool's final console line was **`First-burst passes: 10/10`**. Per-cycle lines showed `first: PASS` and `warm: PASS` for cycles 1–10. The operator deliberately released BTN0 on **both** boards, verified link, then typed `READY` before each first burst. The raw session was written **locally** under:

```text
build/hardware/cold_start/cold_start_20261113T194925642880Z/
    results.csv
    summary.json
```

**This was *not* ten power removals/restorations.** The `READY` confirmation is not time-correlated to exact BTN0 release. The 100,000/s figure is from Board A's internal 100 MHz launch-spacing counters over finite ~10 ms bursts, **not PHY pin timestamping**, line-rate saturation, one-way processing latency or uninterrupted throughput. `unique=1000` and `missing=0` do not reveal the internal Board B FIFO overflow/debug-drop counters.

**Newly received and preserved evidence (14 Nov 2026):** The operator provided original CSV/JSON exports for the 13 Nov BTN0 reset study (10 first + 10 warm bursts) and a separate 14 Nov `power-cycle` mode study (5 first + 5 warm bursts). The files were independently parsed: in each study the CSV rows agree with the JSON rows and summary, every reported burst has 1,000 sent/unique responses, zero missing/duplicate/unexpected/invalid/late, and 40 UART bytes. All **30** bursts across these *two distinct experiments* passed, representing **30,000** reported successful request/reply pairs (20,000 reset; 10,000 power-cycle mode). The 14 Nov power-cycle-mode results were **5/5 first + 5/5 warm** passes. Original uploaded bytes are now committed without modification under [`evidence/hardware/`](../evidence/hardware/README.md), with SHA-256 checksums.

These are **operator-confirmed preparations**, not instrumented proof of physical supply removal/reprogramming, exact time to PHY link or measured wire speed. The `power-cycle` software records `READY` after operator preparation; it does not detect actual power loss or measure latency from power restoration. Preserve the earlier *failed* Profile C attempt: subsequent passes do not erase the intermittent loss observation. The raw earlier failures and fresh ordinary `v5` B/C repetitions remain separate from these newly attached reset/power-cycle files.

For exact operator actions, see [hardware test operations](TEST_OPERATIONS_GUIDE.md), [cold-start protocol](M4C_COLD_START_RELIABILITY.md), and [limitations](LIMITATIONS_V1.md).
