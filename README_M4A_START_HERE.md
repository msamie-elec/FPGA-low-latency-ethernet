# FPGA M4A v0.8A — Throughput and Burst Acceptance Probe

**Purpose:** begin the next milestone after the successful v0.7 200/200 FPGA-to-FPGA
RTT optimisation, without risking the verified FPGA configuration.

This package is a **new PC-side validation toolset** built on byte-for-byte
unchanged v0.7 RTL and XDC files. It does not yet include an improved buffered
FPGA datapath or a new bitstream. The 200 hardware RTT rows for both v0.6 and
v0.7 are preserved in `docs/baselines/`.

## Quick steps

1. Keep the v0.7 Board B programmed; keep verified v0.6/v0.7 projects `U:`/`V:` unchanged.
2. Disconnect the **Board A↔Board B** Ethernet cable. Instead connect the ASUS
   laptop's **TP-Link UE300C** directly to **Board B** using RJ45, as in M2B tests.
3. Windows TP-Link address must be `192.168.77.1/24`; link should be **Up, 100 Mbps**.
4. Extract this ZIP to a **new** folder; open PowerShell in the
   `fpga-low-latency-networking` root, use `subst W: (Get-Location).Path`.
5. Run `python -m pytest -q tests` and `python scripts/check_m4a_source_freeze.py`.
6. Press/release BTN0 on **Board B**, allow link to settle, run:

```powershell
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 5 --drain-s 2 --require-all --csv build/hardware/m4a_gap5.csv
```

7. After a lossless calibration, **reset Board B** and characterise 1ms gap,
   **reset it again** and characterise gap=0 (loss expected):

```powershell
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 1 --csv build/hardware/m4a_gap1.csv
python scripts/m4a_burst_probe.py --pc-ip 192.168.77.1 --count 200 --gap-ms 0 --csv build/hardware/m4a_gap0.csv
```

8. Summarise after all three tests:

```powershell
python scripts/m4a_analyse_probes.py build/hardware/m4a_gap5.summary.json build/hardware/m4a_gap1.summary.json build/hardware/m4a_gap0.summary.json
```

**Upload the three `*.summary.json` and matching `*.csv` files.** We will use
those as baseline evidence for designing an 8/16-entry CDC FIFO and a dedicated
Board A hardware burst generator in M4B.

**Important:** Windows/USB Ethernet burst loss is not uniquely attributable to
FPGA RTL. This is a host-driven characterisation, not final FPGA throughput
signoff. M4B will provide FPGA-native traffic generation and hardware counters.

See `docs/M4A_THROUGHPUT_BURST_CHARACTERISATION.md` for design details.
