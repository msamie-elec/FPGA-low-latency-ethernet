# SPDX-License-Identifier: MIT
# Run in Vivado only AFTER opening a synthesized or implemented design.
# Standalone Tcl scripts support conditionals; an XDC does not.
proc verify_mii_ports {} {
    set expected_rx {eth_rx_dv eth_rxerr {eth_rxd[0]} {eth_rxd[1]} {eth_rxd[2]} {eth_rxd[3]}}
    set expected_tx {eth_tx_en {eth_txd[0]} {eth_txd[1]} {eth_txd[2]} {eth_txd[3]}}
    set missing {}
    foreach port [concat $expected_rx $expected_tx] {
        set matched [get_ports -quiet $port]
        if {[llength $matched] != 1} { lappend missing $port }
    }
    if {[llength $missing] > 0} {
        error "MII port validation failed: missing/nonunique ports: $missing"
    }
    puts "PASS: MII port validation found 6 RX and 5 TX ports."
}
verify_mii_ports
