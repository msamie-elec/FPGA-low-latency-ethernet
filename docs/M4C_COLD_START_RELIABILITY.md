# M4C first-burst and cold-start reliability protocol

## Goal and scope

Determine whether a Profile C (1,000-request, nominal 10 µs launch period)
burst fails **on the first attempt after startup/reset** but succeeds on a
subsequent attempt without an intervening reset. Existing Board A v0.9 and
Board B v0.8B FPGA designs, bitstreams, XDCs, and the existing
m4c_hardware_benchmark.py are **not changed**.

The host utility reuses the existing benchmark's 40-byte UART decoder and
records every attempt. It does not send Ethernet frames itself, reprogram the
FPGA, toggle BTN0, modify HDL, silently retry, or measure PHY wire timings.

Earlier Profile C tests included failed bursts followed by successful bursts.
Those observations motivate this test, but are **not** proof that power-on
initialization is the cause.

## Before starting

1. Back up any existing build/hardware/m4c_hardware_benchmark.csv and its
   .summary.json from previous tests. Preserve earlier failed Profile C evidence.
2. Verify programmed bitstreams: **Board A** = ethernet_generator_a7_m4c
   (v0.9), **Board B** = ethernet_udp_a7_buffered (v0.8B).
   Do not interchange the A and B images.
3. Each board has independent USB power/JTAG/UART; one direct RJ45 cable
   joins the two Ethernet sockets. Recheck the current COM mapping.
4. Check physical link/PHY LEDs and verify board programming. Link LEDs
   alone do not demonstrate UDP correctness.
5. In PowerShell at the project root install pyserial if needed:

       python -m pip install pyserial

## Step 1 — Repeated BTN0 reset test (start here)

Run:

    python scripts/m4c_cold_start.py --com COM4 --mode reset --profile C --cycles 10 --warm-runs 1

The utility opens Board A UART before its first operator prompt.
For **each cycle**:

1. Press and release BTN0 on **both** FPGAs (never leave either held down).
2. Wait for the Ethernet link to settle; confirm both bitstreams remain programmed.
3. Type READY, then Enter. A first C command is issued immediately after
   confirmation; Board A returns one 40-byte FPGA telemetry packet.
4. Without resetting either FPGA, the script runs one warm C burst after
   a 0.2-second gap and saves a separate report.
5. Repeat even when the first burst fails. Do not send manual test commands
   in between the two measurements.

READY is a manual confirmation, not a precise hardware timestamp. This
cannot measure the interval from BTN0 release to first frame.

## Step 2 — Real power-cycle test (separate experiment)

Run a **new** session:

    python scripts/m4c_cold_start.py --com COM4 --mode power-cycle --profile C --cycles 5 --warm-runs 1

For each cycle, remove both USB power supplies, restore them, then
**reprogram both FPGAs using their correct bitstreams** if they were
configured only through volatile JTAG (rather than verified nonvolatile
configuration memory). Check both programmed status and Ethernet link,
then type READY. If Windows changes the COM port, stop and restart the
utility with the new port; the earlier session remains preserved.

Do not confuse BTN0 reset with true electrical power cycling. Without
external timing instrumentation, this checks first-burst reliability after
manual configuration, not exact power-on or PHY link negotiation time.

## Evidence and interpretation

Every invocation creates a new, timestamped folder:

    build/hardware/cold_start/cold_start_YYYYMMDDTHHMMSSffffffZ/

The folder contains **results.csv**, one row per first/warm attempt
(including raw UART bytes, failed/partial replies, counters and spacing),
and **summary.json**, updated throughout the run with pass/fail counts.

These outputs are local under Git-ignored build/. They never overwrite
the earlier benchmark evidence.

A burst passes when all 1,000 unique valid replies are counted with zero
missing, duplicate, invalid or unexpected replies in the FPGA's fixed drain
window. An absent or malformed UART report is an explicit ERROR, not a
silent retry. Exit code 2 indicates at least one failure or incomplete test.

| First burst | Warm burst | Meaning |
|---|---|---|
| Pass | Pass | Startup worked in that cycle |
| Fail | Pass | Startup/state dependence is plausible; inspect reset, link readiness and path state |
| Fail | Fail | Persistent fault or setup problem is plausible; check UART, bitstreams and link |
| Pass | Fail | Intermittent fault; inspect buffering and run-to-run state |

**Measurement boundary:** 100,000 requests/s is FPGA request-launch
spacing within finite bursts, not independently measured wire speed,
long-term sustainable throughput or processing RTT. Missing replies
cannot be assigned specifically to Board B. The tool does not expose
Board B FIFO overflow counters or report packet jitter.

Only after reviewing raw telemetry and first/warm pass rates should we
decide whether additional RTL-level debugging is justified. Never
change frozen HDL or constraints automatically as a response to loss.
