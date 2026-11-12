# M3 v0.7 — Low-Latency Ethernet Reply (Engineering Candidate)

**Status: NOT HARDWARE APPROVED.** The original v0.5A Board B and v0.6 Board A are preserved.
This candidate changes **Board B ONLY**: it launches UDP TX as soon as it forms
an `R`/`I`/`E` response and sends the UART mirror simultaneously. Board A remains
binary-compatible and its hardware 100 MHz RTT counter is unchanged.

## Why

The verified 200-packet v0.6 physical experiment showed mean `S` RTT ~1228 us
and `I`/`E` RTT ~99.6 us. Most of that `S` difference matches 13 extra UART
characters at 115200 baud. Previously, the endpoint waited for the full UART
response before toggling the Ethernet TX request. This is a control-path delay,
not a claim that the market-data arithmetic itself needs milliseconds.

## Architecture / response ownership

```
                 MII RX 25 MHz
                      |
               RX toggle mailbox
                      |
               market-data core 100 MHz
                      |
              stable 112-bit response + length
                 /                   \
       independent UART FSM    UDP TX toggle mailbox
       115200 baud mirror       25 MHz MII TX
                 \                   /
             wait for BOTH completion toggles
                      |
                 release RX mailbox
```

In `rtl/ethernet_udp_a7_lowlat.sv`, `WAIT_RESULT` writes the response/length,
changes `tx_req_toggle`, and changes `uart_start_toggle` on the **same** FPGA
100 MHz edge. An independent UART FSM serializes the same stable payload.
The main FSM freezes data and only acknowledges the original RX request after
both the Ethernet TX IFG/ack AND UART completion are observed. This is a
single-entry architecture: **response latency is optimised, but UART still
limits sustained transaction rate** because the next packet waits for both
consumers. FIFO-based throughput decoupling remains a later project.

The MII TX and RX CDC toggle handshakes and PHY timing constraints are unchanged
from the hardware-verified v0.5A source. Stable multi-bit data remains a
protocol assumption requiring further reset/phase/backpressure verification.

## Preserved designs

* `rtl/ethernet_udp_a7.sv` — original verified v0.5A Board B, unchanged
* `rtl/ethernet_generator_a7_m2c.sv` — verified v0.6 Board A, unchanged
* `rtl/ethernet_udp_a7_lowlat.sv` — **new** Board B v0.7
* Board B `ethernet_m3_endpoint.xdc` matches the former `ethernet_m2c_endpoint.xdc` byte-for-byte.

## Windows quick start

Extract into a **new directory**, then from its `fpga-low-latency-networking`
root assign `V:` in PowerShell (do not overwrite old `R:`, `T:`, `U:`):

```powershell
subst V: (Get-Location).Path
Set-Location V:\
$env:Path = "C:\Programs\msys64\ucrt64\bin;$env:Path"
python -m pytest -q tests
python scripts/check_m3_candidate.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_m3_sim.ps1"
```

Only if ALL tests pass, run a distinct Vivado project targeting Board B:

```powershell
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_m3_endpoint.tcl
python scripts/audit_m3_reports.py
Compress-Archive -Path "V:\build\reports\ethernet_m3_endpoint\*" -DestinationPath "V:\build\reports\ethernet_m3_endpoint_reports.zip" -Force
```

**STOP AND UPLOAD REPORTS BEFORE PROGRAMMING**. Require positive setup/hold,
zero critical CDC-1, MII TX setup+hold and IO register placement, documented
CDC-15 and methodology warnings, plus full RTL simulation pass. Vivado is NOT
available in the authoring environment, so no placement/timing pass is claimed.

If Vivado approves and human report review passes:

1. Keep Board A's verified v0.6 generator bitstream **on U:** unchanged.
2. Program **Board B only** with the new **V:** bitstream:
   `V:\build\vivado_ethernet_m3_endpoint\ethernet_m3_endpoint.runs\impl_1\ethernet_udp_a7_lowlat.bit`
3. Maintain direct RJ45 cable Board A--Board B and USB/JTAG to each.
4. Board A is COM4 in the last verified lab session, Board B is COM3;
   recheck if ports were re-enumerated.
5. Reset BTN0 on both boards before each experiment and allow Ethernet link
   to settle. Run **1**, then **25**, then **200** controlled exchanges:

```powershell
python scripts/m3_dual_board_test.py --com COM4 --count 1 --pattern standard
python scripts/m3_dual_board_test.py --com COM4 --count 25 --pattern mixed
python scripts/m3_dual_board_test.py --com COM4 --count 200 --pattern mixed
```

`m3_dual_board_test.py` writes `build/hardware/m3_dual_board_rtt.csv`. The embedded
`docs/baselines/m2c_v06_hardware_rtt_200.csv` is the USER-PROVIDED physical
v0.6 baseline: no modelled or invented RTT measurements are substituted.
After a passing 200-run, compare **paired** events:

```powershell
python scripts/compare_m3_latency.py
```

## Limitations and acceptance

RTL testbench imposes a **25,000-cycle / 250 us** maximum *simulated ideal-link*
RTT for S/I/E and verifies that MII TX starts while UART remains busy. This
is a regression guard, **not a physical RTT guarantee**. No FPGA-only one-way
latency, line-rate throughput, uncontrolled bursts, phase-robust CDC proof,
full IPv4/UDP implementation or PHY electrical sign-off is claimed. The present
100 MHz clock counter resolves 10 ns ticks but does not prove 10 ns accuracy
against real clocks. The PHY's 25 MHz MII frame times impose the main packet
serialization cost.
