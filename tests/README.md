# Tests directory — executable verification definitions

This directory holds **test code**, not measured hardware output files.

| File or area | Checks | Scope |
|---|---|---|
| `test_reference.py` | Synthetic feed reference-model correctness, malformed inputs, Python/C++ oracle comparison | Host software; no physical FPGA |
| `test_m4b_buffered.py` | Board B source/file structure, packet stimulus vectors, bounded queues, reply-vs-diagnostics handshake | Software/source assertions, not full RTL simulation |
| `test_m4c_benchmark.py` | Board A UART binary telemetry parser, malformed reports, benchmark constants and frozen RTL/XDC hashes | Host protocol/source integrity |
| `test_vivado_one_project.py` | One-XPR project generator source configuration, separate A/B tops and XDCs, Tcl project mock | Packaging/Tcl mock; not a routed hardware implementation |
| `test_wave_demo.py` | Simulation waveform setup script and probes, Tcl mock rendering commands | Waveform source structure; not a substitute for Vivado GUI simulation |
| `vivado_project_mock.tcl` | Tcl mock helper used by automated project tests | Test helper |
| `generated/` | Generated vectors when running regressions | **Ignored**, disposable |

The **HDL simulation testbenches** are in `../tb/`. Simulation-specific waveform configuration and the canonical waveform generator script live in [`../sim/`](../sim/README.md), not in this test-code folder. Test *runner scripts*, including `../scripts/m4c_hardware_benchmark.py` and `../scripts/m4c_cold_start.py`, are in `../scripts/` because they are invoked directly by the operator and interact with hardware. The physical **test results** (CSV/JSON) are generated locally in **`../build/hardware/`** under Git-ignored `build/`. Selected reviewed original records are preserved **once** under **`../evidence/hardware/`** for GitHub readers.

This avoids mixing repeatable source tests with transient local measurements or committing multiple copies of auto-generated Vivado or waveform files.

Run the Python checks from the repo root:

```powershell
python -m pytest -q tests
```

This does **not** program the FPGA or run physical hardware benchmarks. For those, follow [the physical test runbook](../docs/TEST_OPERATIONS_GUIDE.md).
