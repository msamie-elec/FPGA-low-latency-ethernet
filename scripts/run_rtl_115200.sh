#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Longer physical-rate board-path simulation (100MHz clock, 115200 baud).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build
iverilog -g2012 -DREAL_UART_BAUD -s tb_board_uart -o build/tb_board_uart_115200.vvp \
  rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv \
  rtl/uart_rx.sv rtl/uart_tx.sv rtl/board_uart_demo.sv tb/tb_board_uart.sv
vvp build/tb_board_uart_115200.vvp
