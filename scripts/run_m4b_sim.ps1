# M4B development regression. New endpoint is NOT approved by this script alone.
$ErrorActionPreference = 'Stop'
python scripts/m4b_vectors.py
if ($LASTEXITCODE -ne 0) { throw 'M4B vectors failed' }
New-Item -ItemType Directory -Force build | Out-Null
$rtl = @('rtl/m4b_async_fifo.sv','rtl/m4b_sync_fifo.sv',
         'rtl/mii_udp_rx_m4b.sv','rtl/mii_udp_tx_m4b.sv',
         'rtl/feed_parser.sv','rtl/top_of_book.sv','rtl/feed_pipeline.sv',
         'rtl/uart_tx.sv','rtl/ethernet_udp_a7_buffered.sv')
$tests = @(
    @{ top='tb_m4b_sync_fifo'; files=@('rtl/m4b_sync_fifo.sv','tb/tb_m4b_sync_fifo.sv') },
    @{ top='tb_m4b_async_fifo'; files=@('rtl/m4b_async_fifo.sv','tb/tb_m4b_async_fifo.sv') },
    @{ top='tb_m4b_rx_overflow'; files=@('rtl/mii_udp_rx_m4b.sv','rtl/m4b_async_fifo.sv','tb/tb_m4b_rx_overflow.sv') },
    @{ top='tb_m4b_endpoint_burst'; files=$rtl + @('rtl/mii_reply_rx.sv','tb/tb_m4b_endpoint_burst.sv') },
    @{ top='tb_m4b_board_pair'; files=$rtl + @('rtl/uart_rx.sv','rtl/mii_reply_rx.sv',
        'rtl/mii_feed_tx.sv','rtl/ethernet_generator_a7_m2c.sv','tb/tb_m4b_board_pair.sv') }
)
foreach ($item in $tests) {
    $name = $item.top
    $output = "build/$name.vvp"
    & iverilog -g2012 -s $name -o $output @($item.files)
    if ($LASTEXITCODE -ne 0) { throw "$name compilation failed" }
    & vvp $output
    if ($LASTEXITCODE -ne 0) { throw "$name RTL simulation failed" }
}
Write-Host 'PASS M4B buffered endpoint RTL regression — queues, counted RX FIFO overflow, 22-frame Ethernet burst, 2-board compatibility'
