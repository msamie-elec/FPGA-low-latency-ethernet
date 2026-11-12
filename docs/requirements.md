# Verifiable requirements (release candidate)

| ID | Requirement | Evidence plan |
|---|---|---|
| R01 | Accept one byte per valid/ready handshake | tb_feed_pipeline |
| R02 | Decode 16-byte big-endian fixed record | tb_feed_pipeline, reference comparison |
| R03 | Reject incorrect side, reserved field, short/long length | tb_feed_pipeline, Python tests |
| R04 | Maintain bid/ask state for symbol 1 only | tb_feed_pipeline, Python/C++ |
| R05 | Ignore zero-quantity and other-symbol records | tb_feed_pipeline, tb_board_uart |
| R06 | Generate signal only when 0 < ask - bid <= 5 | tb_feed_pipeline, model |
| R07 | Preserve output under report backpressure | tb_feed_pipeline |
| R08 | USB-UART 16-byte request and response on Artix/Spartan variants | tb_board_uart, physical host test |
| R09 | FPGA device synthesizes and meets specified board clock | Vivado implementation reports **pending** |
| R10 | Board processing matches independent software oracle | uart_board_test.py **pending physical test** |
| R11 | Ethernet/MII ingestion between Arty A7 boards | **not implemented** |

R01-R08 are assertions/bench targets; successful local HDL simulation has not
been recorded in this release environment. Do not confuse *test written* with
*test passed*.
