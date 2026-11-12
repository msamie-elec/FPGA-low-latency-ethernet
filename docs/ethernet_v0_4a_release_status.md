# v0.4A evidence status — 2026-10-30

- Previous project v0.3 single-board UART: user independently observed `PASS 10 board transactions` on Arty A7-35T, with +2.737 ns WNS and 100 MHz target in supplied Vivado reports.
- New v0.4A: Ethernet MII RX, UDP broadcast parser, CRC checking, asynchronous mailbox and UART response integrated into a new RTL top. **Not yet synthesised, simulated or physically tested with Vivado/Icarus at release.**
- Python deterministic MII frame generator and protocol unit tests run successfully (see run outputs).
- A7 pin mapping static checker run successfully.
- Release is a **test candidate**, not a verified Ethernet design. Do not publish performance figures or assert Ethernet functionality before on-board results.
- Uses strict test-only subset of Ethernet/IPv4/UDP; not a production network stack.
