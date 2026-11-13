# Simulation waveform: a readable Board A → Board B → Board A packet journey

This is an **idealised MII simulation** (25 MHz four-bit Ethernet interface) of two independent Artix-7 designs. It is not a physical cable/PHY timing measurement, a post-route simulation, or a proof of sustained hardware line rate.

## One-command grouped Vivado view

A waveform-setup script is tracked in Git:

```text
sim/waves/setup_demo.tcl
```

After launching **Run Simulation → Run Behavioral Simulation** using `tb_m4c_board_pair`, use Vivado's **Tcl Console** (not Windows Command Prompt). First change to your extracted repository folder; for example (adjust to your own new version directory):

```tcl
cd {C:/Mohammad/Electronics/FPGA/Projects/FPGA_Low_Latency_Network/Low-latency-ethernet_v4}
source sim/waves/setup_demo.tcl
restart
run all
```

The script creates five ordered waveform groups, leaving the original `Untitled` view untouched. It saves a reusable `sim/waves/dual_board_demo.wcfg` in your **local repository**. This .wcfg does **not** include value history; rerun after the signals have been added so the simulator records their transitions. If `get_objects` reports a missing probe, make sure the **updated testbench** is in the project and relaunch simulation. The generator is not a replacement for the user-saved .wcfg: once the GUI view has been verified, include the generated `dual_board_demo.wcfg` in the PR too.

### What each group proves

| Stage | Signals in testbench | Meaning |
| --- | --- | --- |
| Control and result | `active_profile`, `profiles_passed`, `all_profiles_pass` | Current A/B/C traffic profile and verified scoreboard result. PASS is asserted only after all existing assertions pass. |
| Request transmit | `atxen`, `atxd`, `a2b_byte_valid`, `a2b_byte`, `a2b_payload_valid`, `a2b_payload_byte` | Complete request bytes reconstructed from **Board A's actual MII TX** (low nibble first). |
| Endpoint accept | `b_rx_frame_valid`, `b_reply_enqueued` | Board B validated the frame and subsequently queued a reply in its Ethernet TX FIFO. |
| Reply transmit | `btxen`, `btxd`, `b2a_byte_valid`, `b2a_byte`, `b2a_payload_valid`, `b2a_payload_byte` | Complete response bytes reconstructed from **Board B's actual MII TX**. |
| Scoreboard receive | `a_reply_staged`, `a_unique_replies`, `tx_frame_count`, `count`, `tel_err` | Board A staged a received response and updated the unique-reply scoreboard; UART report bytes arrived without framing error. |

`a2b_byte` and `b2a_byte` contain preamble, MAC, IP, UDP, payload and FCS, including the repeated `55` preamble bytes. The payload-only signals are meaningful **only when** the corresponding `*_payload_valid` pulse is high. The monitor selects request bytes 50..65 (16-byte fixed feed) and reply bytes 50..63 (14-byte response). Byte zero is the first preamble byte. These are **passive simulation probes**, not hardware instrumentation. The MII signals in this testbench are wired directly together, so they do not model PHY propagation delay, packet loss or clock skew.

### Make a useful screenshot for GitHub

1. Run `restart; run all` with the new monitor signals in the trace.
2. In the waveform pane, zoom to **a single request-and-reply exchange**, rather than all ~12 ms. Find a rising `atxen`, followed by `b_rx_frame_valid`, `b_reply_enqueued`, `btxen`, `a_reply_staged`, and an increment in `a_unique_replies`.
3. Expand only the useful groups; set byte buses to hexadecimal radix. If the detail is too crowded, hide the raw 4-bit nibble signals, keeping `*_payload_valid` and `*_payload_byte`.
4. Capture a real high-resolution Vivado screenshot with readable signal names and timestamps. Save it as `docs/images/dual_board_packet_journey.png`. Add that image and the generated `dual_board_demo.wcfg` to Git **after** inspection, not before.
5. A second screenshot of the ending `all_profiles_pass=1` / the `PASS tb_m4c_board_pair` Tcl output is optional, and should be explicitly labelled as **simulation**, not a physical board measurement.

## Validation and limitations

The pre-existing regression asserts that all 8 replies match each A/B/C profile, that the transmit frame counts match, that duplicates/invalid frames are zero and that selected launch-gap telemetry is within its expected tolerance. The demonstration monitor only reconstructs MII bytes and exposes internal status; it does not substitute for those checks. The reusable wave setup is designed for Vivado 2025.2.1, and requires an actual Vivado GUI test to verify its layout and save/open behaviour. GitHub CI uses Icarus Verilog and cannot validate XSim .wcfg rendering.
