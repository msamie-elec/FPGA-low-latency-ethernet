# Windows validation runbook — main FPGA application v0.3

**Target:** Digilent Arty A7-35T, XC7A35TICSG324-1L, 100 MHz, UART 115200 8N1.
**Known PC:** Windows PowerShell, Icarus v12, Vivado 2025.2.1, COM4.
**Prerequisite:** v0.4 echo diagnostic on physical A7 already passed 5/5.

Work inside the v0.3 `fpga-low-latency-networking` folder (you should see
`rtl`, `scripts`, `tb`, `boards`). Keep the old v0.2 folder for backup.

## A. Check package and software

```powershell
python scripts/check_project.py
python -m pytest -q tests
```

Expect `PASS A7/S7 UART physical pin direction and top-level wiring` and 5
pytest passes.

## B. Compile and run accelerated UART + processing simulations

```powershell
New-Item -ItemType Directory -Force build | Out-Null
iverilog -g2012 -s tb_feed_pipeline -o build/tb_feed_pipeline.vvp rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv tb/tb_feed_pipeline.sv
vvp build/tb_feed_pipeline.vvp
iverilog -g2012 -s tb_board_uart -o build/tb_board_uart.vvp rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart.vvp
```

Expect `PASS: 7 reports, 3 rejected frames, backpressure hold checked` and
`PASS tb_board_uart: 2 correct reports, malformed and ignored responses`.

## C. Test UART at actual A7 clock and baud rate

This test has many more cycles and takes longer than the accelerated bench.

```powershell
iverilog -g2012 -DREAL_UART_BAUD -s tb_board_uart -o build/tb_board_uart_115200.vvp rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart_115200.vvp
```

Expect `PASS tb_board_uart: 2 correct reports, malformed and ignored responses`.
If it fails, **do not** proceed to programming the revised bitstream.

## D. Build corrected main-project bitstream

```powershell
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_vivado.tcl -tclargs a7-35
```

Inspect `build\reports\a7-35\timing_summary.rpt` for setup and hold
violations and review any `ERROR` or `CRITICAL WARNING` messages. Previous
v0.2 timing numbers do not apply automatically to this new implementation.

## E. Program the correct design

In Vivado Hardware Manager connect to your `xc7a35t_0` and select **Program
Device**. Select the generated **v0.3 main-project** file:

```
build\vivado_a7-35\fpga_feed_a7-35.runs\impl_1\board_uart_a7.bit
```

Do **not** select the echo diagnostic `arty_a7_uart_echo.bit`, and do not reuse
v0.2's `board_uart_a7.bit`. Verify `End of startup status: HIGH` and that
LD4 blinks. Press/release BTN0.

## F. Complete ten-record hardware regression

```powershell
python -m pip install pyserial
python scripts/uart_board_test.py --port COM4
```

Expected: `PASS record 00` through `PASS record 09`, then
`PASS 10 board transactions (independent Python reference oracle)`.

Arty physical LEDs: LD4 heartbeat; LD5 latched trading signal; LD6 latched
malformed/UART error; LD7 toggles on completed response. With ten responses
LD7 may end OFF. LD6 is expected to latch ON because one intentionally
malformed request is included.

If it fails, save the **full printed output**, note all LED states, and
confirm which bitstream Vivado has loaded before changing RTL. `COM4 OPEN`
proves port access but not UART transaction correctness.

## Evidence to share for engineering review

1. PowerShell outputs from B, C and F.
2. `build\reports\a7-35\timing_summary.rpt` and `utilization.rpt` from D.
3. Screenshot of the Program Device path or Vivado Tcl Console showing
   the `PROGRAM.FILE` location and successful `program_hw_devices`.
