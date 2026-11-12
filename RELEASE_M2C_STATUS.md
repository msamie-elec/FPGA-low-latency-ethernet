# M2C v0.6 release status

2026-11-11. **NOT RELEASED FOR PHYSICAL FPGA PROGRAMMING.**

- Previous Board B v0.5A RTL is frozen; user's hardware-verified baseline has 200/200 UDP+UART PASS.
- New Board A generator, MII feed TX, MII reply RX, 100MHz RTT timer and UART protocol implemented as source-level **engineering candidates**.
- Python frame and software oracle: 22 tests passing in assistant environment.
- RTL simulation: **NOT RUN** here; user must run `scripts/run_m2c_sim.ps1` on Windows.
- Vivado synthesis/route/CDC/timing: **NOT RUN** here; build generator and upload reports.
- Physical two-board Ethernet: **NOT RUN**.
- Architecture qualification: direct RJ45 link, one outstanding request; B v0.5A UART-before-UDP behaviour makes RTT serial-dominated. No low-latency performance claim.

Read `README_M2C_START_HERE.md` first and preserve R:/T: project versions intact.
