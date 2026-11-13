# SPDX-License-Identifier: MIT
# Mock Vivado Tcl commands for a fast CI packaging test. NO REAL FPGA/VIVADO.
if {$argc != 1} {error "Usage: tclsh tests/vivado_project_mock.tcl REPO"}
set root [file normalize [lindex $argv 0]]
array set props {}
set pname ""
set pdir ""
set sources {}
set constraints_a {}
set constraints_b {}
set sim_files {}
set resets 0
proc current_project {} {return PROJECT}
proc get_filesets {name} {return $name}
proc get_runs {name} {return $name}
proc get_property {key obj} {
    global props pname pdir
    set key [string toupper $key]
    if {$obj eq "PROJECT" && $key eq "DIRECTORY"} {return $pdir}
    if {$obj eq "PROJECT" && $key eq "NAME"} {return $pname}
    if {$obj eq "PROJECT" && $key eq "PART"} {return xc7a35ticsg324-1L}
    if {[info exists props($obj,$key)]} {return $props($obj,$key)}
    if {$key eq "CONSTRSET"} {return constrs_1}
    if {$key eq "STATUS"} {return "Not started"}
    return ""
}
proc set_property {key value obj} {
    global props
    set props($obj,[string toupper $key]) $value
}
proc create_project {args} {
    global pname pdir
    set pname [lindex $args 1]
    set pdir [file normalize [lindex $args 2]]
    file mkdir $pdir
    set f [open [file join $pdir $pname.xpr] w]
    puts $f "MOCK XPR -- NOT USABLE IN VIVADO"
    close $f
}
proc create_fileset {args} {return [lindex $args end]}
proc add_files {args} {
    global sources constraints_a constraints_b sim_files
    set i [lsearch -exact $args -fileset]
    if {$i < 0} {error "Missing fileset"}
    set fs [lindex $args [expr {$i + 1}]]
    set path [lindex $args end]
    if {![file isfile $path]} {error "Missing file: $path"}
    switch -- $fs {
        sources_1 {lappend sources $path}
        constrs_board_a {lappend constraints_a $path}
        constrs_board_b {lappend constraints_b $path}
        sim_1 {lappend sim_files $path}
        default {error "Unexpected fileset: $fs"}
    }
}
proc get_files {args} {
    global constraints_a constraints_b sources sim_files props
    set idx [lsearch -exact $args -of_objects]
    if {$idx < 0} {error "Test must use get_files -of_objects"}
    set fs [lindex $args [expr {$idx + 1}]]
    switch -- $fs {
        constrs_board_a {set candidates $constraints_a}
        constrs_board_b {set candidates $constraints_b}
        sources_1 {set candidates $sources}
        sim_1 {set candidates $sim_files}
        default {error "Unknown fileset: $fs"}
    }
    set used_idx [lsearch -exact $args -used_in]
    if {$used_idx >= 0} {
        set phase [string toupper [lindex $args [expr {$used_idx + 1}]]]
        set filtered {}
        foreach file $candidates {
            if {![info exists props($file,USED_IN_$phase)] || $props($file,USED_IN_$phase)} {
                lappend filtered $file
            }
        }
        return $filtered
    }
    return $candidates
}
proc update_compile_order {args} {}
proc close_project {} {}
proc open_project {path} {
    if {![file isfile $path]} {error "XPR missing: $path"}
}
proc reset_run {name} {
    global props resets
    incr resets
    set props($name,STATUS) "Not started"
}
proc launch_runs {name args} {
    global props pname pdir
    if {$name eq "impl_1"} {
        set top [get_property TOP sources_1]
        set out [file join $pdir $pname.runs impl_1]
        file mkdir $out
        set f [open [file join $out $top.bit] w]
        puts $f "MOCK BITSTREAM -- DO NOT PROGRAM"
        close $f
        set f [open [file join $out timing_summary.rpt] w]
        puts $f "MOCK REPORT -- NOT VIVADO"
        close $f
    }
    set props($name,STATUS) "write_bitstream Complete!"
}
proc wait_on_run {args} {}
proc open_run {name} {}
proc close_design {} {}
proc get_ports {args} {
    # Simulate get_ports -quiet <port>; fail if the requested name is unknown.
    set wanted [lindex $args end]
    set valid {eth_rx_dv eth_rxerr {eth_rxd[0]} {eth_rxd[1]} {eth_rxd[2]} {eth_rxd[3]} eth_tx_en {eth_txd[0]} {eth_txd[1]} {eth_txd[2]} {eth_txd[3]}}
    if {[lsearch -exact $valid $wanted] < 0} {return {}}
    return [list $wanted]
}
proc version {args} {return "MOCK NOT VIVADO"}
proc assert_eq {a b note} {
    if {$a ne $b} {error "$note: got='$a' expected='$b'"}
}
set argv {}
set argc 0
source [file join $root vivado create_project.tcl]
# Verify generated XDC copies differ from their frozen originals ONLY in
# removing the two invalid conditional statements, without any timing edits.
foreach {source_name target_name} {
    ethernet_m4c_generator.xdc A.xdc
    ethernet_m4b_endpoint.xdc B.xdc
} {
    set original_path [file join $root boards arty_a7 $source_name]
    set generated_path [file join $root build v xdc $target_name]
    if {![file isfile $generated_path]} {error "Missing generated XDC: $generated_path"}
    set fh [open $original_path r]; set original [read $fh]; close $fh
    set fh [open $generated_path r]; set generated [read $fh]; close $fh
    set rx_guard {if {[llength $mii_rx_ports] != 6} {error "Expected exactly six MII receive ports"}}
    set tx_guard {if {[llength $mii_tx_ports] != 5} {error "Expected five MII transmit ports"}}
    set expected {}
    set removed 0
    foreach line [split $original "\n"] {
        if {$line eq $rx_guard || $line eq $tx_guard} {incr removed; continue}
        lappend expected $line
    }
    set expected_gui "[join $expected "\n"]\n# Arty A7 configuration bank 0 (Digilent schematic)\nset_property CFGBVS VCCO \[current_design\]\nset_property CONFIG_VOLTAGE 3.3 \[current_design\]\n"
    if {$removed != 2 || $expected_gui ne $generated} {
        error "GUI XDC differs from frozen XDC beyond two omitted guards and approved configuration-voltage properties: $source_name"
    }
}
set marker [file join $root build v project_ok.txt]
if {![file isfile $marker]} {error "Generator did not create success marker after XPR reopen verification"}
assert_eq [get_property TOP sources_1] ethernet_generator_a7_m4c "Board A initial top"
assert_eq [get_property CONSTRSET synth_1] constrs_board_a "Board A synthesis XDC"
assert_eq [get_property CONSTRSET impl_1] constrs_board_a "Board A implementation XDC"
assert_eq [get_property TOP sim_1] tb_m4c_board_pair "Combined simulation top"
if {[llength $sources] != 13} {error "Must have 13 final RTL sources"}
if {[llength $constraints_a] != 1 || [llength $constraints_b] != 1} {
    error "Expected one XDC per board"
}
if {[llength $sim_files] != 1} {error "Expected combined simulation testbench"}
source [file join $root vivado board_config.tcl]
# Simulate the real failure: the named Board B fileset exists, but its
# XDC association vanishes. Selector must repair it before run reset/build.
set constraints_b {}
fpga_select_board B
if {[llength $constraints_b] != 1} {error "Board B missing XDC was not repaired"}
assert_eq [get_property TOP sources_1] ethernet_udp_a7_buffered "Board B top"
assert_eq [get_property CONSTRSET synth_1] constrs_board_b "Board B synthesis XDC"
assert_eq [get_property CONSTRSET impl_1] constrs_board_b "Board B implementation XDC"
fpga_select_board A
if {$resets < 4} {error "Target switching did not reset both runs"}
set argv {both}
set argc 1
source [file join $root vivado build_targets.tcl]
foreach board {A B} {
    set path [file join $root build out $board board_$board.bit]
    if {![file isfile $path]} {error "Missing archived board $board result"}
    set manifest [file join $root build out $board build_identity.txt]
    if {![file isfile $manifest]} {error "Missing archive manifest for $board"}
}
puts "PASS: TCL MOCK ONLY — one XPR, safe board configuration, dual output archive"
