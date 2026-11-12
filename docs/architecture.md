# Architecture and design decisions

## Data path

**Simulation interface:** `s_data[7:0]`, `s_valid`, `s_ready`, `s_last`.
A byte transfers at the rising edge when `s_valid && s_ready`.
`s_last` marks the final byte of a variable-length frame.
The UART board wrapper sends exactly 16 bytes and asserts `s_last` on byte 15.

```
       8-bit ready/valid stream
                 |
                 v
    +--------------------------+
    | feed_parser              |-- parse_error (pulse)
    | record validation        |
    | output holding register  |
    +------------+-------------+
                 | event valid/ready
                 v
    +--------------------------+
    | top_of_book              |-- event_ignored (pulse)
    | single-symbol state      |
    | signal: 0 < spread <= 5  |
    +------------+-------------+
                 | report valid/ready
                 v
           consumer/host
```

## Record specification

This is an original synthetic research/benchmark protocol, NOT FIX, ITCH,
OUCH or any actual exchange feed. Network Ethernet/MII framing is **not yet
implemented** in this release.

Exactly 16 bytes, big-endian:

| Offset | Bytes | Field | Allowed values |
|---|---:|---|---|
| 0 | 1 | Side | `0x42` B (bid), `0x41` A (ask) |
| 1 | 1 | Symbol | 0..255, tracked symbol 1 |
| 2 | 4 | Sequence | unsigned u32, not used for ordering |
| 6 | 4 | Price | unsigned u32 integer ticks |
| 10 | 4 | Quantity | unsigned u32; zero means ignore |
| 14 | 2 | Reserved | must be 0x0000 |

Wrong length, side or reserved bytes: one `parse_error` pulse and no event.
Unknown symbols and quantity zero: one ignored-event pulse (board status `I`).
Otherwise bid or ask side replaces that side's previous price. This is NOT a
full market order book (no depth, price levels, orders, deletes, sequence-gap
handling, exchange sequencing, multicast recovery or risk controls).

**Signal:** `have_bid && have_ask && ask > bid && (ask-bid)<=5`.
The sequence number accompanies output but is not enforced or sorted. Output
`report_seq,bid,ask,signal` is held stable while `report_valid=1` and
`report_ready=0`. Reset discards pending inputs and clears state.

## Critical latency definitions

For an accepted 16th byte at a rising edge T:
* parser publishes event immediately after edge T;
* book samples event at edge T+1 and publishes report after T+1;
* downstream may handshake the report at edge T+2.

Thus intrinsic record-completion-to-report-valid latency is nominally one
clock period (registered pipeline at T+1), and to output handshake two edge
intervals, **subject to stalls**. This is a theoretical code inspection claim,
not a measured clock frequency or closed timing result.

An ideal eight-bit byte-per-cycle link at 100 MHz carries up to 6.25 million
16-byte records/s before protocol overhead. This is an *input bandwidth bound*,
not a measured processor, UART or Ethernet throughput. UART 115200 8N1 permits
at most 720 records/s (115200 / (10*16)) ignoring reply/time overhead.

## UART board exercise

UART is a functional test transport, **not** a trading network data path.
Each request is exactly 16 raw bytes; host waits for complete reply before
next request. Frames do not carry a sync marker, CRC or flow control.

Reply encodings:
* `0x52` ('R') + 4-byte seq + 4-byte bid + 4-byte ask + 1-byte boolean
* `0x45` ('E'): rejected malformed record
* `0x49` ('I'): ignored record

Baud 115200, 8N1, no flow control. Press BTN0 to reset state and realign the
16-byte frame counter if a serial framing problem occurs.

## Review risks and limitations

* RTL simulator and Vivado design-tool sign-off must occur before declaring
  the bitstream functional.
* UART test wrapper assumes host-paced requests; unexpected input while stalled
  may be lost because the UART does not have RTS/CTS or FIFO buffering.
* UART baud period is rounded to an integer system-clock count.
* Buttons are asynchronous; reset is synchronously released with a short shift
  register. No explicit button debouncer is used (reset only).
* No full Ethernet MAC, UDP/IP, CRC/FCS, PTP timestamping, high-speed SerDes,
  order-book depth, formal proof, UVM, or ASIC sign-off in this release.
