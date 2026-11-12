# M3 v0.7 engineering release gate — 2026-11-11

- **v0.6 physical 200/200 PASS** recorded from user CSV; archived in `docs/baselines/`.
- **v0.5A physical 200/200 PASS** inherited baseline; unmodified old Board B RTL in this ZIP.
- **v0.7 new Board B** parallel Ethernet TX and UART FSM; NOT physically tested.
- Python and model static tests are locally runnable; run Icarus and Vivado on Windows.
- Not suitable for programming until new Vivado timing/CDC release gate passes.
- If it fails, restore the T: v0.5A Board B bitstream. Board A on U: is unchanged.
