# v0.4A verification matrix — engineering release gate

| ID | Test | Required acceptance | Status at package creation |
|---|---|---|---|
| SW-01 | `python -m pytest -q tests` | all Python unit tests pass | PASS (10) |
| SW-02 | `python scripts/check_ethernet_m2a.py` | 21 board IO pins and source list pass | PASS |
| RTL-01 | `tb_mii_udp_rx` | valid packet accepted, bad FCS and wrong port rejected | **NOT EXECUTED** — Icarus unavailable here |
| RTL-02 | `tb_ethernet_uart_a7` | 2 Ethernet packets generate exact UART reports | **NOT EXECUTED** |
| FPGA-01 | Vivado `build_ethernet_m2a.tcl` | synth/impl/bitstream complete, no critical violations | **NOT EXECUTED** |
| FPGA-02 | implementation timing, external MII I/O/clock CDC review | no unhandled violations, CDC design reviewed | **NOT EXECUTED** |
| HW-01 | PHY link, static Ethernet sender | link up, LD4 heartbeat, LD5 packet indicator | **NOT EXECUTED** |
| HW-02 | one UDP broadcast -> USB-UART report | one expected response | **NOT EXECUTED** |
| HW-03 | 10 UDP broadcasts -> USB-UART reports | ten matching response records | **NOT EXECUTED** |
| NET-02 | UDP Ethernet reply to PC | bidirectional network path | OUT OF SCOPE until M2B |
| NET-03 | 2 FPGA boards | FPGA-to-FPGA Ethernet | OUT OF SCOPE until M2C |

**Do not proceed to board programming until RTL simulations and Vivado implementation pass.** If either fails, preserve the v0.3 bitstream and share the error logs for revision. Physical success is meaningful only when accompanied by the actual timing and CDC methodology reports.
