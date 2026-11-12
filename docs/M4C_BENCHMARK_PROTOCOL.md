# M4C — Final FPGA-native Ethernet burst benchmark (candidate)

## Fixed scope and close-out rule

The final technical work item is to measure three finite 1,000-frame bursts using **the already verified v0.8B Board B**. **No additional endpoint redesign is planned.** Board A alone is modified to generate hardware-paced traffic and count uniquely returned reports. The release is a **portfolio demonstrator**, not a certified networking appliance.

The physical architecture is two Arty A7-35T boards connected directly over **one Cat5e/Cat6 Ethernet cable** at 100 Mbps, with independent USB cables for JTAG/UART. The TP-Link UE300C is not used for this benchmark. Board A uses the new M4C v0.9 generator and Board B retains the v0.8B buffered endpoint bitstream.

## Workload and modes

All packets contain a valid fixed 16-byte synthetic market-data record. Record fields: type alternates `B` / `A`, symbol 1, sequence 1..1000, price 10000+(sequence mod 16), quantity 1, reserved zero. Board B returns a 14-byte `R` report. The generator's existing `mii_feed_tx` and `mii_reply_rx` enforce the fixed demonstration Ethernet/UDP frame envelope and FCS checking.

| ASCII command | Target request period (100 MHz cycles) | Target spacing | Nominal offered rate | Runs |
|---|---:|---:|---:|---:|
| `A` | 10,000 | 100 µs | 10,000 packets/s | 3 |
| `B` | 2,000 | 20 µs | 50,000 packets/s | 3 |
| `C` | 1,000 | 10 µs | 100,000 packets/s | 3 |

The MII transmitter sends only when the previous frame has completed the inter-frame gap and acknowledged the previous mailbox request. **Therefore a requested interval is not proof of the actual achieved interval.** The transmitter samples 100 MHz cycle counts for each launch and reports min/max gaps, number of launches delayed beyond their requested deadline, and first-to-last launch span. Under `C`, the 10 µs request period is larger than the theoretical ~6.72 µs required for the current 72-byte MII transmission plus minimum IFG at 100 Mb/s.

## Reply accounting

A 1000-bit scoreboard on Board A counts each unique report sequence 1..1000 exactly once. It counts duplicated sequences separately; unexpected sequences or non-14-byte reports are invalid/unexpected. Replies continue to be accepted during a fixed post-burst drain period (default 5 ms) before the summary is generated. A missing response is `sent_count - unique_reply_count` within the measurement window. **Missing is not necessarily packet loss inside Board B**; it may be a request, network or reply-path loss or a response beyond the 5 ms drain window. The packet receiver itself may reject CRC/invalid frames before the scoreboard; LED error indication is diagnostic, not a reliable packet-loss counter.

The Board B FPGA-side RX FIFO overflow count and UART diagnostic-drop counters are not exported over the existing hardware interface. **Do not claim these were measured in M4C.** They remain implementation details demonstrated by RTL simulation and inferred where relevant. This scope is intentionally limited to completing a credible final portfolio benchmark.

## UART summary protocol: exactly 40 bytes, big-endian

| Byte range | Description |
|---|---|
| 0 | ASCII `B` (benchmark) |
| 1 | ASCII profile `A`, `B`, or `C` |
| 2 | Protocol version 1 |
| 3 | Reserved 0 |
| 4–7 | Sent request count (request accepted by Board A controller; final TX acknowledgement awaited before drain) |
| 8–11 | Unique valid 14-byte report replies |
| 12–15 | Duplicate report sequences |
| 16–19 | Out-of-range report sequences |
| 20–23 | Wrong-length or non-report responses |
| 24–27 | Late launches (more than 1 cycle after scheduled request time) |
| 28–31 | Minimum gap between consecutive TX **request launches** in 100 MHz cycles |
| 32–35 | Maximum gap between consecutive TX request launches in 100 MHz cycles |
| 36–39 | First-to-last launch span in 100 MHz cycles |

For N=1000, request rate = `(N-1)*100 MHz / send_span_cycles`. This is an FPGA-side request-launch metric, not an oscilloscope measurement of Ethernet wire timing, and not a measured sustained application goodput rate. For actual goodput the reply rate and duration need separately instrumented timestamps.

## Hardware procedure

1. Keep the complete working projects on `U:` (v0.6), `V:` (v0.7), and `X:` (v0.8B) unchanged. Extract M4C separately to `Y:`. Keep a copy of Board A's verified v0.6 bitstream for recovery.
2. Run software tests, the **two-board RTL testbench**, synthesis and place/route for **Board A only**. Check the post-route CDC and timing reports. **Do not program M4C before those gates pass.**
3. Connect USB to each FPGA and RJ45 **between the two boards**, not to the laptop. Board A is historically COM4 and Board B COM3; verify Windows enumeration if changed.
4. Program Board A with `Y:\build\vivado_ethernet_m4c_generator\ethernet_m4c_generator.runs\impl_1\ethernet_generator_a7_m4c.bit`; leave Board B v0.8B installed.
5. Press and **release** BTN0 on both boards, allow the link to settle, then run the host tool. If the link does not negotiate, do not infer an FPGA logic failure from zero replies.
6. Run 3 replicates each of A, B and C; save CSV and JSON summaries with their actual reported send gaps and received counts. Profile A should be the initial smoke test before the others. A one-command test (`--profile A --repeat 1`) is preferable at bring-up.
7. Stop after the defined profile matrix unless a correctness bug invalidates the results. Record any losses, conditions and qualifications; do not open another major redesign cycle to chase an arbitrary target.

## Interpretation limits

- Previous v0.7/v0.8B ~12.75/12.85 µs RTT results were measured at low load. Do not claim that the same RTT holds during these high-rate bursts without measuring it.
- Each existing MII Ethernet packet is a fixed synthetic broadcast payload; this is not an exchange-standard market data protocol or commercial trading system.
- Physical PHY skew, REFCLK quality, formal CDC proof and long-duration reliability are outside this portfolio acceptance scope and must be disclosed.
- Both existing Arty A7 FPGAs are 35T devices; synthesis resource/power estimates must be tied to the exact bitstream being reported.
