# FPGA Low-Latency Ethernet — M4B v0.8B buffered endpoint

**Status: ENGINEERING CANDIDATE, NOT HARDWARE VERIFIED. Do not programme this
bitstream until the new RTL simulations and Vivado timing/CDC review pass.**

The existing **v0.7 on `V:\`** remains the hardware-proven 200/200,
12.75-µs two-FPGA RTT baseline. The **M4A on `W:\`** remains the host-probed
throughput reference. Extract this project separately and use **`X:\`**.

## What is implemented

- A new `ethernet_udp_a7_buffered` top reuses the original, frozen
  `feed_pipeline`, parser, top-of-book engine, and UART transmitter unchanged.
- **RX FIFO:** 16×128-bit dual-clock Gray-pointer FIFO, PHY RX 25 MHz -> core
  100 MHz. Full valid frames are either stored exactly once or dropped when
  full, with a saturating source-domain overflow counter.
- **TX FIFO:** 16×116-bit dual-clock Gray-pointer FIFO, core 100 MHz -> PHY
  TX 25 MHz *falling edge*. The proven UDP packet encoding, FCS, padding, and
  minimum IFG are retained in `mii_udp_tx_m4b`.
- **Diagnostic UART FIFO:** 8×116-bit synchronous queue, independently read
  by the UART state machine. When full, **only that diagnostic copy** drops;
  `debug_uart_drops` records the event. UART never backpressures Ethernet.
- Saturating 16-bit counts: `debug_rx_overflows`,
  `debug_rx_invalid_frames`, `debug_tx_frames`, `debug_uart_drops`. The
  source-domain counters are Gray encoded **in the source register** before
  crossing into sys_clk. They are marked for Vivado debug/ILA visibility,
  **not currently returned over UART**.
- Backpressure is explicit: TX FIFO full stalls the 100-MHz core's final
  result handoff, and the RX FIFO absorbs incoming records up to capacity.
  When the RX FIFO fills, valid incoming frames are *dropped and counted*.
  This is UDP: there is no network-level flow-control mechanism.
- Existing 100-MHz core accepts only one event at a time but can queue RX
  records and TX replies, unlike the UART-gated v0.7 single-mailbox design.

### Important limitations

- The original narrow lab UDP protocol (broadcast destination, fixed
  16-byte market-data packets, source IP and UDP port assumptions) remains;
  this is not a general-purpose Ethernet MAC/IP stack.
- Multi-bit FIFO CDC coherence, metastability assumptions, reset crossings,
  PCB MII skew, clock quality and overflow accounting under varied clock
  ratios require independent Vivado and physical tests. A Python source
  check cannot prove any of these.
- A full-rate local PHY/FPGA **packet generator with counters/histograms** is
  planned for M4C. Windows open-loop tests are still not a calibrated wire-rate
  throughput benchmark.
- UART debugging is intentionally **lossy during overload**. Do not claim a
  UART mirror for every accepted packet if `debug_uart_drops>0`.
- Simulated FIFOs are distributed storage; verify implementation resources,
  bus CDC classification and IOB output placement in post-route reports.
- The M4B RTL source, testbenches and TCL scripts are unverified in Vivado or
  Icarus within the authoring environment. If Windows reports errors, retain
  logs and send them back before attempting physical programming.

## Windows workflow

1. Extract to a new folder, open PowerShell from the *project root* (the
   folder containing `rtl`, `scripts`, `tests`).
2. Assign `X:` (use existing mapping removal only if necessary):

```powershell
subst X: (Get-Location).Path
Set-Location X:\
$env:Path = "C:\Programs\msys64\ucrt64\bin;$env:Path"
```

3. Run Python/reference/structural checks:

```powershell
python -m pytest -q tests
python scripts/check_m4b_candidate.py
```

4. Run Icarus tests including FIFO boundaries, deliberate source overflow, 22 consecutive minimum-spaced
   Ethernet frames and one mixed two-board compatibility regression:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\scripts\run_m4b_sim.ps1"
```

5. **Only if those pass:** build the separate Board B bitstream:

```powershell
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_m4b_endpoint.tcl
python scripts/audit_m4b_reports.py
```

6. ZIP the nine reports, upload for independent timing and CDC review:

```powershell
Compress-Archive -Path "X:\build\reports\ethernet_m4b_endpoint\*" `
  -DestinationPath "X:\build\reports\ethernet_m4b_endpoint_reports.zip" -Force
```

**Do not programme Board B yet.** Following report approval, programme only
Board B (historical `COM3`; verify USB-JTAG identity) with:

`X:\build\vivado_ethernet_m4b_endpoint\ethernet_m4b_endpoint.runs\impl_1\ethernet_udp_a7_buffered.bit`

Board A stays on verified v0.6 (`U:\`, `COM4`). Begin physical tests with
single, then 25/200 direct FPGA-to-FPGA exchanges; repeat M4A 5-ms/2-ms/1-ms
host tests only after confirming link and single-packet reception. **Compare
category-matched FPGA hardware RTT** to v0.7 (median 12.75 µs), and measure
sustained throughput with a future FPGA-native source (M4C).
