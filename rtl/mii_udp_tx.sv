// SPDX-License-Identifier: MIT
// v0.5 engineering candidate: 100-Mbps MII UDP response transmitter.
// Destination broadcast MAC/IP, source MAC 02:11:22:33:44:55,
// source IP 192.168.77.2, destination 192.168.77.255,
// UDP source/destination 5000/5001. Response payload is 1 or 14 bytes.
// The transmitter emits the Ethernet preamble, SFD, IPv4 header,
// UDP header, zero padding (to 60 MAC bytes), Ethernet CRC32 (FCS),
// and >=96 bit times of inter-frame gap.
// Frames are sent using the PHY's MII TX_CLK. The output registers change
// on TX_CLK falling edges so the PHY can sample on the rising edge.
//
// 100-MHz producer / 25-MHz transmitter toggle mailbox:
// response_data and response_len MUST be held unchanged from request toggle
// until ack_toggle returns to the new request value. This is intentionally
// single-entry and non-burst. No ARP or incoming UDP checksum validation.
module mii_udp_tx (
    input  wire         tx_clk,
    input  wire         rst_n,
    input  wire         req_toggle_async,
    input  wire [111:0] response_data,
    input  wire [3:0]   response_len,
    output logic        ack_toggle,
    output logic        eth_tx_en,
    output logic [3:0]  eth_txd
);
    function automatic [31:0] crc_byte(input [31:0] prev_crc, input [7:0] data);
        reg [31:0] crc;
        integer bit_idx;
        begin
            crc = prev_crc ^ {24'b0,data};
            for (bit_idx=0;bit_idx<8;bit_idx=bit_idx+1)
                crc = crc[0] ? ((crc >> 1) ^ 32'hEDB88320) : (crc >> 1);
            crc_byte = crc;
        end
    endfunction

    function automatic [15:0] ipv4_checksum(input [15:0] total_length);
        reg [31:0] s;
        begin
            // 45 00 len, ID 0042, flags/frag 0000, TTL 40, proto 11,
            // source C0A8:4D02, destination C0A8:4DFF.
            s = 32'h00004500 + {16'b0,total_length} + 32'h00000042 +
                32'h00004011 + 32'h0000C0A8 + 32'h00004D02 +
                32'h0000C0A8 + 32'h00004DFF;
            s = {16'b0,s[15:0]} + {16'b0,s[31:16]};
            s = {16'b0,s[15:0]} + {16'b0,s[31:16]};
            ipv4_checksum = ~s[15:0];
        end
    endfunction

    (* ASYNC_REG="TRUE" *) logic req_meta, req_sync;
    logic [111:0] held_data;
    logic [3:0] held_len;
    logic [6:0] byte_index;
    logic high_nibble;
    logic [31:0] crc;
    logic [4:0] gap_count;
    logic [1:0] state;
    localparam [1:0] IDLE=0, STREAM=1, GAP=2, VALIDATE=3;
    wire [15:0] ip_len = 16'd28 + {12'b0,held_len};
    wire [15:0] udp_len = 16'd8 + {12'b0,held_len};
    wire [15:0] ip_csum = ipv4_checksum(ip_len);
    logic [7:0] stream_byte;

    // Byte indices 0..7: preamble+SFD. 8..67: Ethernet frame excluding FCS.
    // 68..71: FCS (least-significant byte first). 72 bytes total, 144 nibbles.
    always_comb begin
        stream_byte = 8'h00;
        if (byte_index <= 7'd6) stream_byte = 8'h55;
        else if (byte_index == 7'd7) stream_byte = 8'hd5;
        else if (byte_index >= 7'd8 && byte_index <= 7'd13) stream_byte=8'hff;
        else if (byte_index >= 7'd14 && byte_index <= 7'd71) begin
            case (byte_index)
                // Sender MAC + EtherType IPv4
                7'd14: stream_byte=8'h02;
                7'd15: stream_byte=8'h11;
                7'd16: stream_byte=8'h22;
                7'd17: stream_byte=8'h33;
                7'd18: stream_byte=8'h44;
                7'd19: stream_byte=8'h55;
                7'd20: stream_byte=8'h08;
                7'd21: stream_byte=8'h00;
                // IPv4, no options or fragmentation, UDP, TTL 64
                7'd22: stream_byte=8'h45;
                7'd23: stream_byte=8'h00;
                7'd24: stream_byte=ip_len[15:8];
                7'd25: stream_byte=ip_len[7:0];
                7'd26: stream_byte=8'h00;
                7'd27: stream_byte=8'h42;
                7'd28: stream_byte=8'h00;
                7'd29: stream_byte=8'h00;
                7'd30: stream_byte=8'h40;
                7'd31: stream_byte=8'h11;
                7'd32: stream_byte=ip_csum[15:8];
                7'd33: stream_byte=ip_csum[7:0];
                // Source 192.168.77.2, dest 192.168.77.255
                7'd34,7'd38: stream_byte=8'hc0;
                7'd35,7'd39: stream_byte=8'ha8;
                7'd36,7'd40: stream_byte=8'h4d;
                7'd37: stream_byte=8'h02;
                7'd41: stream_byte=8'hff;
                // UDP ports 5000 -> 5001, zero IPv4 UDP checksum
                7'd42: stream_byte=8'h13;
                7'd43: stream_byte=8'h88;
                7'd44: stream_byte=8'h13;
                7'd45: stream_byte=8'h89;
                7'd46: stream_byte=udp_len[15:8];
                7'd47: stream_byte=udp_len[7:0];
                7'd48,7'd49: stream_byte=8'h00;
                // CRC transmitted low byte first; CRC includes zero padding.
                7'd68: stream_byte=~crc[7:0];
                7'd69: stream_byte=~crc[15:8];
                7'd70: stream_byte=~crc[23:16];
                7'd71: stream_byte=~crc[31:24];
                default: begin
                    if ((byte_index >= 7'd50) &&
                        (byte_index < (7'd50 + {3'b000,held_len})))
                        stream_byte = held_data[111-8*(byte_index-7'd50) -: 8];
                    else stream_byte=8'h00; // Ethernet minimum-frame padding
                end
            endcase
        end
    end

    always_ff @(negedge tx_clk or negedge rst_n) begin
        if (!rst_n) begin
            req_meta<=0; req_sync<=0;
            held_data<=0; held_len<=0; byte_index<=0;
            high_nibble<=0; crc<=32'hFFFFFFFF;
            gap_count<=0; state<=IDLE; ack_toggle<=0;
            eth_tx_en<=0; eth_txd<=0;
        end else begin
            req_meta<=req_toggle_async;
            req_sync<=req_meta;
            case (state)
                IDLE: begin
                    eth_tx_en<=0;
                    eth_txd<=0;
                    if (req_sync != ack_toggle) begin
                        // The request toggle is synchronised. Capture the
                        // producer-held multi-bit mailbox into TX-domain
                        // registers; DO NOT use async length as an FSM/CE
                        // control. The producer holds data until ack_toggle.
                        held_data<=response_data;
                        held_len<=response_len;
                        byte_index<=0;
                        high_nibble<=0;
                        crc<=32'hFFFFFFFF;
                        state<=VALIDATE;
                    end
                end
                VALIDATE: begin
                    // This decision uses ONLY TX-domain registered values.
                    // Invalid lengths are rejected with an acknowledgement
                    // but no MII frame, preventing handshake deadlock.
                    if ((held_len == 4'd1) || (held_len == 4'd14))
                        state<=STREAM;
                    else begin
                        ack_toggle<=req_sync;
                        state<=IDLE;
                    end
                end
                STREAM: begin
                    eth_tx_en<=1;
                    eth_txd<=high_nibble ? stream_byte[7:4] : stream_byte[3:0];
                    if (high_nibble) begin
                        if (byte_index >= 7'd8 && byte_index <= 7'd67)
                            crc <= crc_byte(crc,stream_byte);
                        high_nibble<=0;
                        if (byte_index == 7'd71) begin
                            gap_count<=0;
                            state<=GAP;
                        end else byte_index<=byte_index+1'b1;
                    end else high_nibble<=1;
                end
                GAP: begin
                    eth_tx_en<=0;
                    eth_txd<=0;
                    if (gap_count == 5'd23) begin
                        // Acknowledge only after a full 12-byte minimum IFG.
                        ack_toggle<=req_sync;
                        state<=IDLE;
                    end else gap_count<=gap_count+1'b1;
                end
                default: state<=IDLE;
            endcase
        end
    end
endmodule
