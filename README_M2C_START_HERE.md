# Milestone M2C: Two-Arty-A7 Ethernet, new v0.6 prototype

**Status 11 November 2026:** engineering candidate. Source package and Python reference checks complete; **the new M2C RTL has NOT yet been simulated in Icarus, implemented in Vivado, or tested on physical boards**. Never programme the candidate solely based on Python test success.

The **previous** v0.5A endpoint, preserved as `rtl/ethernet_udp_a7.sv` and its original dependencies, *has* passed 200/200 physical Ethernet+UART host-paced checks on the user's Arty A7. The source of truth for that previous release remains `T:\`. The v0.5A bitstream is not bundled here.

## Goal

Connect two Arty A7-35T boards directly by Cat5e/Cat6 Ethernet (one RJ45 cable). Board A generates 16-byte synthetic market-data updates, receives/validates Board B's 1/14-byte UDP replies and timestamps a stop-and-wait **round trip using its own 100-MHz FPGA clock**. Board B runs the proven v0.5A market-data UDP processor (plus UART mirror). Windows uses the two boards' USB UARTs only to command and log measurements. You do **not** need the TP-Link USB Ethernet adapter when the two RJ45 connectors are connected directly.

```
                 UART control + measured result on A COM port
 ASUS laptop -----------------------------------------------+
       |                                                    |
       +-- USB JTAG/UART A --------------------+            |
       +-- USB JTAG/UART B --------------------|------------|---------+
                                              v            v         v
                            +---------------------------+   +--------------------------+
                            | Arty A7 #1 / Board A     |   | Arty A7 #2 / Board B    |
                            | M2C ethernet_generator   |   | existing v0.5A endpoint  |
                            | feed TX / UDP reply RX    |<->| market data engine       |
                            | 100-MHz RTT counter      |   | UDP RX and UDP TX        |
                            +-------------RJ45----------+---+----------RJ45------------+
                                         100Mbps direct Cat6
```

## Source layout

- `rtl/ethernet_generator_a7_m2c.sv`: new Board A top, UART commands, local hardware timer and reply checker.
- `rtl/mii_feed_tx.sv`: new Ethernet/IPv4/UDP transmitter for 16-byte synthetic records.
- `rtl/mii_reply_rx.sv`: new Ethernet/IPv4/UDP/FCS reply receiver for `R`/`I`/`E`.
- `rtl/ethernet_udp_a7.sv`: **unchanged v0.5A Board B endpoint**.
- `boards/arty_a7/ethernet_m2c_generator.xdc`: Board A pins and preliminary MII clock/IO timing.
- `boards/arty_a7/ethernet_m2c_endpoint.xdc`: copy of the previously verified v0.5A endpoint XDC.
- `tb/tb_mii_feed_tx.sv`, `tb/tb_mii_reply_rx.sv`, `tb/tb_m2c_board_pair.sv`: new tests.
- `scripts/m2c_vectors.py`: independent Python Ethernet-frame reference generator.
- `scripts/m2c_dual_board_test.py`: Python serial controller, independent expected responses, CSV capture.
- `docs/M2C_ARCHITECTURE.md`: constraints, CDC method, protocol, limits.
- `docs/evidence/m2b_bidirectional_reliability_200pass.csv`: user's earlier v0.5A physical acceptance evidence.

## 1. Extract into a NEW project folder

Example: `C:\FPGA\fpga-low-latency-networking`

Open PowerShell in the **extracted `fpga-low-latency-networking` source root** (the directory containing `rtl`, `tb`, `scripts`). Use a short virtual drive separate from R/S/T:

```powershell
subst U: (Get-Location).Path
Set-Location U:\
Test-Path .\scripts\build_m2c_generator.tcl
```

