# v0.4B CDC and provisional MII timing patch — 2026-10-31

## Source of findings (Vivado 2025.2.1 routed v0.4A, Arty A7-35T)

- CDC-1 critical on `u_mii/reject_toggle_reg/C` to `bad_meta_reg/D` (25 MHz to 100 MHz). The first metastability stage was consumed by application logic (`bad_sync != bad_meta`).
- CDC-3 recognised two-stage synchronisers for request and acknowledgement.
- 128 CDC-15 warnings for the stable-payload mailbox: protocol-level coherency must be tested; no per-bit synchronisation is intended.
- Missing 7 Ethernet RX input-delay constraints and no derived clock at the PHY reference output.
- Original 100MHz and 25MHz internal timing slacks passed, but did not time external MII input delays or certify the clock output.

## v0.4B changes

1. `rtl/ethernet_uart_a7.sv`: added destination-domain `bad_seen`, event detection only on `bad_sync`, never on `bad_meta`. Both `bad_meta` and `bad_sync` remain annotated `ASYNC_REG`.
2. `boards/arty_a7/ethernet_m2a.xdc`: added **provisional** `set_input_delay -min 10 -max 30 ns` for MII RX data, RX_DV and RX_ER from TI DP83848J 100Mbps Tco specs, with board clock/data skew **not yet characterised**. Do not treat these as board-level sign-off.
3. Defined `/4` generated clock on `div4_reg[1]/Q`; Vivado must confirm that the clock propagates to `eth_ref_clk`. This does **not** certify output waveform, jitter or X1 requirements. An MMCM+ODDR based approach may be a later improvement.
4. Extended the UART integration testbench to send a bad-FCS frame first and observe sticky error LED, then verify two normal frames.
5. Expanded Vivado post-route reports and fail if no generated clock reaches the PHY output.

## Explicitly unresolved

- User must execute iverilog RTL simulation and Vivado synthesis/implementation; neither has been run on this patch at release.
- Reinspect detailed CDC report: expect no CDC-1 for rejection toggle; 128 CDC-15 bus warnings need justification via mailbox request/ack protocol, hold stability, and stress test with random phase/reset and back-to-back traffic.
- Revise RX input-delay values once board-level data/clock skew are established. TI device timing alone is insufficient.
- Prove reference clock waveform/phase/duty/jitter at PHY, and that link negotiates at 100Mb/s (10Mb/s MII timing differs).
- No ethernet-to-ethernet TX implemented; replies are still via USB UART. Keep v0.3 baseline unchanged.

## Windows PowerShell commands from extracted project root

```powershell
python -m pytest -q tests
python scripts/check_ethernet_m2a.py
python scripts/check_v04b_cdc_and_constraints.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ethernet_sim.ps1
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_ethernet_m2a.tcl
```

After passing implementation, inspect the reports in `build/reports/ethernet_m2a/` (especially `cdc.rpt`, `check_timing.rpt`, `timing_summary.rpt`, `clock_interaction.rpt`, `methodology.rpt`). Do **not** program hardware until review.
