# FPGA Low-Latency Ethernet Processor — Future Improvements Register

**Project:** Dual Arty A7-35T 100 Mb/s low-latency synthetic-market-data processing demonstrator  
**Reference release:** v1.0, hardware validated 11 November 2026  
**Register date:** 11 November 2026  
**State:** **Backlog only — no work authorised or scheduled**  
**Release policy:** v1.0 is complete for its agreed *portfolio demonstrator* scope. The items below are possible future projects, **not release blockers**. Reopen only for a concrete client requirement, relevant job interview/portfolio need, or a separately scoped engineering project.

**13 November operator addendum:** 10 manual BTN0 reset cycles passed both first and warm Profile C bursts (20,000 request/reply observations), with the Ethernet link confirmed before the control command. This does **not** discharge F05: electrical power-cycle recovery, cold link negotiation timing, cable-reconnect stress and long soak tests remain unverified. The pre-existing intermittent initial Profile C run (2/10 failures in one attempt) must remain in the evidence record.

## Verified v1.0 baseline to preserve

- Platform: two Digilent **Arty A7-35T** boards, **100 Mb/s MII** direct Ethernet. Board A runs v0.9 M4C hardware-paced generator; Board B runs v0.8B UDP endpoint.
- At low sequential load, measured median **physical two-board RTT**: v0.7 ≈ **12.75 µs**; v0.8B ≈ **12.85 µs**. RTT includes Ethernet transfers, CDC, and processing; **not** core-only latency.
- Original v0.6 report path mean RTT ≈ **1,228.37 µs**, reduced to ≈ **12.746 µs** in v0.7 by removing UART-first gating.
- FPGA-native M4C: **9/9 runs, 9,000/9,000 valid responses**, three 1,000-packet bursts per profile at measured request-launch spacings of 100 µs, 20 µs and 10 µs. Additional 1,000/1,000 smoke test.
- The highest **tested loss-free request-launch rate** is **100,000/s for finite ~10 ms bursts**; it is **not** an independently measured PHY line-rate figure, indefinitely sustainable throughput or maximum possible throughput.
- Routed implementation met reported constrained setup/hold timing; **formal CDC closure and complete external MII PVT timing qualification remain open**.
- Synthetic fixed-format IPv4/UDP protocol, single-symbol top-of-book; **not** an exchange-standard feed, production trading application or general networking stack.

Keep all future claims benchmark-specific. Preserve the v1.0 source, evidence, Vivado version and release tag for side-by-side comparison.

## Priority and feasibility legend

- **P1 — Engineering hardening:** highest value if an industrial client requests a more robust *100 Mb/s* design.
- **P2 — Capability expansion:** interesting standalone enhancement, but not required for current portfolio.
- **P3 — New platform/product:** substantial scope or new hardware; treat as a separate contract/project.
- **Existing A7:** technically plausible on the two current Arty A7-35T boards, with verification and resource/timing constraints. **New hardware:** current on-board PHY cannot meet target.
- **Effort** is a very rough engineering estimate, excluding unexpected debugging, procurement and formal certification; it is not a schedule commitment.

## Future work register

