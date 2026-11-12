#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
set -euo pipefail
cd "$(dirname "$0")/.."
if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
  echo 'ERROR: Icarus Verilog (iverilog and vvp) are required for actual RTL simulation.' >&2
  exit 2
fi
mkdir -p build
core=(rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv)
iverilog -g2012 -s tb_feed_pipeline -o build/tb_feed_pipeline.vvp "${core[@]}" tb/tb_feed_pipeline.sv
vvp build/tb_feed_pipeline.vvp
iverilog -g2012 -s tb_board_uart -o build/tb_board_uart.vvp "${core[@]}" rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart.vvp
