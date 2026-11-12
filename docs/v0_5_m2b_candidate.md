# v0.5 Milestone 2B: FPGA UDP Ethernet transmit + receive engineering candidate

Date: 11 November 2026. **UNVERIFIED IN RTL SIMULATION, VIVADO AND HARDWARE.**
The prior v0.4B RX-to-UART implementation was physically verified on an
Arty A7-35T by the user, with 1/1 and 10/10 independent-oracle transactions.
That verified baseline remains in `rtl/ethernet_uart_a7.sv` and the original
`scripts/build_ethernet_m2a.tcl` build path. Do NOT overwrite its bitstream.

## Hardware/data-flow architecture

```
ASUS laptop --UDP broadcast 192.168.77.255:5000 --> UE300C --RJ45-->
   Arty A7 DP83848J PHY --MII RX 25MHz--> mii_udp_rx
   --128-bit stable-data req/ack mailbox--> feed_pipeline 100MHz
                                        |--uart_tx 115200--> laptop COM4
                                        `--stable 112-bit + len toggle mailbox
                                           --> mii_udp_tx PHY TX_CLK 25MHz
                                           --> DP83848J PHY --> RJ45
                                           --> UDP broadcast 192.168.77.255:5001
                                           --> laptop Python receiver
```

## Packet format, explicitly limited scope

- Inbound: same as v0.4B: 16-byte synthetic record, broadcast Ethernet,
  IPv4 IHL=5, UDP destination 5000, Ethernet FCS checked.
- Outbound destination MAC: `ff:ff:ff:ff:ff:ff` (broadcast).
- Outbound source MAC: `02:11:22:33:44:55` (locally administered).
- Outbound source IPv4: `192.168.77.2`, destination `192.168.77.255`.
- Outbound UDP source/destination ports: `5000` -> `5001`.
- Outbound payload: existing binary response (`R` + 13 bytes, `I`, or `E`).
- IPv4 header checksum calculated in RTL; IPv4 UDP checksum = 0 (valid
  under IPv4, not for IPv6). UDP length varies with response size.
- Zero Ethernet padding to 60 bytes, then FCS32, seven `55` preamble bytes and
  `D5` SFD. MII low-nibble-first, registered on PHY TX_CLK falling edge.
- PHY TX clock is input `eth_tx_clk` on Arty A7 pin H16; RX clock remains F15.
- Transmit 100Mbps ONLY. This version does not support 10Mbps, VLAN tags,
  ARP, DHCP, ICMP, unicast MAC matching, fragmentation, hardware timestamping,
  line-rate bursts, general UDP packet receive or traffic shaping.
- One outstanding request / response. UART sends first; Ethernet response
  follows, so this intentionally **is not a low-latency Ethernet design**.
  Both mailbox protocols must be stress-tested further.

## New files

| File | Purpose |
|---|---|
| `rtl/mii_udp_tx.sv` | PHY-clocked MII UDP Ethernet transmitter |
| `rtl/ethernet_udp_a7.sv` | Separate v0.5 top; unchanged baseline top retained |
| `boards/arty_a7/ethernet_m2b.xdc` | TX clock H16, TX timing estimates, async clocks |
| `scripts/build_ethernet_m2b.tcl` | Separate project/build/report directory |
| `scripts/ethernet_tx_vectors.py` | Independent Ethernet transmit golden frames |
| `tb/tb_mii_udp_tx.sv` | TX nibble-by-nibble test for 3 response types |
| `tb/tb_ethernet_udp_a7.sv` | Integration UART and Ethernet dual response |
| `scripts/run_ethernet_m2b_sim.ps1` | M2A regression plus new TX tests |
| `scripts/ethernet_bidirectional_test.py` | Physical UDP+UART compare against oracle |
| `scripts/ethernet_reliability_test.py` | Host-paced v0.4B reliability regression |

## Test sequence (Windows PowerShell in extracted repo root)

**First test the still-programmed v0.4B board without changing the FPGA**:

```
python scripts/ethernet_reliability_test.py --com COM4 --pc-ip 192.168.77.1 --count 200 --gap-ms 5
```

Press/release BTN0 *before* starting; 200 records are deterministic, include
valid, ignored and malformed cases, and each UART response is oracle-checked.
Stop and investigate on any mismatch. This tests a host-paced sequence, **not
packet burst tolerance**. CSV log: `build/hardware/m2a_reliability.csv`.

**Then check the v0.5 candidate off-board**:

```
python -m pytest -q tests
python scripts/check_m2b_candidate.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ethernet_m2b_sim.ps1
```

Both `tb_mii_udp_tx` and `tb_ethernet_udp_a7` must PASS. If Icarus reports
an error, fix RTL/testbench before continuing. **Do not program v0.5 yet.**

**Build separately only if all RTL simulations pass**:

```
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_ethernet_m2b.tcl
```

Expected new bitstream (only if implemented):
`build/vivado_ethernet_m2b/ethernet_m2b.runs/impl_1/ethernet_udp_a7.bit`.
This is separate from the verified M2A bitstream. Check CDC, WNS/WHS,
`check_timing`, methodology, the PHY TX clock H16, and unconstrained paths.
Do not infer TX_CLK timing signoff solely from the input/output constraints;
board trace skew and PHY timing need verification.

**Only after we review simulations and implementation**, program the new bitstream
and run:

```
python scripts/ethernet_bidirectional_test.py --com COM4 --pc-ip 192.168.77.1 --count 1
python scripts/ethernet_bidirectional_test.py --com COM4 --pc-ip 192.168.77.1 --count 10
```

The test listens on wildcard `0.0.0.0:5001` (so Windows can receive broadcast packets) before sending each request to
`192.168.77.255:5000`. It checks two replies, one over UART and one over
Ethernet, against independent software expectations. Static Ethernet IPv4
configuration stays unchanged on the laptop. No second Ethernet adapter is
required. Windows Firewall may need narrowly scoped permission for inbound
UDP port 5001 on the dedicated Ethernet adapter if actual packets are blocked.

## Acceptance gates / unresolved engineering risks

1. M2A v0.4B 200/200 paced hardware test: PENDING.
2. v0.5 TX and integration RTL simulations: PENDING.
3. v0.5 Vivado synthesis, place/route and constraints: PENDING.
4. v0.5 independent UART+UDP dual replies, 1/1 and 10/10: PENDING.
5. v0.5 CDC data consistency, clocks/reset skew and backpressure: NOT SIGNED OFF.
6. Sustained throughput, latency and asynchronous-link error testing: PENDING.

PHY timing source: Texas Instruments DP83848J/DP83848x datasheet (100 Mbps
MII TX_CLK, 10ns setup and 0ns hold) and Digilent Arty A7 master XDC
(`eth_tx_clk=H16`). Reference links:
- https://www.ti.com/lit/ds/symlink/dp83848j.pdf
- https://github.com/Digilent/Arty-A7-35-XADC/blob/master/src/constraints/Arty_Master.xdc