| ID | Priority | Improvement | Why it matters / present gap | Hardware | Rough effort | Demonstrable acceptance criterion |
|---|---|---|---|---|---|---|
| **F01** | **P1** | **CDC and reset-domain closure** | Multi-bit CDC-6, CE-controlled CDC-15, Gray-pointer skew, mailbox data stability, first-word-fall-through memory access and reset-release assumptions still require rigorous review. Zero CDC-1 warnings alone is insufficient. | Existing A7 | 3–7 days | Review every flagged crossing; justify or redesign each; add suitable Gray-bus skew/datapath constraints, reset-order tests, CDC assertions/formal checks; zero unexplained critical findings and documented waivers only. |
| **F02** | **P1** | **Complete MII PHY clock / I/O timing** | Routed setup/hold margins do not establish external MII setup/hold across PVT, clock duty cycle, output skew or 25 MHz PHY reference-clock quality. | Existing A7 | 2–5 days | Derive input/output-delay budgets from DP83848J + board timing; improve/verify 25 MHz clock generation if needed; post-route timing covers all MII paths, with PHY waveform observations where available. |
| **F03** | **P1** | **Expose internal loss and occupancy counters** | v0.8B counts RX overflow/invalid frames and debug drops internally, but M4C cannot read these; observed missing replies cannot be assigned to a particular failure stage. | Existing A7 | 2–4 days | Host-readable snapshot with RX/FIFO/TX/diagnostic counters, wrap/saturation semantics, reset behaviour; intentional FIFO overflow test yields matching counters and observed losses. |
| **F04** | **P1** | **True sustained-rate and saturation benchmark** | Current 100k/s benchmark measures request-launch spacing over finite ~10 ms bursts; no indefinite throughput boundary, wire-timestamping or under-load latency distribution. | Existing A7 | 3–7 days | Run multi-second/minute trials and swept packet intervals; instrument packet TX start/completion and reply receive times using FPGA clocks; publish loss-vs-rate, goodput and latency percentiles with matching source/response counters. |
| **F05** | **P1** | **Long-duration reliability / reset recovery** | No hour-scale soak, repeated cable disconnect/reconnect, brownout/reset stress, temperature variation, or power-cycle recovery matrix. | Existing A7 | 2–5 days | Repeatable soak/100+ reset and link recovery runs with zero unexplained hangs; report errors/recovery time and scope; no unsupported lifetime reliability claims. |
| **F06** | **P1** | **Automated property-based verification / CI** | Directed simulations and 52 Python tests are useful but not exhaustive for simultaneous FIFO full/empty, resets, malformed frames and backpressure. | Existing A7 | 3–7 days | Formal/assertion properties for FIFO order, no duplication, no overwrite and reset; randomised independent clocks, jitter, errors and long bursts; reproducible CI artifacts and coverage report. |
| **F07** | **P2** | **Standards-oriented Ethernet/IP/UDP handling** | Present RTL supports a narrow fixed UDP envelope; no full ARP/ICMP/DHCP handling and incomplete standard packet/header/checksum coverage. | Existing A7 | 1–3 weeks | Interoperate with a standard PC NIC using unicast ARP+UDP, variable frame lengths and verified IPv4/UDP checksums; reject malformed/truncated frames and include independent packet-capture evidence. |
| **F08** | **P2** | **Realistic feed parsing and multi-symbol order book** | Current input is a synthetic 16-byte record and one-symbol top-of-book, rather than standard multicast market data or multi-instrument event logic. | Existing A7 (small scoped version) | 1–3 weeks | Document a legally usable public/synthetic protocol subset; parse add/update/delete/order events, maintain N configurable symbols, detect gaps/reorders, compare against reference software. |
| **F09** | **P2** | **FIFO memory / throughput optimisation** | Current 16-entry async RX/TX FIFOs use distributed memory, 0 BRAM inferred; area and speed trade-offs are not optimised. | Existing A7 | 2–5 days | Compare current implementation with Artix-7-compatible `XPM_FIFO_ASYNC` or inferred BRAM and deeper FIFOs; report latency, LUT/FF/BRAM, throughput and CDC impact, retaining exact behaviour. Larger BRAM FIFOs are not automatically better for shallow low-latency queues. |
| **F10** | **P2** | **Low-latency bypass and queueing under load** | v0.8B adds ≈0.10 µs sequential RTT over v0.7; burst latency distribution is unmeasured. | Existing A7 | 3–7 days | Compare guarded empty-queue bypass or shallower FIFO architecture against v0.8B; measure low-load RTT *and* under-load percentiles, delivery and timing; no ordering violations. |
| **F11** | **P2** | **Hardware observability and operational controls** | Bench flow depends on push-button reset, static configuration and 40-byte UART summary. | Existing A7 | 3–7 days | Version/status registers, clean configuration/reset FSM, link-state indication, fault counters and capture of timing histograms, with a documented host control protocol. |
| **F12** | **P2** | **Precise one-way timestamps / PTP study** | Two-board RTT is not one-way or core-only latency; deterministic clock alignment and hardware timestamps are absent. | Existing A7 for internal probes; may require timing-capable external equipment for absolute one-way | 1–2 weeks | Latency measured at named RTL/PHY boundaries; specify clock error budget; when using IEEE 1588/PTP, demonstrate actual synchronisation accuracy rather than assuming it. |
| **F13** | **P3** | **Gigabit / 10 GbE architecture** | The on-board Arty A7 PHY is **10/100 Mb/s MII**, so 1G/10G cannot be obtained by editing RTL alone. Real high-speed/HFT systems typically require different Ethernet PHY/MAC and capable FPGA/I/O. | **New hardware required** | Separate project, multi-week | Select compatible hardware and MAC/PHY, recreate controlled testbench and host/network test path, establish sustained wire-rate goodput and qualified timing. |
| **F14** | **P3** | **Redundancy / failover / security hardening** | No dual-feed handling, redundancy, state recovery, robust field-update controls or attack-oriented malformed traffic handling. | Existing A7 for a small proof-of-concept; production deployment likely new platform | Separate project | Define fault/security model and demonstrate failover/detection limits, secure configuration/update strategy and auditable failure behaviour. |

