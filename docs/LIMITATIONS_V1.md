# Release boundaries and known limitations (v1.0)

1. **Synthetic protocol only:** fixed laboratory IPv4/UDP/MII envelope and original 16-byte market-data format. Not a full Ethernet MAC, complete trading-feed implementation, TCP/IP network stack or exchange-ready infrastructure.
2. **Finite-rate evidence:** highest tested loss-free profile is 100,000 packet requests/s for 1,000 packets per run, repeated three times. Not wire-level timestamped, uninterrupted long-duration, line-rate or maximum-performance qualification.
3. **Latency definition:** approximately 12.75 us (v0.7) / 12.85 us (v0.8B) median *two-board RTT* at low sequential load, including PHY transfers. Not core-only or one-way processing time, and not measured during M4C bursts.
4. **Clock crossings:** FIFO pointers are Gray-coded and synchronised, but multi-bit CDC observations, bus skew, reset release, async mailbox timing and full data coherency were not formally closed. Vivado CDC-15 and some CDC-6/methodology warnings remain. Add explicit Gray-pointer skew constraints and deeper validation for product use.
5. **I/O constraints:** positive constrained routed setup/hold margins do not prove all external MII PHY waveforms and asynchronous interfaces under PVT. Further measurement, input/output delay modelling and timing margin are needed.
6. **No overflow visibility in benchmark:** Board B RTL counts RX overflow and UART debug drops, but M4C telemetry does not export those counters. No real-hardware FIFO occupancy/overflow figures are claimed.
7. **No BRAM in v0.8B:** 16-deep RX/TX FIFO memory mapped primarily to logic/register resources. Resource efficiency could be improved in a separate commercial optimisation project.
8. **Link and reset dependence:** hardware startup requires an established physical 100 Mb/s link and released/reset synchronisation before benchmark commands. Early runs with the boards not directly connected returned no replies.
9. **Reliability and security:** no EMI/temperature/radiation/long soak, formal verification, compliance, packet-shaping, security hardening or production fault-injection claims. This is a bounded engineering portfolio demonstrator.
10. **Public release hygiene:** review licensing/provenance, filenames, comments and hardware photographs before publication. Raw Vivado reports were excluded because they included machine-specific metadata; anonymised aggregate metrics are used instead.

**Stop rule:** Record these as limitations. Do not extend into M4D, new Ethernet features or a broad unmeasured product claim. Project 1's technical development is concluded after M4C.
