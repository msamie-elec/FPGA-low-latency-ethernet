# v0.5A — CDC / MII TX Timing Audit and Candidate Fix (11 November 2026)

## Status

**ENGINEERING TEST CANDIDATE — NOT APPROVED FOR FPGA PROGRAMMING.**

The complete v0.5 design was simulated by the user on 11 Nov 2026 and all
four Icarus testbenches passed. The *routed* 2025.2.1 Vivado reports from
`ethernet_m2b_reports.zip` are substantially more informative and identify
real implementation blockers. Those reports describe the **original v0.5**,
not the revised v0.5A package.

| Measured v0.5 item | Value | Interpretation |
|---|---|---|
| Overall setup WNS | **-0.873 ns** | FAIL; five MII TX output endpoints |
| Setup TNS | **-3.765 ns** | FAIL |
| Overall hold WHS | +0.050 ns | PASS, constrained paths only |
| System 100 MHz WNS | +1.810 ns | PASS |
| Ethernet RX 25 MHz WNS | +7.123 ns | PASS |
| Ethernet TX 25 MHz WNS | **-0.873 ns** | FAIL |
| CDC-1 | **147 Critical** | FAIL, mainly async response length logic controlling TX FSM/CE |
| CDC-15 | 264 Warnings | Multi-bit mailbox checks must be justified |
| CDC-3 | 5 Info | Recognised synchronizers |
| CDC-9 | 2 Info | Recognised reset synchronizers |
| Methodology | TIMING-9 (1), TIMING-18 (12) | Unknown CDC and missing/partial external delays |
| Logic | 845 LUT, 1158 FF, 369 slices | 4.06%, 2.78%, 4.53% |
| Power | 0.069 W medium confidence | Not a board power measurement |

### Root cause 1 — critical CDC control logic

In original `rtl/mii_udp_tx.sv`, IDLE state had:

```
if ((req_sync != ack_toggle) &&
    ((response_len == 4'd1) || (response_len == 4'd14))) ...
```

`response_len` originates in the **100 MHz** domain. Although a two-flop
synchronizer protects `req_toggle_async`, the raw `response_len` bus went
through combinational logic to **25 MHz** TX-domain state and register enable
pins. This accounts for 147 critical `CDC-1` paths (in addition to expected
clock-enable controlled multi-bit mailbox warnings).

### Candidate source change

The IDLE state now uses **only** `req_sync != ack_toggle` to capture the held
multi-bit data and length into TX-domain `held_data` / `held_len` registers.
A new `VALIDATE` state checks the already captured `held_len` before initiating
transmission. Unsupported lengths generate an acknowledgement but no frame;
this avoids deadlock. The source data remains stable until acknowledgement,
as guaranteed by the 100 MHz producer. This is an open-loop coherent bus
transfer with single-entry handshake; physical CDC/metastability and reset
stress verification are still required.

### Root cause 2 — MII TX setup timing

The original TX output register is clocked on **falling** `eth_tx_clk` and
DP83848J samples on the next **rising** edge. Therefore setup must close in
half of a 40 ns period. Vivado's worst TX path:

```
Clock domain: eth_tx_25mhz
From:         u_mii_tx/eth_txd_reg[1]/C
To:           eth_txd[1]
Requirement:   20.000 ns (fall -> rise)
Data path:     5.670 ns
Clock insertion at FF: 5.167 ns
PHY output setup budget: 10.000 ns
Worst slack:  -0.873 ns
```

### Candidate constraint change

We leave the DP83848J specification **unchanged**: minimum 10 ns setup and
0 ns hold at 100 Mbps. We add `set_property IOB TRUE` for the five outgoing
MII pins. This asks Vivado to pack the output flip-flops into I/O blocks,
reducing fabric-to-pad delay. This is not proven until a new place-and-route
confirms IOB packing, positive TX output WNS/WHS, and the PHY board-skew
allowance. If IOB packing does not solve it, we must re-architect the output
registering/clock phase rather than weaken timing requirements.

Reference: Texas Instruments DP83848x data sheet, section 100 Mb/s MII
Transmit Timing: TX_CLK high/low 16..24 ns, TXD/TX_EN setup >=10 ns,
hold >=0 ns. AMD Vivado UG912 `IOB` placement property.

### Remaining audit limitations

- `CDC-15` warnings (RX and TX multi-bit mailboxes) need deliberate stable-data
  handshake verification; a CDC-1 count of zero is not functional proof.
- Source-synchronous TX constraints omit board clock/data trace skew; PHY
  timing needs electrical/PCB sign-off.
- `TIMING-18` warnings include btn0, LEDs, UART, PHY reset, PHY reference
  and, in methodology reporting, clock-edge-specific TX output warnings.
  Do not hide the TX warnings by removing realistic setup/hold constraints.
- Power estimate assumes vectorless activity and is not measured on board.
- This system handles **100 Mbps** PHY operation only in its current timing
  constraints. The link must negotiate 100 Mbps.

## Instructions for a new candidate implementation

1. Extract this package into a **new directory** distinct from known-good
   `R:\` (v0.4B) and `S:\` (original v0.5). Map it to `T:\` if convenient.
2. Run `python -m pytest -q tests` and
   `python scripts/check_m2b_candidate.py`.
3. Run PowerShell simulation script
   `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ethernet_m2b_sim.ps1`.
   The `tb_mii_udp_tx` test now includes an invalid-length mailbox case.
4. Only after simulation succeeds, run Vivado 2025.2.1:

```
& "C:\AMDDesignTools\2025.2.1\Vivado\bin\vivado.bat" -mode batch -source scripts/build_ethernet_m2b.tcl
```

5. The Tcl script writes diagnostics, then **fails the build release gate**
   if the worst constrained setup slack is negative or any critical CDC-1
   is reported. A bitstream file can still exist after a failed gate; it
   must not be programmed.
6. Run `python scripts/audit_m2b_reports.py` to independently summarise
   the reported WNS/WHS/CDC-1 and methodology status.
7. Archive and upload `build\reports\ethernet_m2b\` (including new
   `tx_output_setup.rpt` / `tx_output_hold.rpt`) for review.
8. Do **not** program v0.5A until timing, CDC, simulation and outstanding
   PHY assumptions have been reviewed together.

## Preserved baseline

The original `rtl/ethernet_uart_a7.sv`, `boards/arty_a7/ethernet_m2a.xdc`
and the proven v0.4B hardware path remain unchanged. The 200/200 host-paced
Ethernet-to-UART pass is a physical v0.4B result, not evidence that this
v0.5A TX candidate works on the board.
