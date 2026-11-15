# Upwork portfolio case study

**Title:** FPGA Low-Latency Ethernet / UDP Processor - Dual Artix-7 Hardware

**Suggested category:** Embedded Systems / FPGA / Digital Hardware Design

**Short description (ready to adapt):**

Developed and hardware-validated a low-latency Ethernet processing demonstrator across two Digilent Arty A7-35T FPGA boards using SystemVerilog and AMD Vivado. Implemented a synthetic market-data parser, top-of-book processing engine, bidirectional 100 Mb/s Ethernet UDP path, dual-clock FIFO buffering, independent UART diagnostics and a hardware-paced FPGA traffic generator with reply scoreboard.

Physical tests demonstrated 200/200 correct sequential transactions and approximately **12.85 microseconds median two-FPGA RTT** with the buffered endpoint. In the final controlled benchmark, the FPGA generated three 1,000-packet trials at each of 10,000, 50,000 and 100,000 packet requests/s, yielding **9,000/9,000 correct replies** with no missing or duplicate responses. FPGA timestamp counters confirmed exact 100/20/10 microsecond request-launch intervals. This is finite-burst evidence, not a claim of indefinite line-rate throughput or core-only latency.

**Services demonstrated:** FPGA RTL design; Ethernet UDP datapaths; MII interface; clock-domain crossing and asynchronous FIFOs; verification/testbenches; timing closure and Vivado CDC review; Python-based hardware testing; performance analysis and optimisation.

**Suggested 4 portfolio images:** (1) original photo of the two Arty boards connected by RJ45; (2) FPGA system block diagram; (3) v0.6-to-v0.7 hardware RTT comparison with correct UART-gating context; (4) 3x3 final M4C benchmark table.

**Portfolio cautions:** Demonstrator uses a synthetic fixed packet format. No production-exchange protocol, certified Ethernet appliance, PHY-only timing measurement or unverified benchmark claims.

**Published Upwork portfolio:** [Low-Latency FPGA Ethernet — view on Upwork](https://www.upwork.com/freelancers/~016d7fb025a209e3a2) (Portfolio section).

**GitHub source and reproduction:** [FPGA Low-Latency Ethernet](https://github.com/msamie-elec/FPGA-low-latency-ethernet).
