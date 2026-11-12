// SPDX-License-Identifier: MIT
// MII 4-bit receive adapter, 100 Mb/s (25 MHz RX_CLK), low nibble first.
// Deliberately narrow V0.4A: broadcast destination MAC, IPv4 IHL=5,
// UDP destination port 5000, exactly 16 payload bytes, valid Ethernet FCS.
// This is a receive-only experiment: no ARP, ICMP, DHCP or Ethernet TX yet.
// One-entry four-phase data mailbox. payload remains stable until ack toggles.
module mii_udp_rx (
    input  wire         rx_clk,
    input  wire         rst_n,
    input  wire         eth_rx_dv,
    input  wire         eth_rxerr,
    input  wire [3:0]   eth_rxd,
    input  wire         ack_toggle_async,
    output logic        req_toggle,
    output logic [127:0] payload,
    output logic        good_toggle,
    output logic        reject_toggle
);
    function automatic [31:0] crc_byte(input [31:0] current, input [7:0] data);
        reg [31:0] x;
        integer bitn;
        begin
            x = current ^ {24'd0, data};
            for (bitn=0;bitn<8;bitn=bitn+1)
                x = x[0] ? ((x >> 1) ^ 32'hEDB88320) : (x >> 1);
            crc_byte = x;
        end
    endfunction

    (* ASYNC_REG="TRUE" *) logic ack_meta, ack_sync;
    always_ff @(posedge rx_clk or negedge rst_n) begin
        if (!rst_n) begin ack_meta <= 0; ack_sync <= 0; end
        else begin ack_meta <= ack_toggle_async; ack_sync <= ack_meta; end
    end

    logic prev_dv, high_nibble;
    logic [3:0] low_nibble;
    wire [7:0] this_byte = {eth_rxd,low_nibble};
    logic [3:0] preamble_count;
    logic [10:0] mac_byte_count;
    logic [31:0] crc;
    logic bad_frame, in_mac;
    logic [127:0] staging;
    logic saw_rx_error;

    always_ff @(posedge rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_dv <= 0; high_nibble <= 0; low_nibble <= 0;
            preamble_count <= 0; mac_byte_count <= 0;
            crc <= 32'hFFFFFFFF; bad_frame <= 0; in_mac <= 0;
            staging <= 0; payload <= 0;
            req_toggle <= 0; good_toggle <= 0; reject_toggle <= 0;
            saw_rx_error <= 0;
        end else begin
            prev_dv <= eth_rx_dv;
            if (eth_rx_dv) begin
                if (!prev_dv) begin
                    // First nibble of the preamble (first cycle of RX_DV).
                    high_nibble <= 1'b1;
                    low_nibble <= eth_rxd;
                    preamble_count <= 0;
                    mac_byte_count <= 0;
                    in_mac <= 0;
                    bad_frame <= 0;
                    saw_rx_error <= eth_rxerr;
                    crc <= 32'hFFFFFFFF;
                    staging <= 0;
                end else begin
                    if (eth_rxerr) saw_rx_error <= 1'b1;
                    if (!high_nibble) begin
                        low_nibble <= eth_rxd;
                        high_nibble <= 1'b1;
                    end else begin
                        high_nibble <= 1'b0;
                        if (!in_mac) begin
                            if (preamble_count < 7) begin
                                if (this_byte != 8'h55) bad_frame <= 1'b1;
                                preamble_count <= preamble_count + 1'b1;
                            end else begin
                                if (this_byte != 8'hD5) bad_frame <= 1'b1;
                                in_mac <= 1'b1;
                            end
                        end else begin
                            if (mac_byte_count < 11'd1522) begin
                                crc <= crc_byte(crc,this_byte);
                                mac_byte_count <= mac_byte_count + 1'b1;
                                case (mac_byte_count)
                                     0,1,2,3,4,5: if (this_byte != 8'hff) bad_frame <= 1'b1;
                                    12: if (this_byte != 8'h08) bad_frame <= 1'b1;
                                    13: if (this_byte != 8'h00) bad_frame <= 1'b1;
                                    14: if (this_byte != 8'h45) bad_frame <= 1'b1;
                                    16: if (this_byte != 8'h00) bad_frame <= 1'b1;
                                    17: if (this_byte != 8'h2c) bad_frame <= 1'b1;
                                    23: if (this_byte != 8'h11) bad_frame <= 1'b1;
                                    36: if (this_byte != 8'h13) bad_frame <= 1'b1;
                                    37: if (this_byte != 8'h88) bad_frame <= 1'b1;
                                    38: if (this_byte != 8'h00) bad_frame <= 1'b1;
                                    39: if (this_byte != 8'h18) bad_frame <= 1'b1;
                                    default: ;
                                endcase
                                if (mac_byte_count >= 42 && mac_byte_count < 58)
                                    staging[127-8*(mac_byte_count-42) -: 8] <= this_byte;
                            end else bad_frame <= 1'b1;
                        end
                    end
                end
            end else if (prev_dv) begin
                // FCS is included in the CRC computation; standard residue is fixed.
                if (in_mac && !high_nibble && mac_byte_count >= 64 &&
                    !bad_frame && !saw_rx_error && crc == 32'hDEBB20E3 &&
                    req_toggle == ack_sync) begin
                    payload <= staging;
                    req_toggle <= ~req_toggle;
                    good_toggle <= ~good_toggle;
                end else begin
                    reject_toggle <= ~reject_toggle;
                end
            end
        end
    end
endmodule
