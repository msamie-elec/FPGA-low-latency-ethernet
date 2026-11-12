// SPDX-License-Identifier: MIT
// M4C final, bounded hardware-native burst benchmark. Board A only.
// Board B is the separately hardware-verified v0.8B buffered endpoint.
// UART command 'A' (100us), 'B' (20us), 'C' (10us) sends BURST_PACKETS
// deterministic 16-byte valid market-data updates. Each request is launched
// only when the PHY/MII transmitter has acknowledged the previous frame.
// UART returns ONE 40-byte summary after end-of-burst receive drain.
// The TX scheduler reports any late launch; offered rate is computed from
// actual, locally timestamped request gaps, NOT Python or UART pacing.
// Reply scoreboard checks CRC/UDP envelope in mii_reply_rx plus report seq.
// It detects duplicates, missing, invalid and unexpected sequence numbers.
// No ARP, line-rate guarantee, FIFO telemetry, IPv4/UDP checksum signoff.
module ethernet_generator_a7_m4c #(
    parameter integer UART_BAUD=115200,
    parameter integer PHY_RESET_CYCLES=1000000,
    parameter integer BURST_PACKETS=1000,
    parameter integer DRAIN_CYCLES=500000,
    parameter integer PERIOD_A_CYCLES=10000,
    parameter integer PERIOD_B_CYCLES=2000,
    parameter integer PERIOD_C_CYCLES=1000
)(
    input wire clk,
    input wire btn0,
    output wire [3:0] led,
    input wire eth_rx_clk,
    input wire eth_tx_clk,
    input wire eth_rx_dv,
    input wire eth_rxerr,
    input wire [3:0] eth_rxd,
    output wire eth_ref_clk,
    output wire eth_rstn,
    output wire eth_tx_en,
    output wire [3:0] eth_txd,
    input wire uart_rx_i,
    output wire uart_tx_o
);
    logic [1:0] div4=0;
    always_ff @(posedge clk) div4 <= div4+1'b1;
    assign eth_ref_clk=div4[1];
    logic [2:0] rst_pipe=0;
    always_ff @(posedge clk or posedge btn0) begin
        if(btn0) rst_pipe<=0;
        else rst_pipe<={rst_pipe[1:0],1'b1};
    end
    wire sys_rst_n=rst_pipe[2];
    localparam integer RCW=$clog2(PHY_RESET_CYCLES+1);
    logic [RCW-1:0] reset_counter=0;
    logic phy_ready=0;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin reset_counter<=0;phy_ready<=0;end
        else if (!phy_ready) begin
            if(reset_counter==PHY_RESET_CYCLES-1) phy_ready<=1;
            else reset_counter<=reset_counter+1'b1;
        end
    end
    assign eth_rstn=phy_ready;
    (* ASYNC_REG="TRUE" *) logic tx_rst1,tx_rst2,rx_rst1,rx_rst2;
    always_ff @(negedge eth_tx_clk or negedge phy_ready) begin
        if(!phy_ready) begin tx_rst1<=0;tx_rst2<=0;end
        else begin tx_rst1<=1;tx_rst2<=tx_rst1;end
    end
    always_ff @(posedge eth_rx_clk or negedge phy_ready) begin
        if(!phy_ready) begin rx_rst1<=0;rx_rst2<=0;end
        else begin rx_rst1<=1;rx_rst2<=rx_rst1;end
    end

    logic [127:0] tx_record;
    logic tx_req_toggle;
    wire tx_ack_toggle;
    mii_feed_tx u_feed_tx(
        .tx_clk(eth_tx_clk),.rst_n(tx_rst2),.req_toggle_async(tx_req_toggle),
        .feed_data(tx_record),.ack_toggle(tx_ack_toggle),
        .eth_tx_en(eth_tx_en),.eth_txd(eth_txd)
    );
    logic rx_ack_toggle;
    wire rx_req_toggle,rx_reject_toggle;
    wire [111:0] rx_response;
    wire [3:0] rx_response_len;
    mii_reply_rx u_reply_rx(
        .rx_clk(eth_rx_clk),.rst_n(rx_rst2),
        .eth_rx_dv(eth_rx_dv),.eth_rxerr(eth_rxerr),.eth_rxd(eth_rxd),
        .ack_toggle_async(rx_ack_toggle),.req_toggle(rx_req_toggle),
        .response(rx_response),.response_len(rx_response_len),
        .reject_toggle(rx_reject_toggle)
    );
    (* ASYNC_REG="TRUE" *) logic rx_req_meta,rx_req_sync;
    (* ASYNC_REG="TRUE" *) logic tx_ack_meta,tx_ack_sync;
    (* ASYNC_REG="TRUE" *) logic reject_meta,reject_sync;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            rx_req_meta<=0;rx_req_sync<=0;
            tx_ack_meta<=0;tx_ack_sync<=0;
            reject_meta<=0;reject_sync<=0;
        end else begin
            rx_req_meta<=rx_req_toggle;rx_req_sync<=rx_req_meta;
            tx_ack_meta<=tx_ack_toggle;tx_ack_sync<=tx_ack_meta;
            reject_meta<=rx_reject_toggle;reject_sync<=reject_meta;
        end
    end
    wire [7:0] cmd_data;
    wire cmd_valid,cmd_error;
    uart_rx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_command_rx(
        .clk(clk),.rst_n(sys_rst_n),.rx_pin(uart_rx_i),
        .data(cmd_data),.valid(cmd_valid),.framing_error(cmd_error)
    );
    logic uart_valid;
    logic [7:0] uart_data;
    wire uart_ready;
    uart_tx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_telemetry_tx(
        .clk(clk),.rst_n(sys_rst_n),.data(uart_data),
        .valid(uart_valid),.ready(uart_ready),.tx_pin(uart_tx_o)
    );

    localparam [2:0] IDLE=0,RUN=1,DRAIN=2,UART_LOAD=3,
                     UART_WAIT_BUSY=4,UART_WAIT_READY=5;
    logic [2:0] state;
    logic [31:0] cycle_count,next_due,period_cycles,send_count;
    logic [31:0] first_send_cycle,last_send_cycle,send_span;
    logic [31:0] min_gap,max_gap,late_count,drain_timer;
    logic [31:0] unique_count,duplicate_count,unexpected_count,invalid_count;
    logic [BURST_PACKETS-1:0] seen_reply;
    logic [7:0] profile;
    logic [319:0] telemetry;
    logic [5:0] uart_index;
    logic [111:0] staged_reply;
    logic [3:0] staged_len;
    logic reply_staged;
    logic led_reply,led_send,sticky_error;
    logic [24:0] heartbeat;
    logic bad_seen;
    wire [31:0] next_seq=send_count+32'd1;
    wire [7:0] type_next=next_seq[0] ? 8'h42 : 8'h41;
    wire [31:0] price_next=32'd10000+{28'd0,next_seq[3:0]};
    wire [31:0] reply_seq=staged_reply[103:72];
    wire valid_reply=(staged_len==4'd14 && staged_reply[111:104]==8'h52 &&
                      reply_seq>=1 && reply_seq<=BURST_PACKETS);
    wire [31:0] send_gap=cycle_count-last_send_cycle;
    wire [31:0] launch_late=cycle_count-next_due;

    always_ff @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            state<=IDLE;cycle_count<=0;next_due<=0;period_cycles<=0;
            send_count<=0;first_send_cycle<=0;last_send_cycle<=0;
            send_span<=0;min_gap<=32'hffffffff;max_gap<=0;
            late_count<=0;drain_timer<=0;unique_count<=0;
            duplicate_count<=0;unexpected_count<=0;invalid_count<=0;
            seen_reply<='0;profile<=0;telemetry<=0;uart_index<=0;
            staged_reply<=0;staged_len<=0;reply_staged<=0;
            tx_record<=0;tx_req_toggle<=0;rx_ack_toggle<=0;
            uart_valid<=0;uart_data<=0;led_reply<=0;led_send<=0;
            sticky_error<=0;heartbeat<=0;bad_seen<=0;
        end else begin
            cycle_count<=cycle_count+1'b1;
            heartbeat<=heartbeat+1'b1;
            uart_valid<=0;
            reply_staged<=0;
            if(cmd_error) sticky_error<=1;
            if(reject_sync!=bad_seen) begin
                bad_seen<=reject_sync;
                // Rejection events are diagnostic-only; a toggled event
                // can be missed if asynchronous toggles occur too quickly.
                sticky_error<=1;
            end
            // RX mailbox ACK must not wait for serial telemetry or TX.
            // Stage multi-bit data first; process staged data next cycle.
            if(rx_req_sync!=rx_ack_toggle) begin
                rx_ack_toggle<=rx_req_sync;
                staged_reply<=rx_response;
                staged_len<=rx_response_len;
                reply_staged<=1;
            end
            if(reply_staged && (state==RUN || state==DRAIN)) begin
                if(valid_reply) begin
                    if(seen_reply[reply_seq-1'b1]) begin
                        duplicate_count<=duplicate_count+1'b1;
                        sticky_error<=1;
                    end else begin
                        seen_reply[reply_seq-1'b1]<=1'b1;
                        unique_count<=unique_count+1'b1;
                        led_reply<=~led_reply;
                    end
                end else if(staged_len==4'd14 &&
                            staged_reply[111:104]==8'h52) begin
                    unexpected_count<=unexpected_count+1'b1;
                    sticky_error<=1;
                end else begin
                    invalid_count<=invalid_count+1'b1;
                    sticky_error<=1;
                end
            end
            case(state)
                IDLE: begin
                    if(phy_ready && tx_ack_sync==tx_req_toggle && cmd_valid &&
                       (cmd_data==8'h41 || cmd_data==8'h42 || cmd_data==8'h43)) begin
                        profile<=cmd_data;
                        period_cycles <= (cmd_data==8'h41) ? PERIOD_A_CYCLES :
                                          (cmd_data==8'h42) ? PERIOD_B_CYCLES : PERIOD_C_CYCLES;
                        next_due<=cycle_count+32'd200;
                        send_count<=0;first_send_cycle<=0;last_send_cycle<=0;
                        send_span<=0;min_gap<=32'hffffffff;max_gap<=0;
                        late_count<=0;unique_count<=0;duplicate_count<=0;
                        unexpected_count<=0;invalid_count<=0;seen_reply<='0;
                        state<=RUN;
                    end
                end
                RUN: begin
                    if(send_count<BURST_PACKETS && cycle_count>=next_due &&
                       tx_ack_sync==tx_req_toggle) begin
                        tx_record<={type_next,8'd1,next_seq,price_next,
                                    32'd1,16'd0};
                        tx_req_toggle<=~tx_req_toggle;
                        if(send_count==0) first_send_cycle<=cycle_count;
                        else begin
                            if(send_gap<min_gap) min_gap<=send_gap;
                            if(send_gap>max_gap) max_gap<=send_gap;
                        end
                        if(cycle_count>next_due+32'd1) late_count<=late_count+1'b1;
                        last_send_cycle<=cycle_count;
                        if(send_count==BURST_PACKETS-1)
                            send_span<=cycle_count-first_send_cycle;
                        send_count<=next_seq;
                        next_due<=next_due+period_cycles;
                        led_send<=~led_send;
                    end
                    // Final ack is after MII frame+IFG, not the launch event.
                    if(send_count==BURST_PACKETS && tx_ack_sync==tx_req_toggle) begin
                        drain_timer<=0;
                        state<=DRAIN;
                    end
                end
                DRAIN: begin
                    if(drain_timer==DRAIN_CYCLES-1) begin
                        telemetry<={8'h42,profile,8'h01,8'h00,
                                    send_count,unique_count,duplicate_count,
                                    unexpected_count,invalid_count,late_count,
                                    (send_count<=1 ? 32'd0 : min_gap),
                                    max_gap,send_span};
                        uart_index<=0;
                        state<=UART_LOAD;
                    end else drain_timer<=drain_timer+1'b1;
                end
                UART_LOAD: if(uart_ready) begin
                    uart_data<=telemetry[319-8*uart_index -:8];
                    uart_valid<=1;
                    state<=UART_WAIT_BUSY;
                end
                UART_WAIT_BUSY: if(!uart_ready) state<=UART_WAIT_READY;
                UART_WAIT_READY: if(uart_ready) begin
                    if(uart_index==6'd39) state<=IDLE;
                    else begin uart_index<=uart_index+1'b1;state<=UART_LOAD;end
                end
                default: state<=IDLE;
            endcase
        end
    end
    // LD4 heartbeat, LD5 good reply toggle, LD6 sticky reject/error,
    // LD7 transmitted request toggle. These are lab indicators only.
    assign led={led_send,sticky_error,led_reply,heartbeat[24]};
endmodule