Expected: `True`. Keep `R:\` (v0.4B) and `T:\` (verified v0.5A) unchanged.

## 2. Software + RTL simulation (must pass before Vivado)

```powershell
$env:Path = "C:\Programs\msys64\ucrt64\bin;$env:Path"
python -m pytest -q tests
python scripts/check_m2c_candidate.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_m2c_sim.ps1"
```

Expected: **22 Python tests** and three new RTL tests, including the simulated two-board link. The existing v0.5A RTL regression can also be rerun with `scripts/run_ethernet_m2b_sim.ps1`.

If RTL simulation fails, share the console error. **Do not programme Board A.** The new RTL is unverified until these tests pass.

## 3. Build Board A in Vivado

```powershell
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_m2c_generator.tcl
python scripts/audit_m2c_reports.py --board generator
```

Candidate bitstream after a successful build:

```
U:\build\vivado_ethernet_m2c_generator\ethernet_m2c_generator.runs\impl_1\ethernet_generator_a7_m2c.bit
```

Save the reports for review:

```powershell
Compress-Archive -Path "U:\build\reports\ethernet_m2c_generator\*" -DestinationPath "U:\build\reports\ethernet_m2c_generator_reports.zip" -Force
```

**Stop before programming**, share `ethernet_m2c_generator_reports.zip` for CDC, timing and PHY TX sign-off. The script rejects negative setup slack or CDC-1 critical warnings, but CDC-15 mailbox coherency, external clock assumptions and missing I/O delay reports still need engineering review.

## 4. Board B programming (after Board A passes review)

Board B is the known v0.5A endpoint, currently stored in the original `T:\` project:

```
T:\build\vivado_ethernet_m2b\ethernet_m2b.runs\impl_1\ethernet_udp_a7.bit
```

Do not confuse the two Arty boards when using Vivado Hardware Manager. Identify each JTAG serial and each UART COM port one board at a time before attaching both. Board A uses a **new** bitstream only after separate sign-off. Board B uses the **existing** verified bitstream. Both boards need their own USB programming/power connection.

After both programmed: connect Arty A RJ45 directly to Arty B RJ45 using one Cat5e/Cat6 patch lead. Neither board needs the UE300C for this direct arrangement. The DP83848J includes Auto-MDIX and supports 100Mbps full-duplex auto-negotiation; verify the physical RJ45 link LEDs on BOTH boards. Windows `Get-NetAdapter` does not show this direct FPGA-to-FPGA Ethernet link.

## 5. Two-board smoke and regression (only after hardware authorisation)

Determine Board A's USB serial port; the old `COM4` may now refer to Board B:

```powershell
python -m serial.tools.list_ports -v
```

Press/release BTN0 on **both** boards, allow >1 second for the 25-MHz PHY references and link to settle, then run from `U:\`, with Board A's actual COM port substituted:

```powershell
python scripts/m2c_dual_board_test.py --com COM5 --count 1 --pattern standard
```

Reset **both** before a new, independent test session, because Board A sequence count and Board B top-of-book state persist across commands. If one packet passes:

```powershell
python scripts/m2c_dual_board_test.py --com COM5 --count 25 --pattern mixed
```

Then a longer run:

```powershell
python scripts/m2c_dual_board_test.py --com COM5 --count 200 --pattern mixed
```

Replace `COM5` with the actual Board A COM number; this number is **not known in advance**. Results appear in `U:\build\hardware\m2c_dual_board_rtt.csv`. The Python checker stops at the first mismatch or timeout.

## Critical latency qualification

Board A's FPGA timer spans enqueueing a transmit request to detecting a validated reply. It excludes Windows, Python and Board A's UART logging, but **it INCLUDES Board B's v0.5A UART report transmission before Ethernet TX** (~0.09–1.2 ms depending on report). It therefore **does not measure wire-to-wire network-processing latency**. We must implement a fast UDP-first or parallel UART/UDP Board B endpoint and use more precise TX/RX measurement boundaries before using this design for low-latency benchmarking. One packet in flight also means **no line-rate or burst-throughput claim**.

See `docs/M2C_ARCHITECTURE.md` for full details and the next optimisation milestone.
