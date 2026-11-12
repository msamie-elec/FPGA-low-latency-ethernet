# SPDX-License-Identifier: MIT
# Source from Vivado GUI Tcl Console in an OPEN EthAB project:
#   cd <repository-root>
#   source vivado/board_config.tcl
#   fpga_select_board A
#   fpga_archive_current
#   fpga_select_board B

proc fpga_board_data {target} {
    switch -nocase -- $target {
        A - board_a {return [list A ethernet_generator_a7_m4c constrs_board_a]}
        B - board_b {return [list B ethernet_udp_a7_buffered constrs_board_b]}
        default {error "Invalid board '$target'; choose A or B"}
    }
}
proc fpga_root_dir {} {
    # GUI project is under <repo>/build/v/EthAB
    set project_path [file normalize [get_property DIRECTORY [current_project]]]
    return [file normalize [file join $project_path .. .. ..]]
}
proc fpga_archive_current {} {
    set top [get_property TOP [get_filesets sources_1]]
    if {$top eq "ethernet_generator_a7_m4c"} {
        set board A
    } elseif {$top eq "ethernet_udp_a7_buffered"} {
        set board B
    } else {
        error "Unrecognised synthesis top: $top"
    }
    set status [get_property STATUS [get_runs impl_1]]
    if {![string match *Complete* $status]} {
        error "Cannot archive board $board: implementation is not complete ($status)"
    }
    set project_path [file normalize [get_property DIRECTORY [current_project]]]
    set project_name [get_property NAME [current_project]]
    set impl_dir [file join $project_path $project_name.runs impl_1]
    set source_bit [file join $impl_dir $top.bit]
    if {![file isfile $source_bit]} {
        error "Bitstream not found: $source_bit; run Generate Bitstream first"
    }
    set archive [file join [fpga_root_dir] build out $board]
    file mkdir $archive
    set dest [file join $archive board_$board.bit]
    file copy -force $source_bit $dest
    foreach path [glob -nocomplain -directory $impl_dir *.rpt] {
        file copy -force $path [file join $archive [file tail $path]]
    }
    set manifest [open [file join $archive build_identity.txt] w]
    puts $manifest "Board: $board"
    puts $manifest "Top: $top"
    puts $manifest "Part: [get_property PART [current_project]]"
    puts $manifest "Constraints: [get_property CONSTRSET [get_runs impl_1]]"
    puts $manifest "Vivado version: [version -short]"
    puts $manifest "Run status: $status"
    close $manifest
    puts "ARCHIVED board $board bitstream and available routed reports: $archive"
    return $dest
}
proc fpga_select_board {target} {
    lassign [fpga_board_data $target] board top constrset
    set current_top [get_property TOP [get_filesets sources_1]]
    set current_constr [get_property CONSTRSET [get_runs synth_1]]
    set impl_constr [get_property CONSTRSET [get_runs impl_1]]
    if {$current_top ne $top || $current_constr ne $constrset || $impl_constr ne $constrset} {
        # Switching top invalidates synthesis/implementation. Preserve finished
        # outputs before reset; never treat an incomplete bitstream as valid.
        set project_path [get_property DIRECTORY [current_project]]
        set project_name [get_property NAME [current_project]]
        set previous_bit [file join $project_path $project_name.runs impl_1 $current_top.bit]
        if {[file isfile $previous_bit]} {
            if {[string match *Complete* [get_property STATUS [get_runs impl_1]]]} {
                fpga_archive_current
            } else {
                puts "WARNING: Ignoring stale/incomplete bitstream for $current_top"
            }
        }
        reset_run impl_1
        reset_run synth_1
    }
    set_property TOP $top [get_filesets sources_1]
    set_property CONSTRSET $constrset [get_runs synth_1]
    set_property CONSTRSET $constrset [get_runs impl_1]
    update_compile_order -fileset sources_1
    save_project
    puts "ACTIVE: Board $board | synthesis top=$top | constraints=$constrset"
    puts "Simulation top remains tb_m4c_board_pair (both FPGAs)."
    return $board
}
