# Engineering iteration log

## Cycle 1 — Inspect/review pre-existing project skeleton

* Reviewed synthetic-feed parser, one-symbol book, software reference, fixed
  vectors, basic board ROM demo and RTL testbench.
* Confirmed parser flags short/overlong records and preserves output under
  downstream backpressure by holding the event register.
* Identified that there was no physical host-input interface and no executed
  HDL simulation evidence. Established requirements and verification gates.

## Cycle 2 — Build hardware-facing UART loop

* Added synthesizable UART RX/TX, frame packing and a host-paced binary
  response protocol for Arty A7 and S7.
* Added board pin constraints from official Digilent master XDC references,
  a configurable Vivado batch build, and end-to-end UART testbench.
* Added explicit ignored-record notification (`I`) and parse rejection (`E`).
* Static review caught a mistakenly connected nonexistent parser port;
  corrected it and added an automated named-port regression test.

## Cycle 3 — Cross-language regression and release review

* Python and standalone C++ reference models agree on deterministic sample
  vectors, including deliberate malformed inputs.
* Seeded 1,200-record Python/C++ random comparison passes, including invalid
  header and reserved-field cases.
* Python reference, board-response and boundary tests are automatically run.
* RTL simulation attempted but blocked: no `iverilog`/`vvp` installed and the
  container cannot access package repositories; no claim of HDL simulation PASS.
* Vivado synthesis/timing/bitstream and real Arty hardware test pending.

## Required follow-on engineering iteration

1. Run actual Icarus bench; fix any compile/timing/scoreboard issues.
2. Build implementation for exact FPGA part in Vivado; inspect timing violations.
3. Program board and execute serial host tests, record observable results.
4. Design MII Ethernet RX/TX, IPv4/UDP and FCS checking, CDC buffering and
   corresponding network traffic verification; do not label Ethernet complete
   before these are exercised.
5. Establish throughput/latency/resource measurements and document trade-offs.

## Cycle 4 — Real Arty A7 USB-UART fault isolation (2026-10-29)

* User passed main v0.2 RTL benches, synthesised and programmed A7-35T.
* Main physical ten-record test returned `NO DATA` on record 0 despite
  functional heartbeat and BTN0 reset.
* COM4 exclusive access check passed; therefore it was not a busy COM port.
* Separate 100 MHz/115200 baud echo diagnostic v0.3 simulated but failed on
  hardware; found RX/TX pin directions were assigned backward.
* Echo diagnostic v0.4 used FPGA RX=A9, FPGA TX=D10. User reports simulation,
  hardware programming and five physical echo checks passing.
* Applied exact physical-direction correction to main board UART top and A7
  XDC. Added physical-baud integration simulation and XDC pin assertions.
* NEXT: rebuild corrected main Vivado bitstream, inspect timing, program it,
  and run the 10-record UART test. Physical main-project PASS not yet claimed.
