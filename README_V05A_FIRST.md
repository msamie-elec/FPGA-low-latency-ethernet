# Read first: v0.5A M2B CDC and TX Timing Candidate

**Do not program this design into your Arty A7 yet.** This is a *new*
source-level engineering candidate correcting issues found in the user-provided
Vivado v0.5 timing and CDC reports dated 11 November 2026.

- v0.4B on R:\ is verified by 200/200 paced physical Ethernet-to-UART packets.
- v0.5 on S:\ passed RTL simulation but fails Vivado timing and has 147
  critical CDC findings. Leave it unchanged.
- v0.5A should be in its own folder, optionally mapped to T:\.

Changes:
1. TX mailbox: capture response length into `held_len`, then validate it
   in a separate TX-domain state. Avoid direct async length-to-control paths.
2. MII TX pins: request IOB packing of all five registered output signals,
   retaining realistic PHY setup/hold timing.
3. Add unsupported-length TX test and build-time timing/CDC release gate.
4. Add detailed TX setup/hold reports and a Python report-review tool.

Run from the new project root:

```powershell
python -m pytest -q tests
python scripts/check_m2b_candidate.py
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ethernet_m2b_sim.ps1
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_ethernet_m2b.tcl
python scripts/audit_m2b_reports.py
```

A successful compilation/bitstream alone is *not* sufficient. Do not claim
hardware readiness unless the fresh diagnostics are reviewed and the TX
setup, hold, and CDC gates are passed. The rest of the protocol is deliberately
unchanged.

See `docs/v0_5a_cdc_tx_timing_audit.md` for exact original v0.5 findings.
