# Startup and reset reliability — hardware evidence (13–14 November 2026)

**System:** two Digilent Arty A7-35T FPGA boards, directly connected over 100 Mb/s RJ45; USB/JTAG/UART from the laptop. **Board A:** M4C v0.9 programmable traffic generator. **Board B:** v0.8B buffered Ethernet UDP endpoint. **Profile:** C, 10 µs target FPGA request-launch spacing, 1,000 requests per burst. **Host:** PowerShell, `scripts/m4c_cold_start.py`, Board A historically COM4.

## Experimental question

Does the existing hardware reply correctly to the *first* request burst after reset or a manually performed power cycle, and to a second *warm* burst? The operator reported that pressing BTN0 and immediately entering `READY` could produce intermittent failures. In the final trial, the operator deliberately allowed a short settling interval after restoring the boards, checking the link and/or releasing reset. **The interval was not timestamped by the script**, so no exact minimum startup delay is established.

## All supplied cold-start evidence (do not omit failed or incomplete runs)

| Evidence directory suffix (UTC) | Operator-selected mode | First burst | Warm burst | Complete? | Key outcome |
|---|---|---:|---:|---|---|
| `20261113T194925642880Z` | reset | 10/10 | 10/10 | Yes | 20 passing 1,000-packet bursts |
| `20261114T071530795020Z` | power-cycle | 5/5 | 5/5 | Yes | 10 passing bursts |
| `20261114T075322485541Z` | power-cycle | 2/5 | 2/5 | Yes | Cycles 3–5: 1,000 replies missing in *both* first and warm bursts |
| `20261114T081602749896Z` | power-cycle | 0/1 | 0/1 | No | Both attempted bursts failed, 1,000 missing per burst |
| `20261114T082003257008Z` | power-cycle | 2/3 | 2/3 | No | Third first burst: unexpected UART response header `25252525`; third warm burst: zero of expected 40 UART bytes |
| `20261114T082407890477Z` | power-cycle | **5/5** | **5/5** | **Yes** | **10/10 passing bursts; 10,000/10,000 unique replies, no missing, duplicate or invalid replies** |

The table is transcribed from the original uploaded `hardware.zip` `cold_start/*/summary.json` records and checked against the individual run records. The evidence in the archive is a mixture of completed and incomplete experiments; do not combine them into one unqualified reliability percentage. Source identifiers above preserve traceability to the local raw CSV and JSON files without introducing a second home for simulation files.

### Final successful trial details

- Test run: `cold_start_20261114T082407890477Z` (captured 14 Nov 2026).
- 5 first bursts and 5 warm bursts, **1,000 sent and 1,000 unique replies in each burst**.
- Every reported burst: missing = 0, duplicate = 0, unexpected = 0, invalid = 0, late launches = 0.
- FPGA-measured request-launch min/max spacing = **1,000/1,000 cycles** at 100 MHz, corresponding to **10 µs** and 100,000 packet *requests* per second over finite bursts.
- 40-byte UART telemetry decoded for each burst; `status = PASS`.
- The command used: `python scripts/m4c_cold_start.py --com COM4 --mode power-cycle --profile C --cycles 5 --warm-runs 1`.
- The operator reports a deliberate settling wait before entering `READY`. The script cannot prove which physical reset/power actions were performed, exactly when they happened, or the precise wait duration.

## Reproduction and human interaction

1. Connect each board to USB; connect **one direct Ethernet cable between the two FPGA RJ45 sockets**. Confirm the actual JTAG identities and Board A UART COM port; do not assume COM4 on other machines.
2. Program **Board A M4C v0.9** and **Board B v0.8B** using their matching bitstreams. Do not interchange images.
3. In PowerShell, from the **repository root**, run the command above.
4. For each prompted cycle, perform the selected mode: **power-cycle means physically remove and restore both boards' power and reprogram their volatile FPGA bitstreams if necessary**; **reset** means press and release BTN0 on both boards without interrupting power. Do not substitute one for the other.
5. Confirm both PHY links are established and allow a deliberate settling interval (initial pragmatic operating procedure: **5 seconds after link and reset release**). This is a conservative *test condition*, **not** a measured PHY/link-ready time.
6. When the Python script displays `type READY then Enter`, type `READY` **at that prompt**, then press Enter. Do not enter `READY` as a fresh PowerShell command after the script ends.
7. After the script has run the first and warm bursts, repeat for the next cycle. Retain `build/hardware/cold_start/<run-id>/results.csv` and `summary.json` without overwriting previous experiments.

## Interpretation and remaining limitations

This final run confirms **five manually controlled first-burst tests and five warm-burst tests succeeded** on the stated setup. Its contrast with earlier failures **supports**, but does **not prove**, the hypothesis that premature traffic initiation or insufficient interface/reset settling caused the intermittent startup behaviour. In the failed 07:53 experiment, warm runs failed alongside first runs: this may indicate a persistent not-ready state, not merely a one-off first-packet race. The 08:20 experiment additionally produced UART protocol/acquisition errors. No root cause has been isolated.

The script does **not** automatically verify electrical power cycling, PHY state, exact reset-to-ready latency, link negotiation duration, power-on recovery threshold, or wire-level timestamps. An operator-selected `power-cycle` label is not independently audited. This must **not** be described as fully autonomous cold-start reliability, an uptime guarantee, a maximum sustainable Ethernet packet rate or proof of one-way processing latency.

## Publication and close-out

Keep this record under `docs/`. Keep existing simulation wave configuration under `sim/waves/`, RTL and testbench under `rtl/` and `tb/`, functional test code under `tests/`, PowerShell/Python runnable harness under `scripts/`, and generated captures under ignored `build/hardware/`. No redundant `vivado/waveforms/` or second test-code tree is needed. A compact machine-readable trial index lives in [the startup evidence index](../evidence/m4c/startup_reliability_2026-11-14.csv).

**Recommended project disposition:** the bounded manual startup procedure is documented and final Profile C trial passed; leave automatic link-ready gating, machine-timed startup characterization, and broader reliability qualification as **optional future hardening**, not release claims or mandatory follow-on scope. No RTL or bitstream changes were made for these tests.
