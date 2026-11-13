# Arty A7 physical I/O and XDC reference (Board A / Board B)

**Applies to:** final M4C v0.9 traffic generator and M4B v0.8B buffered endpoint; Digilent **Arty A7-35T**, device `xc7a35ticsg324-1L`; Vivado 2025.2.1. Read this alongside [the Vivado GUI guide](VIVADO_GUI_QUICKSTART.md).

## Why there are two XDCs

There are **two physical FPGAs**, each separately configured, not two halves of a single FPGA. Both use the same Arty A7 Ethernet and LED pin mappings. **Board A** has a UART *input* to accept the profile character and a UART *output* to return the 40-byte summary. **Board B** only uses its UART *output* for optional diagnostics. Applying Board A's XDC when Board B is the selected top can produce wrong/missing port constraints, and vice versa.

| Board | Top-level RTL | Source XDC in repository | Generated GUI constraint set | GUI XDC |
|---|---|---|---|---|
| **A — generator** | `ethernet_generator_a7_m4c` | `boards/arty_a7/ethernet_m4c_generator.xdc` | `constrs_board_a` | `build/v/xdc/A.xdc` |
| **B — endpoint** | `ethernet_udp_a7_buffered` | `boards/arty_a7/ethernet_m4b_endpoint.xdc` | `constrs_board_b` | `build/v/xdc/B.xdc` |

The project generator writes *derived* GUI XDCs; it does not modify the frozen source XDCs. Two XDC-embedded port-count `if` guards are moved to `vivado/check_mii_ports.tcl` because Vivado XDC parsing does not support them there; generated copies also set `CFGBVS VCCO` and `CONFIG_VOLTAGE 3.3` for the board's configuration bank. **Do not hand-edit generated `build/v/xdc` files as the source of truth.**

## Port directions and physical pins

All listed user I/O pins use `LVCMOS33` according to the source XDCs. `eth_*` connect FPGA logic to the board's Ethernet PHY, **not** directly to a second FPGA's pins: the two boards are joined through their RJ45 magnetics/cable.

| RTL port | Direction at FPGA | PACKAGE_PIN | Role |
|---|---|---|---|
| `clk` | input | E3 | 100 MHz onboard system oscillator |
| `btn0` | input | D9 | User-operated **active-high reset request**; press **and release** |
| `led[0]` … `led[3]` | outputs | H5, J5, T9, T10 | FPGA design indications; **not** a packet-integrity proof |
| `uart_rx_i` | **A input only** | A9 | Laptop UART → Board A; single ASCII `A`, `B` or `C` |
| `uart_tx_o` | output, both | D10 | Board A 40-byte benchmark telemetry / Board B debug |
| `eth_ref_clk` | output | G18 | FPGA-generated 25 MHz PHY reference |
| `eth_rstn` | output | C16 | Active-low PHY reset control |
| `eth_rx_clk` | input | F15 | PHY MII receive clock (25 MHz nominal) |
| `eth_rx_dv` | input | G16 | PHY RX data valid |
| `eth_rxerr` | input | C17 | PHY RX error indication |
| `eth_rxd[0:3]` | inputs | D18, E17, E18, G17 | 4-bit MII receive nibble bus, bit order 0–3 |
| `eth_tx_clk` | input | H16 | PHY MII transmit clock (25 MHz nominal) |
| `eth_tx_en` | output | H15 | MII transmit enable |
| `eth_txd[0:3]` | outputs | H14, J14, J13, H17 | 4-bit MII transmit nibble bus, bit order 0–3 |

A has **23 top-level I/O bits**; B has **22**, because B has no `uart_rx_i` input. The Ethernet PHY receives and transmits 4-bit MII nibbles at 25 MHz for 100 Mb/s signalling; this is **not** a Gigabit Ethernet interface.

## Timing intent in the source constraints

| XDC item | Definition / design intent | Qualification |
|---|---|---|
| `sys_100mhz` | 10.000 ns on `clk` | System/control clock |
| `eth_rx_25mhz` | 40.000 ns on PHY RX clock input | Separate PHY clock domain |
| `eth_tx_25mhz` | 40.000 ns on PHY TX clock input | Separate PHY clock domain |
| `phy_ref_25mhz` | `create_generated_clock -divide_by 4` on `div4_reg[1]/Q` | Derived 25 MHz PHY reference; output quality not electrically characterised |
| PHY receive input delay | Min 10 ns / max 30 ns relative to RX clock | **Exploratory** PHY-derived assumptions; PCB skew/PVT not fully modelled |
| PHY transmit output delay | Min 0 ns / max 10 ns relative to TX clock | **Provisional** PHY setup/hold model; lacks full PCB/uncertainty budget |
| `IOB TRUE` | TX enables/data packed into I/O register resources | Avoid excessive fabric-route delay |
| Clock groups | System+generated PHY reference, RX PHY, and TX PHY grouped asynchronously | CDC crossing must be justified **independently** |

**Not completely constrained:** BTN0 and Board A UART RX are asynchronous external controls, while PHY reset/reference, diagnostic UART TX and LED outputs require their own interface-appropriate timing decisions. The local Vivado reports still show **13 Board A / 12 Board B TIMING-18** missing-delay methodology instances. It would be incorrect to invent delay numbers merely to erase warnings.

## Mandatory build checks

In Vivado **Tcl Console**, from the repository root:

```tcl
source vivado/board_config.tcl
fpga_select_board A
report_compile_order -constraints
# after archiving A, select B
fpga_select_board B
report_compile_order -constraints
```

For the selected board, confirm exactly one *effective* GUI XDC is used for **both synthesis and implementation**. A constraints-set name on the screen is **not enough**: an earlier run had an empty B constraint set, unconstrained pins and meaningless timing. Never bypass `NSTD-1` or `UCIO-1` DRCs. Inspect the actual pin/clock report, post-route DRC and timing summary before generating/programming bitstreams. See [acceptance notes](VIVADO_2026-11-13_ACCEPTANCE.md), [known limitations](LIMITATIONS_V1.md).

## Connection diagram

```text
  Windows laptop                   Windows laptop
  USB/JTAG/UART (A)                USB/JTAG/UART (B)
        |                                  |
    [Arty A7-35T] === direct RJ45 === [Arty A7-35T]
      Board A           100 Mb/s         Board B
      generator                          endpoint

   A UART RX: profile A/B/C           B UART TX: debug only
   A UART TX: 40-byte result          B accepts/processes/replies
```

**COM4/COM3 were the local operator's observed ports on 13 Nov 2026; they are *not* pinned in XDC or guaranteed on another computer.** To identify the proper Windows COM port, run `python -m serial.tools.list_ports -v` in **PowerShell**, and unplug/replug one USB cable at a time if necessary. Vivado Hardware Manager identifies JTAG cables, not necessarily which Windows COM number belongs to each board.
