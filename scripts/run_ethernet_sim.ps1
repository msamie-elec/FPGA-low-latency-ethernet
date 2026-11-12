# Run in normal PowerShell at project root with Icarus Verilog in PATH.
$ErrorActionPreference='Stop'
python scripts/ethernet_vectors.py
New-Item -ItemType Directory -Force build | Out-Null
iverilog -g2012 -s tb_mii_udp_rx -o build/tb_mii_udp_rx.vvp rtl/mii_udp_rx.sv tb/tb_mii_udp_rx.sv
if ($LASTEXITCODE -ne 0) {throw 'MII compile failed'}
vvp build/tb_mii_udp_rx.vvp
if ($LASTEXITCODE -ne 0) {throw 'MII simulation failed'}
iverilog -g2012 -s tb_ethernet_uart_a7 -o build/tb_ethernet_uart_a7.vvp rtl/mii_udp_rx.sv rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_tx.sv rtl/ethernet_uart_a7.sv tb/tb_ethernet_uart_a7.sv
if ($LASTEXITCODE -ne 0) {throw 'Integration compile failed'}
vvp build/tb_ethernet_uart_a7.vvp
if ($LASTEXITCODE -ne 0) {throw 'Integration simulation failed'}
