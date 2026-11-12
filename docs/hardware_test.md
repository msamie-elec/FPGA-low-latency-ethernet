# Digilent Arty A7 / S7 board bring-up instructions

## Identify your exact FPGA variants first

| Printed board | Vivado `-tclargs` target | FPGA device | Test clock |
|---|---|---|---|
| Arty A7-35T | `a7-35` | XC7A35TICSG324-1L | 100 MHz |
| Arty A7-100T | `a7-100` | XC7A100TCSG324-1 | 100 MHz |
| Arty S7-25 | `s7-25` | XC7S25-1CSGA324C | 12 MHz |
| Arty S7-50 | `s7-50` | XC7S50-1CSGA324C | 12 MHz |

Source: Digilent published board manuals and official XDC pin assignments:
* https://digilent.com/reference/programmable-logic/arty-a7/reference-manual
* https://digilent.com/reference/programmable-logic/arty-s7/reference-manual
* https://github.com/Digilent/digilent-xdc

Verify PCB revision and *exact device* with your actual hardware before using
provided XDC/part selection. This software has not been programmed onto your
boards from this environment.

## Stage 1: synthesize and build bitstream in Vivado

1. Install a Vivado release supporting your exact 7-series FPGA.
2. Open a terminal with `vivado` on PATH; from repository root run:
   `vivado -mode batch -source scripts/build_vivado.tcl -tclargs a7-35`
3. Inspect terminal logs for warnings/errors, read
   `build/reports/a7-35/timing_summary.rpt` and ensure no timing violations.
4. Open Vivado Hardware Manager, connect the Arty over its USB/JTAG port,
   and program the corresponding `.bit` file. The Tcl flow prints its path.
5. Ensure BTN0 is not held; press and release it once to reset the test state.

For S7, use the matching `s7-25` or `s7-50` variant, not an A7 part.

## Stage 2: test serial input/output

**IMPORTANT:** Do not program the `arty_a7_uart_echo.bit` diagnostic for this
stage. Instead, select the **NEW main-project** `board_uart_a7.bit` built from
this corrected project. `tty`/COM port access is independent of JTAG.

Validate both accelerated and physical-rate RTL simulations first:

```powershell
# From the project folder (PowerShell)
New-Item -ItemType Directory -Force build | Out-Null
iverilog -g2012 -s tb_board_uart -o build/tb_board_uart.vvp rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart.vvp
iverilog -g2012 -DREAL_UART_BAUD -s tb_board_uart -o build/tb_board_uart_115200.vvp rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart_115200.vvp
```

For real hardware, verify the **new** bitstream was programmed successfully,
not merely generated, and that the clock and reset work. Confirm the serial
port is openable (`COM4` is known accessible on the user system).


The physical Arty A7 UART mapping was independently verified by the
five-byte echo test on 29 October 2026: PC TX -> FPGA RX A9;
FPGA TX D10 -> PC RX. Previous v0.2 bitstreams have these reversed and
**must not be reused** for host-to-FPGA tests.

Your onboard FTDI USB connection should enumerate as a serial device on the
host system (Windows: COMxx; Linux often `/dev/ttyUSB1`). Find the **UART**
channel, not the JTAG programming channel. No external USB-to-TTL cable is needed.

Run:

```bash
python -m pip install pyserial
python scripts/uart_board_test.py --port COM4
```

Change COM4 to the actual port; 115200 baud, 8 data, no parity, 1 stop bit.
Reset board before starting the test to clear stale symbol values and realign
record counter. The host sends one 16-byte frame and waits for one full reply.

Expected: `PASS record 00` through `PASS record 09`, then
`PASS 10 board transactions`. Actual status will be unknown until you run it.

On Arty A7 physical board: LD4 (`led[0]`) blinks; LD5 (`led[1]`)
latches after a qualifying spread; LD6 (`led[2]`) latches on a malformed
record or UART error; LD7 (`led[3]`) toggles per response. After ten responses
LD7 may return OFF. These indicators differ from the separate echo diagnostic.


### If the test fails

* No COM port: check FTDI driver, cable and Device Manager / `ls /dev/ttyUSB*`.
* UART framing or report mismatch: confirm board clock and correct bitstream;
  press BTN0 and rerun. Try a different cable before changing HDL.
* Vivado rejects constraints: ensure board version and top module match TCL.
* Timing violations: do not regard bitstream as verified even if it programs.
* UART data loss: host should not send two requests without waiting for reply;
  there is deliberately no RTS/CTS flow control in this test harness.

## Stage 3: collect objective evidence

Retain bitstream build log, utilization, WNS/TNS and timing summary, power
estimate with assumptions, board type/revision, baud, serial test transcript,
and any logic-analyser captures. These form the evidence needed for an
interview-ready repository. No measurements have been fabricated.

## Future Ethernet test (not included)

Use two A7 boards with PHY/MII and verified clock-domain crossings, a MAC
including frame check sequence handling, Ethernet/IPv4/UDP validation, and
packet-to-record adaptation. First perform MAC loopback and PC-generated packet
capture tests, then independent A7-to-A7 generation/receive tests.
