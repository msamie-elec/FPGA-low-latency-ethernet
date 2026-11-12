// SPDX-License-Identifier: MIT
// Milestone M2C Board A: one outstanding UDP feed, PHY-based Ethernet TX,
// Ethernet UDP reply RX, RTT measured using A's own 100-MHz counter.
// Host UART commands: 'S' standard feed, 'I' ignored-symbol feed,
// 'E' malformed-type feed. One command at a time, UART reply = 24 bytes:
// 'M' + seq[31:0] + status + response[14 padded bytes] + rtt_cycles[31:0].
// status 'P' accepted and validated; 'S' wrong response; 'T' timeout.
// IMPORTANT RTT spans TX request toggle -> synchronised validated RX event.
// It includes endpoint B UART emission in existing v0.5A: NOT FPGA-only
// processing or wire-to-wire latency. See docs/M2C_ARCHITECTURE.md.
module ethernet_generator_a7_m2c #(
    parameter integer UART_BAUD=115200,
    parameter integer PHY_RESET_CYCLES=1000000,
    parameter integer REPLY_TIMEOUT_CYCLES=50000000
)(
    input  wire clk,
    input  wire btn0,
    output wire [3:0] led,
    input  wire eth_rx_clk,
    input  wire eth_tx_clk,
    input  wire eth_rx_dv,
    input  wire eth_rxerr,
    input  wire [3:0] eth_rxd,
    output wire eth_ref_clk,
    output wire eth_rstn,
    output wire eth_tx_en,
    output wire [3:0] eth_txd,
    input  wire uart_rx_i,
    output wire uart_tx_o
);
    logic [1:0] div4=0;
    always_ff @(posedge clk) div4<=div4+1'b1;
    assign eth_ref_clk=div4[1];
    logic [2:0] rst_pipe=0;
    always_ff @(posedge clk or posedge btn0) begin
        if (btn0) rst_pipe<=0;
        else rst_pipe<={rst_pipe[1:0],1'b1};
    end
    wire sys_rst_n=rst_pipe[2];
    localparam integer RW=$clog2(PHY_RESET_CYCLES+1);
    logic [RW-1:0] reset_ctr=0;
    logic phy_ready=0;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin reset_ctr<=0; phy_ready<=0; end
        else if (!phy_ready) begin
            if (reset_ctr==PHY_RESET_CYCLES-1) phy_ready<=1;
            else reset_ctr<=reset_ctr+1'b1;
        end
    end
    assign eth_rstn=phy_ready;
    (* ASYNC_REG="TRUE" *) logic tx_rst1,tx_rst2,rx_rst1,rx_rst2;
    always_ff @(negedge eth_tx_clk or negedge phy_ready) begin
        if(!phy_ready) begin tx_rst1<=0; tx_rst2<=0; end
        else begin tx_rst1<=1; tx_rst2<=tx_rst1; end
    end
    always_ff @(posedge eth_rx_clk or negedge phy_ready) begin
        if(!phy_ready) begin rx_rst1<=0; rx_rst2<=0; end
        else begin rx_rst1<=1; rx_rst2<=rx_rst1; end
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
        .ack_toggle_async(rx_ack_toggle),
        .req_toggle(rx_req_toggle),.response(rx_response),
        .response_len(rx_response_len),.reject_toggle(rx_reject_toggle)
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
    wire cmd_valid,cmd_framing_error;
    uart_rx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_command_rx(
        .clk(clk),.rst_n(sys_rst_n),.rx_pin(uart_rx_i),
        .data(cmd_data),.valid(cmd_valid),.framing_error(cmd_framing_error)
    );
    logic uart_valid;
    logic [7:0] uart_data;
    wire uart_ready;
    uart_tx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_telemetry_tx(
        .clk(clk),.rst_n(sys_rst_n),.data(uart_data),
        .valid(uart_valid),.ready(uart_ready),.tx_pin(uart_tx_o)
    );
    logic [31:0] cycles,start_cycle,seq,pending_seq;
    logic [7:0] pending_command;
    logic [191:0] telemetry;
    logic [111:0] reply_buf;
    logic [3:0] reply_len;
    logic [31:0] reply_elapsed;
    logic [4:0] uart_index;
    logic [2:0] state;
    localparam [2:0] IDLE=0,WAIT_REPLY=1,UART_LOAD=2,
        UART_WAIT_BUSY=3,UART_WAIT_READY=4,VALIDATE_REPLY=5;
    logic error_sticky,reply_led,send_led;
    logic [24:0] heartbeat;
    logic bad_seen;
    wire [31:0] elapsed=cycles-start_cycle;
    wire [31:0] next_seq=seq+32'd1;
    wire [31:0] next_price=32'd10000 + {28'd0,next_seq[3:0]};
    wire [7:0] next_type=(cmd_data==8'h45) ? 8'h58 :
                         (next_seq[0] ? 8'h42 : 8'h41);
    wire [7:0] next_symbol=(cmd_data==8'h49) ? 8'd2 : 8'd1;
    wire [7:0] expected_code=(pending_command==8'h49) ? 8'h49 :
                             (pending_command==8'h45) ? 8'h45 : 8'h52;
    wire correct_reply=(
        ((expected_code==8'h52) && reply_len==4'd14 &&
         reply_buf[111:104]==8'h52 && reply_buf[103:72]==pending_seq) ||
        ((expected_code!=8'h52) && reply_len==4'd1 &&
         reply_buf[111:104]==expected_code)
    );
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            cycles<=0;start_cycle<=0;seq<=0;pending_seq<=0;
            pending_command<=0;tx_record<=0;tx_req_toggle<=0;rx_ack_toggle<=0;
            telemetry<=0;reply_buf<=0;reply_len<=0;reply_elapsed<=0;
            uart_index<=0;uart_data<=0;uart_valid<=0;
            state<=IDLE;error_sticky<=0;reply_led<=0;send_led<=0;
            heartbeat<=0;bad_seen<=0;
        end else begin
            cycles<=cycles+1'b1;
            heartbeat<=heartbeat+1'b1;
            uart_valid<=0;
            if (cmd_framing_error) error_sticky<=1;
            if (reject_sync!=bad_seen) begin
                bad_seen<=reject_sync;
                error_sticky<=1;
            end
            case(state)
                IDLE: begin
                    // No overlapping TX mailbox: a single outstanding request.
                    if (phy_ready && tx_ack_sync==tx_req_toggle && cmd_valid &&
                        (cmd_data==8'h53 || cmd_data==8'h49 || cmd_data==8'h45)) begin
                        seq<=next_seq;
                        pending_seq<=next_seq;
                        pending_command<=cmd_data;
                        tx_record<={next_type,next_symbol,next_seq,next_price,
                                    32'd1,16'd0};
                        start_cycle<=cycles;
                        tx_req_toggle<=~tx_req_toggle;
                        send_led<=~send_led;
                        state<=WAIT_REPLY;
                    end
                end
                WAIT_REPLY: begin
                    if (rx_req_sync!=rx_ack_toggle) begin
                        // RX mailbox remains unchanged until this ACK returns.
                        rx_ack_toggle<=rx_req_sync;
                        // Stage the entire mailbox first. The following
                        // clock cycle validates ONLY 100-MHz registered data;
                        // never let raw async response bits control an FSM/CE.
                        reply_buf<=rx_response;
                        reply_len<=rx_response_len;
                        reply_elapsed<=elapsed;
                        state<=VALIDATE_REPLY;
                    end else if (elapsed>=REPLY_TIMEOUT_CYCLES) begin
                        telemetry<={8'h4d,pending_seq,8'h54,112'd0,elapsed};
                        uart_index<=0;
                        error_sticky<=1;
                        state<=UART_LOAD;
                    end
                end
                VALIDATE_REPLY: begin
                    telemetry<={8'h4d,pending_seq,
                                correct_reply ? 8'h50 : 8'h53,
                                reply_buf,reply_elapsed};
                    if(!correct_reply) error_sticky<=1;
                    else reply_led<=~reply_led;
                    uart_index<=0;
                    state<=UART_LOAD;
                end
                UART_LOAD: if(uart_ready) begin
                    uart_data<=telemetry[191-8*uart_index -: 8];
                    uart_valid<=1;
                    state<=UART_WAIT_BUSY;
                end
                UART_WAIT_BUSY: if(!uart_ready) state<=UART_WAIT_READY;
                UART_WAIT_READY: if(uart_ready) begin
                    if(uart_index==5'd23) state<=IDLE;
                    else begin uart_index<=uart_index+1'b1; state<=UART_LOAD; end
                end
                default: state<=IDLE;
            endcase
        end
    end
    assign led={send_led,error_sticky,reply_led,heartbeat[24]};
endmodule
