# M2C Architecture and Verification Plan — Two-Arty-A7 UDP Loop

Date: 11 November 2026. **New M2C generator is an engineering candidate, NOT yet RTL- or hardware-verified.** Only Board B's unchanged v0.5A design was physically tested (200/200, evidence in `docs/evidence`).

## High-level objective

Construct a reproducible, stand-alone two-FPGA Ethernet experiment. One Arty A7 serves as a programmable traffic source and single-flight response checker; the other runs the existing v0.5A market-data processor. A local 100-MHz timer on Board A records FPGA-clock round-trip duration without relying on host serial latency or syncing clocks across boards. The architecture provides a stepping stone to real latency/throughput benchmarking, NOT that benchmark itself.

```
 Host UART -> Board A uart_rx -> (100MHz) record generator / request timestamp
                                    | stable 128-bit toggle mailbox
                                    v
                   TX 25MHz mii_feed_tx -> A PHY -> RJ45 Cat6 -> B PHY
                                                                |
                                 B 25MHz mii_udp_rx -> B 100MHz processing
                                                                |
                                                  B UART first (existing v0.5A)
                                                                |
              B 25MHz mii_udp_tx <- B 100MHz response + mailbox
                    |
                  RJ45 -> A PHY -> A 25MHz mii_reply_rx
                                      | stable 112-bit + 4-bit mailbox
                                      v
                  A 100MHz capture -> local payload validation -> RTT latch
                                      |
                         A UART telemetry 24 bytes -> host Python oracle/CSV
```

## Hardware

- Board A: one Digilent Arty A7-35T; `ethernet_generator_a7_m2c` top, MII PHY + UART RX/TX.
- Board B: another Digilent Arty A7-35T; **unchanged** `ethernet_udp_a7` v0.5A top, previously physically verified.
- Each board separately powered/programmed via USB. USB supplies JTAG plus a dedicated UART COM port. Both boards must be selected by correct JTAG cable serial.
- Direct, standard Cat5e/Cat6 patch cable between the RJ45 sockets; DP83848J PHY supports auto-MDIX and 10/100 auto negotiation. No Ethernet switch or laptop USB-to-Ethernet dongle required in this topology.
- Clocking: separate 100-MHz local oscillators, each board derives a 25-MHz PHY reference, receives independent PHY RX_CLK and TX_CLK. No shared FPGA clock and no one-way latency measurement in this prototype.

## On-wire protocol (purpose-built testbench, not a general MAC/IP stack)

Two Ethernet directions use destination MAC broadcast `ff:ff:ff:ff:ff:ff`, destination IP `192.168.77.255`, 100Mbps MII, fixed IPv4 header with no options, zero IPv4 UDP checksum, FCS/CRC32.

| Field | Board A request | Board B response |
|---|---|---|
| Source MAC | `02:11:22:33:44:66` | `02:11:22:33:44:55` |
| Source IP | `192.168.77.3` | `192.168.77.2` |
| UDP source port | 5002 | 5000 |
| UDP destination port | 5000 | 5001 |
| UDP payload | 16-byte synthetic record | 14-byte `R` or one-byte `I`/`E` |
| FCS | CRC32 over Ethernet header/data/padding | CRC32 over Ethernet header/data/padding |
| Total frame | 8-byte preamble/SFD + 60 MAC bytes + 4 FCS = 72 | same |

A record contains: `[type:1][symbol:1][sequence:4 big-endian][price:4][quantity:4][reserved:2 zero]`.

Board A's counter begins at sequence **1** after BTN0 reset. The host selects one of three one-byte commands:

- `S` (`0x53`): normal update with type `B` for odd sequences, `A` for even; symbol 1.
- `I` (`0x49`): identical record but symbol 2; Board B must ignore.
- `E` (`0x45`): record type `X`, intentionally malformed; Board B must return error.

In every case, sequence increases monotonically on A. The price is `10000 + (sequence & 15)`, quantity 1 and reserved bytes zero. This deterministic pattern permits exact checking with the original Python `TopOfBook` reference. The current hardware is intentionally **stop-and-wait, one outstanding packet**. A host command sent while A is processing a prior command may be ignored; the supplied Python script sends the next command only after the previous 24-byte telemetry is received.

## CDC and backpressure protocol

Board A has three functional domains (system 100MHz, PHY TX 25MHz and PHY RX 25MHz). It uses separately synchronised toggle request/acknowledge pairs rather than sampling unqualified pulses. `mii_feed_tx` registers the full 128-bit request payload only after its request toggle has crossed a two-FF `ASYNC_REG` chain; the 100-MHz producer holds the bus stable until TX ack. The receive path follows the inverse: `mii_reply_rx` holds its 112-bit response and 4-bit length stable until system-domain acknowledgement. The system-domain control *first* registers the entire response/length, and only on a subsequent clock performs sequence/length/type checks. This staging avoids the unsynchronised-bus-to-FSM-control CDC-1 pattern encountered in M2B v0.5.

