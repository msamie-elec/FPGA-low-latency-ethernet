# Milestone M2A v0.4B: user-reported physical hardware acceptance

**11 November 2026**. Evidence is the actual user-supplied PowerShell
log for the Arty A7-35T and a wired TP-Link UE300C connected to a Windows
ASUS VivoBook. The signal path is Ethernet MII 100 Mbps -> v0.4B RTL
processing -> USB-UART COM4. This is NOT proof of Ethernet transmit.

Previously verified: RTL unit/integration simulations, Vivado implementation,
physical FPGA programmed, LD4 heartbeat, 100 Mbps Ethernet negotiated,
Windows wired IPv4 `192.168.77.1/24`.

Test command and exact user-reported results:

```
python scripts/ethernet_to_uart_test.py --com COM4 --pc-ip 192.168.77.1 --broadcast 192.168.77.255 --count 1
PASS ethernet packet 00: 5200000001000027100000000000
PASS 1 Ethernet-to-UART FPGA transactions

python scripts/ethernet_to_uart_test.py --com COM4 --pc-ip 192.168.77.1 --broadcast 192.168.77.255 --count 10
PASS ethernet packet 00: 5200000001000027100000000000
PASS ethernet packet 01: 5200000002000027100000271301
PASS ethernet packet 02: 5200000003000027100000272400
PASS ethernet packet 03: 49
PASS ethernet packet 04: 49
PASS ethernet packet 05: 5200000006000027200000272401
PASS ethernet packet 06: 5200000007000027260000272400
PASS ethernet packet 07: 52000000080000271a0000272400
PASS ethernet packet 08: 52000000090000271a0000271b01
PASS ethernet packet 09: 45
PASS 10 Ethernet-to-UART FPGA transactions
```

User did not report measured packet latency, throughput, heavy traffic, board
power or Ethernet TX. This log is a **hardware functional milestone** only.
Do not modify the verified v0.4B logic as part of v0.5 development.
