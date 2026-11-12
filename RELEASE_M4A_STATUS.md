# M4A v0.8A — release status (11 November 2026)

**Purpose:** establish a safe, source-preserving burst acceptance baseline before altering FPGA RTL.

* 200/200 v0.7 FPGA-to-FPGA hardware transactions: USER-VERIFIED, uploaded CSV preserved.
* Paired v0.6/v0.7 RTT result: all 200 expected responses identical; 99.0% improvement in valid-report mean RTT.
* Original v0.7 RTL and constraints: 24/24 files hash-verified byte-identical.
* M4A Python tests + inherited tests: 39/39 PASS in local container.
* M4A physical host burst measurements: **NOT RUN**; must run on Windows with UE300C.
* M4B FIFO-based RTL buffering and autonomous FPGA load generator: **NOT YET IMPLEMENTED**.
* No modified FPGA bitstream, Vivado run, Icarus simulation or physical M4A network test is claimed.

Recommended next action: 200-packet gap=5ms calibration followed by gap=1ms and
zero-gap bursts. Test source is Python host; not a calibrated hardware wire-speed generator.

See README_M4A_START_HERE.md and docs/M4A_THROUGHPUT_BURST_CHARACTERISATION.md.