These multi-bit mailbox CDC structures may produce `CDC-15` reports in Vivado. They require evidence of hold-time, correct acknowledgement order, reset conditions and clock-phase stress before production sign-off. The structural Python checks do **not** prove metastability immunity or bus coherency.

Each board's TX MII outputs change on PHY TX_CLK falling edges with Vivado `IOB TRUE` requested; the PHY samples at rising edges. Constraints are carried forward from v0.5A (MII receive input 10–30ns and TX output max 10ns, min 0ns; provisional and board-skew unqualified). The 25-MHz reference clock is a fabric divider, requires waveform/electrical qualification. Never claim sign-off based solely on positive internal WNS.

## Board A host UART telemetry (24 bytes, fixed length)

```
offset   width   field
0        1       ASCII 'M' (0x4d) frame marker
1..4     4       sequence, big-endian
5        1       status: 'P' correct; 'S' wrong response; 'T' timeout
6..19    14      UDP response bytes (one-byte replies padded with zeros)
20..23   4       100-MHz cycle duration, big-endian
```

`P` means the returned code/length was compatible with the requested command and, for `R`, that its sequence matched. Python independently replays every record through `software/model.py`, verifies the full 14-byte content for reports or one-byte `I/E`, and logs a CSV. The MII reply receiver checks Ethernet FCS and supported addressing before delivering a packet; a CRC failure will cause a timeout rather than a falsely accepted response. Timeout default is 50 million 100-MHz cycles (500ms); it is reset each new request.

## Measurement interpretation and limits

`rtt_cycles = cycle_counter(at capture of validated reply in A 100MHz domain) - cycle_counter(at TX mailbox enqueue in A 100MHz domain)`; time in microseconds is `rtt_cycles / 100`. The measurement includes A's TX mailbox wait, Ethernet frames, both PHYs, B's RX CDC, B's processing, **B's 115200-baud UART mirror of its response BEFORE triggering its UDP TX**, B's TX mailbox, and A's RX mailbox. The UART telemetry emitted by A and Windows scheduling are outside the measured interval.

For a 14-byte response, B's UART transmission alone takes approximately `14 * 10 / 115200` seconds, or **1.215ms** (not including extra staging). Consequently, these RTT measurements are expected in milliseconds rather than the few-microsecond regime of a truly low-latency FPGA network pipeline. A one-byte `I`/`E` reply has only ~86.8us of UART payload overhead. We must change B to UDP-first/parallel output to obtain meaningful accelerated Ethernet RTT benchmarks. Without clock synchronisation we still cannot reliably split that result into one-way A->B vs B->A latency.

The current design does NOT implement general ARP/DHCP/ICMP, arbitrary Ethernet traffic, standard complete IPv4/UDP validation, generic MAC buffering, configurable Ethernet addresses, congestion control, packet queues, bursts/line rate, one-way latency, or high-accuracy measured power. It neither demonstrates full-duplex concurrent burst traffic nor supports packet retransmission.

## Mandatory acceptance gate

1. Python `pytest` all checks, including independent frame CRC/IP oracle.
2. Icarus MII TX unit test checks 3 packet types against Python vectors.
3. Icarus MII reply RX unit test checks valid R/I/E and corrupt FCS rejection.
4. Icarus integrated two-board test instantiates A & B RTL connected by idealised MII. Tests S, I, E and S with timestamp telemetry. This verifies logic, not PHY electrical or cable behaviour.
5. Vivado generator build: synthesised, placed, routed, no negative setup/hold slack, zero critical CDC-1, valid PHY REFCLK association, TX output IOB placement and port timing.
6. Manual review of CDC-15 and all methodology TIMING-18 warnings and clock constraints. Board-level skew and reference clock still provisional.
7. Only after acceptance: programme A's bitstream; programme B's **previously verified** v0.5A bitstream. Identify each board by JTAG serial and UART COM port.
8. Check Ethernet link LEDs, run a single packet, then 25 mixed records, then 200 mixed records. Any physical failure: stop, retain UART/LED observations and Vivado logs, restore baseline if needed.

## Next optimisation direction

Create M2C-fast Board B where UART diagnostic emission no longer serially gates Ethernet TX. Introduce hardware timestamp strobes at fixed MII receive/transmit points, better clock-domain phase accounting, clock synchronisation if one-way metrics are needed, and a streaming transmit generator with FIFOs and sequence tracking for burst/throughput. Keep the proven M2B endpoint as an immutable comparison baseline.
