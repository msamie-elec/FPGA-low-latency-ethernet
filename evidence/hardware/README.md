# Physical two-board test evidence — reviewed operator uploads

The files in this folder are **captured test results**, not test source code. Run utilities remain in `scripts/`; generated ongoing captures remain in ignored `build/hardware/`. Each uploaded source file is stored here **exactly once**, with a descriptive, immutable filename.

## Captured experiments

| Session | Procedure / mode in data | Operator-confirmed first | Warm | Total valid unique replies | Missing / duplicate / unexpected / invalid / late |
|---|---|---:|---:|---:|---|
| **13 November 2026** | `reset`: manual BTN0 reset, PHY link ready, 10 cycles | **10/10 PASS** | **10/10 PASS** | **20,000** | 0 / 0 / 0 / 0 / 0 |
| **14 November 2026** | `power-cycle` software mode, following operator-confirmed overnight power-off and reprogramming; 5 software cycles | **5/5 PASS** | **5/5 PASS** | **10,000** | 0 / 0 / 0 / 0 / 0 |

Both experiments used **Profile C**, 1,000 requested packets per burst, nominal 10 microseconds between FPGA request launches; UART telemetry reported 1,000 min/max 100 MHz cycles (100,000 requests/s finite-burst *launch* rate). Each record contains 40 UART bytes. CSV and JSON were both checked: all rows/statuses/counters agree between paired files.

### 13 Nov — reset

- [CSV](2026-11-13_btn0_reset_C_10cycles.csv)
- [JSON](2026-11-13_btn0_reset_C_10cycles.json)
- Local source session: `build/hardware/cold_start/cold_start_20261113T194925642880Z/`

### 14 Nov — power-cycle mode

- [CSV](2026-11-14_power_cycle_C_5cycles.csv)
- [JSON](2026-11-14_power_cycle_C_5cycles.json)
- Local source session: `build/hardware/cold_start/cold_start_20261114T071530795020Z/`

## Uploaded file integrity (SHA-256)

| Archived file | SHA-256 of the exact user-uploaded original |
|---|---|
| `2026-11-13_btn0_reset_C_10cycles.csv` | `a08bd23fc529c447fd42e2f347ae70ae377cbfc557160ed57753c74f4f7599fe` |
| `2026-11-13_btn0_reset_C_10cycles.json` | `debd5d01dfa6202d5d5580dbb86ee8712dec459d64bbe9f6204fe361f8f702a6` |
| `2026-11-14_power_cycle_C_5cycles.csv` | `18e283bc83a2457a858ebc980dc634361e6caffe54e001206120402dc090b363` |
| `2026-11-14_power_cycle_C_5cycles.json` | `2ba3ca5d08457fa40cad83f00bdf84f3b60b90adb5e2b39b4c96f015285eed1d` |

**Integrity verification:** each archived Git blob SHA-1 was independently compared against the Git blob SHA-1 calculated from the matching uploaded byte sequence; all four were identical. No normalization, filtering or row reconstruction was applied to these original files.

## Interpretation boundaries

These are controlled, finite **Board A request-launch and reply-scoreboard** tests over the two-board physical link, reported via Board A's UART. They are **not** PHY pin-timestamped, maximum sustainable throughput tests, one-way processing latency, or an electrical instrument measuring startup interval.

**Operator follow-up (14 November):** both boards were physically unplugged overnight, then reconnected and reprogrammed before the power-cycle-mode session. This establishes an actual overnight cold restart **before the test**. It does **not** confirm that power was removed and reprogrammed afresh between each of five software cycles. The script records `mode=power-cycle` and manual `READY` confirmations, not instrumented evidence of physical power interruption, PHY recovery times or JTAG events. This data therefore documents 5 passing first and 5 passing warm bursts after at least one genuine overnight cold reprogramming, **not five independently verified electrical power cycles**.

The earlier initial Profile C 10-run trial contained **2 failed runs** before later successes; these 30 passing reset/power-cycle bursts must **not** erase that adverse observation. Those earlier failure-row files were not supplied in this evidence upload.

See [full verification scope](../../docs/VERIFICATION_AND_PERFORMANCE_V1.md), [cold-start protocol](../../docs/M4C_COLD_START_RELIABILITY.md), and [test operator guide](../../docs/TEST_OPERATIONS_GUIDE.md).
