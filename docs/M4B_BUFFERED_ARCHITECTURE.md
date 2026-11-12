# M4B v0.8B — Design and Verification Notes

## Architecture

```
PHY RX_CLK 25 MHz                         sys_clk 100 MHz
+---------------------------+            +----------------------------+
|  MII FCS/IP/UDP validator |            | feed_pipeline (unchanged)  |
|    frame_data[127:0]      |            |   in-order 16-byte parser  |
+-----------+---------------+            +-----------+----------------+
            |                                         ^
            v                                         |
       +----+-------------------------------+   +-----+--------------+
       | RX async FIFO 16x128              |-->| core input FSM     |
       | Gray pointer, full/drop accounting|   +-----+--------------+
       +------------------------------------+         |
                                                   response metadata
                                                       |
                              +------------------------+---------+
                              |                                  |
                        +-----v--------------------+   +---------v------------------+
                        | TX async FIFO 16x116    |   | UART sync FIFO 8x116      |
                        | 100 MHz -> 25 MHz neg   |   | optional drop; count      |
                        +-------------+-----------+   +---------+------------------+
                                      |                         |
                            +---------v------------+    +-------v-----------+
                            | MII UDP TX + CRC/IFG |    | 115200 UART diag  |
                            +----------------------+    +-------------------+
```

## Clock-domain proof obligations

- Both asynchronous FIFOs use binary pointers only locally, registered Gray
  pointer exports, and two-flop `ASYNC_REG` synchronizers on each pointer
  direction. Full uses the next write pointer, empty the next read pointer.
- RX data is written only when the RX-valid pulse and `!wr_full` coincide on
  `posedge eth_rx_clk`. It is read only on `posedge sys_clk` with `rd_valid`.
- TX data is written on `posedge sys_clk`; it is read on **negedge**
  `eth_tx_clk` with local `rd_valid`, and the MAC captures the same FIFO head
  in local held registers before serialization. The MII output is still
  falling-edge registered and has the verified v0.7 provisional XDC bounds.
- FIFO reset signals are asserted asynchronously from the system/PHY reset
  scheme and deasserted per domain. Test reset during traffic and re-sync
  before data acceptance; inspect Vivado reset timing and CDC warnings.
- The independent 16-bit status counters are updated in their source domains.
  **Registered** Gray values cross via two-stage synchronizers and are decoded
  on 100-MHz debug signals. They are not used in flow-control decisions.
- The parser's valid-response pulses are captured into a pending register;
  the 100-MHz core holds that response until the Ethernet TX FIFO accepts it.
  UART accepts the same response opportunistically but never blocks Ethernet.

## Safety and limits

- FIFO depths are power-of-two parameters (>=4), evaluated with 16/16/8
  initially. Counter values saturate at 65535 (not modulo).
- A dropped UART diagnostic is **not** a dropped Ethernet response. Both are
  separately counted or tracked; outputs are marked for ILA debug but not
  available over the current USB telemetry protocol.
- The RX parser checks Ethernet FCS, a fixed lab IPv4/UDP format and 16-byte
  payload. This is not an Ethernet-compliant general-purpose receiver.
- Ethernet UDP has no backpressure. RX overload is dropped, counted and
  observable only through debug instrumentation. This design is not lossless
  at arbitrary arrival rate.
- The TX serialisation limits 100-Mbps wire-rate; an 84-byte including IFG
  minimum frame has a theoretical rate bound around 148,810 frames/s. This
  is *not* a design performance claim.
- Current Python M4A open-loop host-rate measurements are not PHY wire-rate
  or FPGA-only throughput results. Future M4C must generate traffic on FPGA.

## Test plan

1. FIFO boundary and ordering: Gray pointers, pointer wrap, full, empty,
   backpressure, simultaneous full pop/push in synchronous queue.
2. Backpressure test: hold RX FIFO reader idle, send 8 frames into a 4-slot FIFO,
   verify 4 accepted + 4 counted drops, drain/wrap and accept again.
3. MII 22 consecutive 72-byte frames at minimum inter-frame spacing, 20
   reports followed by ignored and error records. Check order and frame CRC.
4. Send malformed FCS and verify no UDP reply plus rejection counter.
5. Force diagnostic UART saturation by generating 22 frames far faster than
   14 bytes can serialise at 115200 baud. Confirm `debug_uart_drops` rises
   while all Ethernet responses still succeed.
6. Two-FPGA compatibility with existing v0.6 Board A in simulated MII link:
   valid/ignored/error cases with a hardware RTT bound.
7. Follow-on tests: full FIFO overflow and reset under continuous traffic;
   multi-clock ratio/phase sweep; CDC constraints and detailed Vivado report.
8. Controlled hardware: 1/25/200 requests; category-matched RTT from Board A;
   5/2/1ms host probes; FPGA-native calibrated burst throughput in M4C.

**The new HDL is an unverified engineering candidate until the user's Icarus
and Vivado tools execute these tests and the reports are reviewed.**
