# M4C v0.9: Final hardware-native benchmark - validated

**Status as of 11 November 2026:** Software regression passed (52 Python tests); Board A/B RTL simulation passed; Vivado routed design passed preliminary setup/hold checks; and M4C physical benchmark completed with 9 of 9 runs returning all 1,000 unique replies. The main [README](README.md) and the [final report](docs/VERIFICATION_AND_PERFORMANCE_V1.md) supersede this development-era status page.

Board A v0.9 sends hardware-paced packets at three nominal request intervals (100/20/10 us). Board B remains the v0.8B FIFO endpoint. Each profile was repeated three times, with 1,000 packets per run. The achieved launch-request gaps were exactly 10,000/2,000/1,000 cycles at 100 MHz, with zero late launches; all 9,000 unique replies were recorded. One additional 1,000/1,000 profile A smoke test was also recorded.

Interpretation: FPGA request-launch timing and successfully received responses during finite bursts, **not wire timestamps or long-duration sustainable throughput**. Full method: [M4C protocol](docs/M4C_BENCHMARK_PROTOCOL.md).

Test from project root:

```powershell
python -m pytest -q tests
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\\scripts\\run_m4c_sim.ps1"
python scripts/m4c_hardware_benchmark.py --com COM4 --profile all --repeat 3 --csv build/hardware/m4c_final_3x3.csv
```

Hardware link: Board A Ethernet RJ45 **directly to** Board B Ethernet RJ45; both boards independently powered/programmed via USB. Do not connect Board B to the UE300C for the A/B benchmark.

This was the final planned technical milestone. v1.0 portfolio release documents are included; no further Ethernet feature iteration is planned.
