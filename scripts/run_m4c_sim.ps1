# Only works with Icarus Verilog installed in Windows PATH.
$ErrorActionPreference='Stop'
New-Item -ItemType Directory -Force build | Out-Null
$rtl=@('rtl/m4b_async_fifo.sv','rtl/m4b_sync_fifo.sv',
       'rtl/mii_udp_rx_m4b.sv','rtl/mii_udp_tx_m4b.sv',
       'rtl/feed_parser.sv','rtl/top_of_book.sv','rtl/feed_pipeline.sv',
       'rtl/uart_rx.sv','rtl/uart_tx.sv','rtl/mii_feed_tx.sv',
       'rtl/mii_reply_rx.sv','rtl/ethernet_generator_a7_m4c.sv',
       'rtl/ethernet_udp_a7_buffered.sv')
& iverilog -g2012 -s tb_m4c_board_pair -o build/tb_m4c_board_pair.vvp @($rtl+@('tb/tb_m4c_board_pair.sv'))
if($LASTEXITCODE -ne 0){throw 'M4C compile failed'}
& vvp build/tb_m4c_board_pair.vvp
if($LASTEXITCODE -ne 0){throw 'M4C RTL simulation failed'}
Write-Host 'PASS M4C FPGA-native A/B burst RTL regression'
