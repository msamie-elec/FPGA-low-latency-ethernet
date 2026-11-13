# Dual-board Vivado GUI acceptance — 13 November 2026

**Scope:** One Vivado GUI project, two *independent* Artix-7 bitstreams. This record documents the **user-observed Windows Vivado 2025.2.1 acceptance run**, using the locally extracted `Low-latency-ethernet_v2` working copy (project `EthAB.xpr`). These screenshots/results **are not a fresh execution of the later GitHub branch-head project generator**; GitHub Actions cannot run commercial Vivado. The records below are manually transcribed observations, not checked-in raw machine-specific routed reports.

## Physical/configuration model

- **Board A:** Digilent Arty A7-35T (`xc7a35ticsg324-1L`), M4C traffic generator + scoreboard; synthesis top `ethernet_generator_a7_m4c`; constraint set `constrs_board_a`; active local XDC `ethernet_m4c_generator.xdc`.
- **Board B:** a **second** Arty A7-35T, M4B buffered UDP endpoint; top `ethernet_udp_a7_buffered`; constraint set `constrs_board_b`; active local XDC `ethernet_m4b_endpoint.xdc`.
- A **single** GUI project contains both sources and `tb_m4c_board_pair` simulation top. Only the selected synthesis top and matching XDC are implemented at a time. The simulation passed three hardware-paced profiles of 8 simulated requests apiece; this is not the same as repeating the physical 9,000-response benchmark in this acceptance session.
- The physical demonstrator requires both boards connected by RJ45, with distinct USB/JTAG connections. Generating both bitstreams does not require two connected boards.

## Routed design and output evidence

| Observed metric | Board A — M4C generator | Board B — M4B endpoint |
|---|---:|---:|
| Synthesis | complete | complete (6 FIFO warnings retained) |
| Implementation | complete | complete |
| Setup WNS | +0.576 ns | +0.737 ns |
| Setup TNS | 0 ns | 0 ns |
| Hold WHS | +0.052 ns | +0.046 ns |
| Hold THS | 0 ns | 0 ns |
| Pulse-width worst slack | +4.500 ns | +4.500 ns |
| Failing timing endpoints | 0 | 0 |
| Final implemented DRC violations | 0 | 0 |
| Estimated post-route on-chip power | 0.080 W | 0.083 W |
| Bitstream | generated + archived | generated + archived |
| Archive date | 12 Nov 2026 | 13 Nov 2026 |

**Archived in the user's local working tree, not Git:** `build/out/A/board_A.bit`, `build/out/B/board_B.bit`, each with `build_identity.txt` and routed `.rpt` files. Vivado Tcl reported `ARCHIVED board A...` and `ARCHIVED board B...`, and Windows Explorer showed each bitstream (~2,141 KB). These artifacts are ignored by Git and were not uploaded to this PR. Power numbers are **estimates**, not board-level measurements, and not proofs of energy efficiency.

## Constraint-set failure detected and resolved during acceptance

Initially Board B had `constrs_board_b` selected by *name* but its effective constraint compile order was **empty**. The unconstrained run was *invalid* despite successful placement/routing: 22 unassigned I/O pin locations, 22 default I/O standards, 6,124 clockless registers, 13,610 unconstrained internal endpoints, `inf` setup/hold slack, and critical `TIMING-17` methodology findings. The incorrect ~10.193 W low-confidence power estimate from that unconstrained run **must not** be quoted.

The user reattached the corrected **Board B** XDC, reset the run(s), re-synthesized and implemented. The corrected implementation reported finite slack, zero missing internal clocks, zero unconstrained internal endpoints, zero DRC violations and 0.083 W estimated on-chip power.

The GitHub branch now includes **separate generated GUI XDC copies** and a selector/generator guard that checks effective XDC membership. The guard and generated-copy flow have passed CI Tcl mocks; **their exact behaviour still needs a fresh Windows Vivado test using the latest branch**. Always check `report_compile_order -constraints` before building; seeing a constraint-set name alone is insufficient. Never silence `NSTD-1`, `UCIO-1` or `TIMING-17` to force an unsafe bitstream.

## Remaining timing, I/O and CDC findings

| Report | Board A | Board B |
|---|---|---|
| Timing check: no input delay | 2 ports (`btn0`, `uart_rx_i`) | 1 port (`btn0`) |
| Timing check: no output delay | 7 reported (6 standard + `eth_ref_clk`) | 7 reported (6 standard + `eth_ref_clk`) |
| Timing methodology | 13 `TIMING-18` instances | 12 `TIMING-18` instances |
| No clock | 0 | 0 |
| Unconstrained internal endpoints | 0 | 0 |
| CDC tool-classified unsafe / unknown | 0 / 0 | 0 / 0 |

The six standard Board B output-delay findings cover `eth_rstn`, `led[0:3]` and `uart_tx_o`; `eth_ref_clk` is separately listed as a timing-clock-related output. These are not all equivalent: button/UART/LED and PHY clock/reset signals need protocol-appropriate review rather than arbitrary `set_input_delay`/`set_output_delay` entries. External PHY timing and reset sequencing have **not** been fully qualified.

**Board B routed CDC (13 Nov):** 245 report-detail rows: 7 `CDC-6` Gray/multi-bit sync warnings, 232 `CDC-15` clock-enable-controlled FIFO data warnings, 4 `CDC-3` one-bit sync info, 2 `CDC-9` async reset sync info. Clock-pair summary shows 303 endpoints tool-classified safe, 0 unsafe, 0 unknown and no waived endpoints; these counts describe different report granularity and should not be added together. The architecture uses two-stage Gray-pointer synchronization in RX/TX FIFOs. **Vivado's “Safe” classification is not proof of stable multi-bit data coherency, controlled FIFO read latency, reset release, metastability MTBF, or Gray-bus skew closure.**

The six remaining synthesis warnings for Board B are from `m4b_async_fifo`: possible set/reset simulation-synthesis mismatch (`Synth 8-7137`) and memory inferred as registers rather than BRAM (`Synth 8-4767`). The memory mapping is consistent with the current small FIFO design but does not resolve the mismatch concern. Do not silently waive these warnings or alter hardware-validated RTL solely to suppress them.

## Next validation gates (not part of this recorded pass)

1. Run the **latest PR branch** `vivado/create_project.cmd` into a **new short path** and prove the regenerated project reopens with one effective XDC per board; do not overwrite the locally archived acceptance `v2` outputs.
2. Run combined GUI simulation, then build both tops; inspect constraints, compile order, I/O locations, DRC, routed setup/hold/pulse-width and CDC after each build. Do not treat Tcl mock/CI as a Vivado run.
3. If continuing engineering qualification, model PHY setup/hold input/output budgets and reset/clock requirements; validate Gray-bus skew and FIFO data stability with appropriately scoped constraints and tests; repeat place/route and bitstream creation after any change.
4. For *new* bitstreams, run controlled two-board physical checks before asserting that they reproduce the previously measured RTT/burst data. Review IP/board-constraint provenance and image/file metadata before making the repository public.

**Release interpretation:** successful **local FPGA builds and two separately archived bitstreams**, with transparent CDC/PHY/FIFO qualifications. Not a formal CDC signoff, external electrical signoff, or a new physical benchmark result.
