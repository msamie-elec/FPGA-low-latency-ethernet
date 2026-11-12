# Verification status, updated 29 October 2026

Refer to `RELEASE_STATUS.md` for historical v0.2 evidence and the separately
verified v0.4 echo diagnostic. These do NOT prove v0.3 main-board operation.

v0.3 verification to run: `python scripts/check_project.py`, Python unit
regression and C++ cross-check, accelerated RTL simulation, real UART clock
rate simulation, Vivado implementation reports, **and physical 10/10 board
transactions**. New FPGA hardware measurements remain pending.

The testbench uses FPGA-side pin names, but tests cannot verify actual PCB pin
mapping. Therefore the static XDC checks explicitly validate A9/D10 for the
A7. These checks must not be treated as substitutes for real hardware tests.
