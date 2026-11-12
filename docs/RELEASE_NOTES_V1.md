# v1.0 - Final portfolio release (11 November 2026)

## Scope freeze

**Technical development closed after M4C.** Board A uses v0.9 hardware-native benchmark generator; Board B uses verified v0.8B FIFO endpoint. The v1.0 identifier refers to the *portfolio packaging and documentation*, not a new synthesis RTL version or newly designed FPGA bitstream.

## Measured acceptance

- M4C 9/9 physical FPGA-to-FPGA 1,000-packet trials passed; 9,000/9,000 replies correctly matched (three trials each at 10k/50k/100k packet requests/s).
- Additional M4C profile A smoke trial 1,000/1,000 replies.
- Hardware-reported request-launch gaps equal the programmed 100/20/10 us periods in all final trials, with zero late launches.
- M4C generator and M4B buffered endpoint both had positive constrained setup/hold slack in the supplied Vivado 2025.2.1 reports.
- Sequential hardware round-trip latency: v0.7 median 12.75 us; v0.8B median 12.85 us. Both are *hardware RTT*, not core processing latency.

## Exclusions

The rate measurement is finite-burst FPGA request launch timing with matching replies, not measured line rate or indefinitely sustainable throughput. No full PHY timing signoff, CDC formal proof or exchange-protocol claims. No new Ethernet features after this release.

## Publication tasks requiring manual action

1. Review repository metadata, MIT license rights and third-party constraint provenance.
2. Add an original photo of the actual two-board physical setup and a screenshot of Vivado timing/results (crop computer names and serials as appropriate).
3. Create a new GitHub repository, upload the source, and tag **v1.0**; optionally attach the engineering-report PDF.
4. Add GitHub project link and a short demo video to Upwork/LinkedIn portfolio entries.
5. Archive the exact verified bitstreams locally, separately from the public source tree, with tool-version and build hashes.

No GitHub publication, profile update or remote account action is implied by this offline ZIP.
