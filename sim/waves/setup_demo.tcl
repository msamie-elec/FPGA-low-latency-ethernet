# SPDX-License-Identifier: MIT
# Vivado 2025.2.1 XSim GUI: source sim/waves/setup_demo.tcl
# Use after launching behavioral simulation with tb_m4c_board_pair as top.
# A read-only waveform setup: no FPGA RTL, clocks or testbench drivers modified.
#
# To populate a fresh trace after adding these signals:
#     restart
#     run all
# Save an annotated *real* Vivado screenshot separately for docs/images/.
set wave_script_dir [file dirname [file normalize [info script]]]
set wave_out [file join $wave_script_dir dual_board_demo.wcfg]
set tb_scope /tb_m4c_board_pair

# Dedicated, repeatable view, leaving the existing Untitled view intact.
set cfg [create_wave_config {Dual FPGA Ethernet packet journey}]
current_wave_config $cfg

# Add a readable hierarchy without bulk-adding all internal design nets.
# Every item is fully qualified to avoid accidental selection from wrong scope.
proc fpga_demo_group {label names} {
    global tb_scope
    set group [add_wave_group $label]
    foreach name $names {
        set path "${tb_scope}/${name}"
        set matches [get_objects -quiet $path]
        if {[llength $matches] == 0} {
            error "Missing demo signal: $path. Use the updated tb_m4c_board_pair.sv and relaunch simulation."
        }
        add_wave -into $group $path
    }
}
fpga_demo_group {01 - Test control and result} {
    miiclk btn arstn brstn active_profile profile_pass profiles_passed all_profiles_pass
}
fpga_demo_group {02 - A to B request (MII and decoded bytes)} {
    atxen atxd a2b_frames a2b_byte_valid a2b_byte a2b_payload_valid a2b_payload_byte
}
fpga_demo_group {03 - B validates and processes request} {
    b_rx_frame_valid b_reply_enqueued
}
fpga_demo_group {04 - B to A reply (MII and decoded bytes)} {
    btxen btxd b2a_frames b2a_byte_valid b2a_byte b2a_payload_valid b2a_payload_byte
}
fpga_demo_group {05 - A receives response and verifies} {
    a_reply_staged a_unique_replies tx_frame_count count tel_err
}

save_wave_config $wave_out
puts "DEMO WAVE READY: $wave_out"
puts "Next: restart; run all. Zoom into ONE packet+reply exchange."
puts "Wave config contains signal layout only, not simulator trace or hardware proof."
