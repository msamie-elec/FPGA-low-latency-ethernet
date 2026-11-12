# M2C full simulation. Run from the M2C project root in PowerShell.
$ErrorActionPreference = 'Stop'
python scripts/m2c_vectors.py
if ($LASTEXITCODE -ne 0) { throw 'M2C vector generation failed' }
New-Item -ItemType Directory -Force build | Out-Null
# New transmitter and receiver unit tests.
iverilog -g2012 -s tb_mii_feed_tx -o build/tb_mii_feed_tx.vvp rtl/mii_feed_tx.sv tb/tb_mii_feed_tx.sv
if ($LASTEXITCODE -ne 0) { throw 'Feed transmitter compile failed' }
vvp build/tb_mii_feed_tx.vvp
if ($LASTEXITCODE -ne 0) { throw 'Feed transmitter simulation failed' }
iverilog -g2012 -s tb_mii_reply_rx -o build/tb_mii_reply_rx.vvp rtl/mii_reply_rx.sv tb/tb_mii_reply_rx.sv
if ($LASTEXITCODE -ne 0) { throw 'Reply receiver compile failed' }
vvp build/tb_mii_reply_rx.vvp
if ($LASTEXITCODE -ne 0) { throw 'Reply receiver simulation failed' }
# New endpoint Ethernet-first integration test using independent reference vectors.
python scripts/ethernet_tx_vectors.py
if ($LASTEXITCODE -ne 0) { throw 'M3 endpoint vector generation failed' }
$common = @('rtl/uart_rx.sv','rtl/uart_tx.sv','rtl/feed_parser.sv',
  'rtl/top_of_book.sv','rtl/feed_pipeline.sv','rtl/mii_feed_tx.sv',
  'rtl/mii_reply_rx.sv','rtl/mii_udp_rx.sv','rtl/mii_udp_tx.sv',
  'rtl/ethernet_generator_a7_m2c.sv','rtl/ethernet_udp_a7_lowlat.sv')
iverilog -g2012 -s tb_ethernet_udp_a7_lowlat -o build/tb_m3_endpoint.vvp $common tb/tb_ethernet_udp_a7_lowlat.sv
if ($LASTEXITCODE -ne 0) { throw 'M3 endpoint RTL compile failed' }
vvp build/tb_m3_endpoint.vvp
if ($LASTEXITCODE -ne 0) { throw 'M3 endpoint RTL simulation failed' }
iverilog -g2012 -s tb_m3_board_pair -o build/tb_m3_board_pair.vvp $common tb/tb_m3_board_pair.sv
if ($LASTEXITCODE -ne 0) { throw 'M3 two-board RTL compile failed' }
vvp build/tb_m3_board_pair.vvp
if ($LASTEXITCODE -ne 0) { throw 'M3 two-board RTL simulation failed' }
Write-Host 'PASS M3 v0.7 Ethernet-first RTL regression'