## Recommended order if the project is ever reopened

**First industrial hardening sprint (best value from existing boards):** F01 → F02 → F03 → F04. This addresses the most important gaps between a promising laboratory demonstrator and evidence suitable for a more demanding client review.

**Second sprint (if robustness is a requirement):** F05 + F06, then optionally F09 to evaluate alternative FIFO implementations.

**Choose one application direction, not all:** F07 for Ethernet/IP contracting; F08 for market-data / trading; F12 for precision networking/timing. Avoid building a general-purpose MAC, PTP engine, complete order book and 10 GbE implementation as one unfunded portfolio exercise.

**Do not reopen simply to improve the existing headline number.** The current v1.0 demonstrates 100k *request launches*/s in measured short bursts with 9,000/9,000 replies. A credible study showing *where* throughput stops and *why* is worth more than claiming an unverified larger number.

## Proposed GitHub issue seeds

If a specific enhancement becomes active, convert only that item into a GitHub issue (labels `future`, `research`, `hardware`, and its `Fxx` ID). For each issue capture: motivation, frozen v1.0 baseline, altered modules/XDC, verification plan, measured acceptance criteria, recorded regression delta, and a stop decision. **Do not mark items as implemented until evidenced.**

## Decision record

| Date | Decision |
|---|---|
| 2026-11-11 | M4C's three hardware profiles completed: 9/9 runs with 9,000/9,000 validated replies. Technical development closes at v1.0 for the portfolio scope. |
| 2026-11-11 | Register F01–F14 for possible future client-led improvements. None block v1.0 GitHub/Upwork publication. |
| 2026-11-11 | Next active project: **FPGA DSP and Digital Communications**. Do not initiate M4D unless a separate requirement justifies it. |

## Technical reference points (for future revisits)

1. AMD **Vivado UG906**, CDC rules and precedence: `CDC-6` is a multi-bit synchronised-bus warning; `CDC-15` is a clock-enable-controlled crossing warning. [UG906, 2025.2](https://docs.amd.com/r/2025.2-English/ug906-vivado-design-analysis/Understanding-the-Clock-Domain-Crossings-Report-Rules).
2. AMD **Vivado UG903**, CDC bus-skew and timing constraints for Gray-coded asynchronous crossings: [UG903](https://www.xilinx.com/support/documents/sw_manuals/xilinx2022_2/ug903-vivado-using-constraints.pdf).
3. AMD **UG953**, 7-Series `XPM_FIFO_ASYNC` options, block/distributed RAM, reset-busy and read-mode behaviour: [UG953, 2024.2](https://docs.amd.com/r/2024.2-English/ug953-vivado-7series-libraries/XPM_FIFO_ASYNC).
4. Digilent **Arty A7 Reference Manual**, DP83848J 10/100 Ethernet PHY and MII interface: [Arty A7 reference](https://docs.rs-online.com/1469/0900766b8173b5c4.pdf).

*Estimates and suggested work items are engineering proposals, not verified defects beyond those explicitly documented in the v1.0 release. The register intentionally adds no new performance claims.*
