// SPDX-License-Identifier: MIT
// M2C Board A: receive only the legacy v0.5A broadcast UDP replies.
// PHY MII nibble order low then high; receive clock is PHY RX_CLK.
// Validates preamble, Ethernet broadcast+IPv4, source IP 192.168.77.2,
// destination IP 192.168.77.255, UDP 5000->5001, payload 1 or 14,
// zero Ethernet padding, exact 64-byte MAC frame including FCS, CRC residue.
// Does not validate IPv4/UDP checksums, nor provide general-purpose networking.
// Single-entry CDC mailbox: response and length held until ack synchronises.
module mii_reply_rx (
    input  wire         rx_clk,
    input  wire         rst_n,
    input  wire         eth_rx_dv,
    input  wire         eth_rxerr,
    input  wire [3:0]   eth_rxd,
    input  wire         ack_toggle_async,
    output logic        req_toggle,
    output logic [111:0] response,
    output logic [3:0]   response_len,
    output logic        reject_toggle
);
    function automatic [31:0] crc_byte(input [31:0] in_crc,input [7:0] data);
        reg [31:0] c;
        integer i;
        begin
            c=in_crc ^ {24'd0,data};
            for(i=0;i<8;i=i+1) c=c[0] ? ((c>>1)^32'hEDB88320) : (c>>1);
            crc_byte=c;
        end
    endfunction
    (* ASYNC_REG="TRUE" *) logic ack_meta,ack_sync;
    always_ff @(posedge rx_clk or negedge rst_n) begin
        if (!rst_n) begin ack_meta<=0; ack_sync<=0; end
        else begin ack_meta<=ack_toggle_async; ack_sync<=ack_meta; end
    end
    logic prev_dv,high_nibble,in_mac,bad_frame,rx_error;
    logic [3:0] low_nibble,preamble_count;
    logic [10:0] byte_count;
    logic [31:0] crc;
    logic [15:0] ip_len,udp_len;
    logic [111:0] staging;
    wire [7:0] this_byte={eth_rxd,low_nibble};
    wire valid_len=((ip_len==16'd29 && udp_len==16'd9) ||
                    (ip_len==16'd42 && udp_len==16'd22));
    always_ff @(posedge rx_clk or negedge rst_n) begin
        if (!rst_n) begin
            prev_dv<=0; high_nibble<=0; low_nibble<=0;
            preamble_count<=0; byte_count<=0; in_mac<=0;
            bad_frame<=0; rx_error<=0; crc<=32'hffffffff;
            ip_len<=0; udp_len<=0; staging<=0;
            req_toggle<=0; response<=0; response_len<=0; reject_toggle<=0;
        end else begin
            prev_dv<=eth_rx_dv;
            if (eth_rx_dv) begin
                if (!prev_dv) begin
                    high_nibble<=1'b1; low_nibble<=eth_rxd;
                    preamble_count<=0; byte_count<=0; in_mac<=0;
                    bad_frame<=0; rx_error<=eth_rxerr; crc<=32'hffffffff;
                    ip_len<=0; udp_len<=0; staging<=0;
                end else begin
                    if (eth_rxerr) rx_error<=1;
                    if (!high_nibble) begin
                        low_nibble<=eth_rxd; high_nibble<=1;
                    end else begin
                        high_nibble<=0;
                        if (!in_mac) begin
                            if (preamble_count<7) begin
                                if (this_byte!=8'h55) bad_frame<=1;
                                preamble_count<=preamble_count+1'b1;
                            end else begin
                                if (this_byte!=8'hd5) bad_frame<=1;
                                in_mac<=1;
                            end
                        end else begin
                            if (byte_count<11'd1522) begin
                                crc<=crc_byte(crc,this_byte);
                                byte_count<=byte_count+1'b1;
                                case (byte_count)
                                    0,1,2,3,4,5: if(this_byte!=8'hff) bad_frame<=1;
                                    6: if(this_byte!=8'h02) bad_frame<=1;
                                    7: if(this_byte!=8'h11) bad_frame<=1;
                                    8: if(this_byte!=8'h22) bad_frame<=1;
                                    9: if(this_byte!=8'h33) bad_frame<=1;
                                    10: if(this_byte!=8'h44) bad_frame<=1;
                                    11: if(this_byte!=8'h55) bad_frame<=1;
                                    12: if(this_byte!=8'h08) bad_frame<=1;
                                    13: if(this_byte!=8'h00) bad_frame<=1;
                                    14: if(this_byte!=8'h45) bad_frame<=1;
                                    15: if(this_byte!=8'h00) bad_frame<=1;
                                    16: ip_len[15:8]<=this_byte;
                                    17: ip_len[7:0]<=this_byte;
                                    20,21: if(this_byte!=8'h00) bad_frame<=1;
                                    22: if(this_byte!=8'h40) bad_frame<=1;
                                    23: if(this_byte!=8'h11) bad_frame<=1;
                                    26,30: if(this_byte!=8'hc0) bad_frame<=1;
                                    27,31: if(this_byte!=8'ha8) bad_frame<=1;
                                    28,32: if(this_byte!=8'h4d) bad_frame<=1;
                                    29: if(this_byte!=8'h02) bad_frame<=1;
                                    33: if(this_byte!=8'hff) bad_frame<=1;
                                    34,36: if(this_byte!=8'h13) bad_frame<=1;
                                    35: if(this_byte!=8'h88) bad_frame<=1;
                                    37: if(this_byte!=8'h89) bad_frame<=1;
                                    38: udp_len[15:8]<=this_byte;
                                    39: udp_len[7:0]<=this_byte;
                                    40,41: if(this_byte!=8'h00) bad_frame<=1;
                                    default: ;
                                endcase
                                // B's packet is always Ethernet-minimum 60 MAC bytes
                                // before FCS; any bytes beyond the UDP payload are padding.
                                if (byte_count>=42 && byte_count<56)
                                    staging[111-8*(byte_count-42) -: 8]<=this_byte;
                                if (byte_count>=42 && byte_count<60 &&
                                    (byte_count>=42+udp_len-16'd8) && this_byte!=0)
                                    bad_frame<=1;
                            end else bad_frame<=1;
                        end
                    end
                end
            end else if (prev_dv) begin
                if (in_mac && !high_nibble && byte_count==11'd64 &&
                    !bad_frame && !rx_error && valid_len &&
                    crc==32'hdebb20e3 && req_toggle==ack_sync) begin
                    response<=staging;
                    response_len<=(udp_len==16'd9) ? 4'd1 : 4'd14;
                    req_toggle<=~req_toggle;
                end else reject_toggle<=~reject_toggle;
            end
        end
    end
endmodule
