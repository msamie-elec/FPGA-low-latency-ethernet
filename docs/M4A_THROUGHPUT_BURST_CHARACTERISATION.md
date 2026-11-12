# M4A — Baseline throughput and burst characterisation (v0.8A)

**Release status: host measurement instrumentation; verified v0.7 FPGA RTL is unchanged.**

## Engineering problem

The user-verified v0.7 two-Arty-A7 experiment completed 200/200 mixed transactions, with
mean hardware round-trip times around 12.75 microseconds. The paired 200-row comparison
against v0.6 verified all response bytes identical and documented a 99.0% reduction in
mean valid-report RTT. This is **round-trip latency for one outstanding transaction**,
NOT maximum sustainable packet rate or burst tolerance.

Board B v0.7 (`rtl/ethernet_udp_a7_lowlat.sv`) uses an inbound single-entry
25-to-100 MHz mailbox (`mii_udp_rx`), a serial 16-byte parser, a one-entry outbound
100-to-25 MHz mailbox and an independent UART FSM. The Ethernet response is launched
in parallel with UART, but the upstream RX acknowledgement is withheld until BOTH
Ethernet TX and UART finish. One normal 14-byte UART response at 115200 baud takes
approximately 14*10/115200 = **1.215 ms** to serialize. Continuous arrival at the
minimum 100-Mbps Ethernet frame spacing (~6.72 microseconds) therefore exercises a
known single-entry bottleneck. The RX parser flags a new valid frame as rejected while
its mailbox is occupied; it does not queue that record.

Do **not** interpret a run with packet drops as proof that a particular packet was lost
inside the FPGA: Windows scheduling, OS send/receive buffering, the USB NIC and PHY also
participate. This measurement stage establishes observed host-driven delivery only.

## Test architecture (use the ALREADY-VERIFIED v0.7 Board B)

```
ASUS laptop [192.168.77.1/24]
  |  Python UDP open-loop bursts, port 5000
  |  TP-Link UE300C USB-C -> RJ45 / Cat6 (100 Mb/s link)
  v
Arty A7 Board B ONLY, v0.7 on V:\
  |  MII RX 25MHz -> single mailbox -> 100MHz market-data processor
  |  -> Ethernet UDP reply, src 192.168.77.2:5000
  v
Laptop UDP listener on 0.0.0.0:5001 (receives broadcast)
  |  per-sequence correlation + Python reference + CSV + JSON
```

**Physical configuration change from M3:** Disconnect the direct RJ45 cable between
Boards A and B. Connect UE300C **directly to Board B** with the Ethernet cable.
Keep Board B powered and programmed with its verified v0.7 **V:** bitstream.
Board A need not be connected for M4A. Do not change the bitstream or RTL.

Verify `Get-NetAdapter` shows Ethernet `Up` at 100 Mbps. Only the TP-Link wired
interface should have IPv4 address 192.168.77.1 and subnet 255.255.255.0.
Windows reporting "No Internet" on this direct link is expected. Firewall may need
an adapter-scoped inbound UDP-5001 rule if responses are blocked; don't disable the
whole firewall. Close other applications listening on UDP 5001.

## Traffic and oracle

Each IPv4 UDP packet has a fixed 16-byte synthetic record:
`B, symbol=1, unique 32-bit sequence, bid price=10000, quantity=1, reserved=0`.
This is deliberately stateless with respect to missing records *provided Board B was
reset* (no retained ask value). Each accepted request should return a 14-byte report
`R + sequence + bid 10000 + ask 0 + signal 0`. The response echoes sequence; therefore
missing, duplicate and stale replies are identifiable even when requests are dropped.
The TCP/IP stack is not involved; no ping or ARP support is required.

### First calibrate paced traffic

From a NEW directory holding this M4A package (example short drive `W:`), run:

```powershell
subst W: (Get-Location).Path
Set-Location W:\
$env:Path = "C:\Programs\msys64\ucrt64\bin;$env:Path"
python -m pytest -q tests
```

After connecting the UE300C to **Board B**, **press/release BTN0 on B before each run**
and confirm its LD4 heartbeat and Ethernet link:

```powershell
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 5 --drain-s 2 --require-all --csv build/hardware/m4a_gap5.csv
```

A 200/200 paced result calibrates the host test path. If it fails, do not interpret
fast-burst losses until the cable, programming, port 5001 firewall and link are checked.

### Then characterise load, not yet line-rate

After **resetting Board B again** before each independent command:

```powershell
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 1 --csv build/hardware/m4a_gap1.csv
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 0 --csv build/hardware/m4a_gap0.csv
python scripts/m4a_analyse_probes.py --out build/hardware/m4a_probe_matrix.csv build/hardware/m4a_gap5.summary.json build/hardware/m4a_gap1.summary.json build/hardware/m4a_gap0.summary.json
```

**These command lines are intended to be run individually, with a BTN0 reset and
link settle between runs.** Do not concatenate them unattended. At `--gap-ms 0`,
Python makes best-effort consecutive `sendto()` calls; the OS/NIC may buffer or
coalesce packets, so it is **not a calibrated hardware wire-rate generator**.
For sub-millisecond intervals Windows `time.sleep()` is not sufficiently precise.
Inspect actual observed send gaps in the generated JSON, not just the requested gap.

Each `*.csv` records each sent sequence, expected report, any valid UDP reply and
host-observed round-trip time. Each `*.summary.json` reports sent/valid/missing,
corrupt/duplicate/unexpected counts, host send-span and measured host send gaps.
Missing responses are expected at sufficient load in this single-mailbox design;
that is an experimental observation, not an RTL pass/fail signal. Use `--require-all`
only for the low-rate calibration or after implementing buffering.

## Next: M4B true buffered streaming architecture (not implemented in M4A)

1. **RX ingest:** strict wire-validating parser at PHY RX_CLK (25 MHz) -> dual-clock
   128-bit asynchronous FIFO (initial depth 8 or 16) with Gray-coded pointers,
   pointer synchronizers and explicit `full` drop accounting. Source registers stay
   stable through CDC. No multi-bit asynchronous sampling without proven protocol.
2. **Processing:** 100 MHz ready/valid pipeline reads FIFO, performs the 16-byte
   feed parse, and writes response metadata to a separate bounded queue. Preserve
   response order or document a sequence-ID reorder scheme. No acceptance of a
   frame unless there is a safe response storage path.
3. **TX:** 100-to-25 MHz bounded response FIFO, packet builder/FCS and existing
   IOB-register output timing. Maintain at least 12-byte IFG; no UART dependency.
4. **Telemetry:** UART is *observability only*: rate-limited queue or aggregate
   counters with explicit debug-drop status. UART shall not prevent Ethernet RX
   mailbox/FIFO release or Ethernet TX. Diagnose overflow distinctly from a
   malformed Ethernet frame, and distinguish PHY CRC rejections.
5. **Board A:** new FPGA-native programmable burst source (not host Python), with
   offered-packet count, sequence checker, timeout/corruption/duplicate counters,
   finite-depth reply FIFO, and hardware histogram of RTT measured in Board A's
   100 MHz domain. Hardware stimulus removes Windows pacing from the critical path.
6. **Verification:** reset under traffic, FIFO wrap, simultaneous read/write,
   full/empty boundary, clock-ratio/phase variation, backpressure, lost packets,
   malformed FCS, min IFG, 10/100 Mb/s link changes, packet correctness, CDC
   report, and timing with source-synchronous PHY I/O constraints. Run exact 200
   accepted packets at 5ms gap first; then controlled bursts with declared drop
   policy; finally report sustained packets/s and latency histograms.

**Theoretical line framing upper bound for minimum-size 100-Mbps Ethernet frames:**
(8-byte preamble/SFD + 64-byte frame/FCS + 12-byte IFG) = 84 bytes per frame;
100e6/(84*8) ≈ 148,810 frames/s. This is *not* a measured FPGA rate, and software
UDP transmission may be slower. For our 16-byte record and minimum-frame padding,
this is an applicable wire-framing upper bound, not a throughput commitment.

## Evidence and source freeze

* `docs/baselines/m2c_v06_hardware_rtt_200.csv`: v0.6 physical Board A counter
* `docs/baselines/m3_v07_hardware_rtt_200.csv`: user-uploaded v0.7 physical Board A counter
* `scripts/compare_m3_latency.py`: paired 200-run comparison
* `scripts/m4a_burst_probe.py`: host-driven packet acceptance probe
* `scripts/m4a_analyse_probes.py`: acceptance matrix
* `scripts/check_m4a_source_freeze.py`: verifies all RTL/XDC hashes against original v0.7

**No v0.8 FPGA bitstream is present. No new FPGA RTL has been implemented or
validated in this phase.** Future M4B development must be separate from the
v0.7 success baseline, with full Icarus+Vivado+physical acceptance gates.
