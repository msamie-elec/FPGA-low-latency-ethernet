# v0.5 RTL candidate regression; run from project root in PowerShell.
$ErrorActionPreference='Stop'
python scripts/ethernet_vectors.py
if ($LASTEXITCODE -ne 0) {throw 'RX vectors failed'}
python scripts/ethernet_tx_vectors.py
if ($LASTEXITCODE -ne 0) {throw 'TX vectors failed'}
New-Item -ItemType Directory -Force build | Out-Null
# Baseline M2A tests (must stay passing)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\run_ethernet_sim.ps1
if ($LASTEXITCODE -ne 0) {throw 'v0.4B baseline simulation failed'}
iverilog -g2012 -s tb_mii_udp_tx -o build/tb_mii_udp_tx.vvp rtl/mii_udp_tx.sv tb/tb_mii_udp_tx.sv
if ($LASTEXITCODE -ne 0) {throw 'MII TX compile failed'}
vvp build/tb_mii_udp_tx.vvp
if ($LASTEXITCODE -ne 0) {throw 'MII TX simulation failed'}
iverilog -g2012 -s tb_ethernet_udp_a7 -o build/tb_ethernet_udp_a7.vvp rtl/mii_udp_rx.sv rtl/mii_udp_tx.sv rtl/feed_parser.sv rtl/top_of_book.sv rtl/feed_pipeline.sv rtl/uart_tx.sv rtl/ethernet_udp_a7.sv tb/tb_ethernet_udp_a7.sv
if ($LASTEXITCODE -ne 0) {throw 'M2B integration compile failed'}
vvp build/tb_ethernet_udp_a7.vvp
if ($LASTEXITCODE -ne 0) {throw 'M2B integration simulation failed'}
Write-Host 'PASS v0.5 complete RTL regression'
