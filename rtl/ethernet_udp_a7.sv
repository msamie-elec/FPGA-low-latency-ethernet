// SPDX-License-Identifier: MIT
// Milestone M2B v0.5 engineering candidate: preserve v0.4B Ethernet RX
// and UART output, add a PHY-clocked MII Ethernet UDP broadcast response.
module ethernet_udp_a7 #(
    parameter integer UART_BAUD=115200,
    parameter integer PHY_RESET_CYCLES=1000000
)(
    input  wire       clk,
    input  wire       btn0,
    output wire [3:0] led,
    input  wire       eth_rx_clk,
    input  wire       eth_tx_clk,
    input  wire       eth_rx_dv,
    input  wire       eth_rxerr,
    input  wire [3:0] eth_rxd,
    output wire       eth_ref_clk,
    output wire       eth_rstn,
    output wire       eth_tx_en,
    output wire [3:0] eth_txd,
    output wire       uart_tx_o
);
    // The PHY needs 25 MHz at X1 even when no Ethernet traffic is present.
    // Fabric divider is used for this first bring-up; validate clock waveform
    // and duty cycle on the actual board before production-style qualification.
    logic [1:0] div4 = 0;
    always_ff @(posedge clk) div4 <= div4 + 1'b1;
    assign eth_ref_clk = div4[1];

    logic [2:0] rst_pipe = 0;
    always_ff @(posedge clk or posedge btn0) begin
        if (btn0) rst_pipe <= 0;
        else rst_pipe <= {rst_pipe[1:0], 1'b1};
    end
    wire sys_rst_n = rst_pipe[2];

    localparam integer RESET_WIDTH = $clog2(PHY_RESET_CYCLES+1);
    logic [RESET_WIDTH-1:0] reset_count = 0;
    logic phy_ready = 0;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin reset_count <= 0; phy_ready <= 0; end
        else if (!phy_ready) begin
            if (reset_count == PHY_RESET_CYCLES-1) phy_ready <= 1;
            else reset_count <= reset_count+1'b1;
        end
    end
    assign eth_rstn = phy_ready;

    (* ASYNC_REG="TRUE" *) logic rx_rst1, rx_rst2;
    (* ASYNC_REG="TRUE" *) logic tx_rst1, tx_rst2;
    always_ff @(posedge eth_tx_clk or negedge phy_ready) begin
        if (!phy_ready) begin tx_rst1 <= 0; tx_rst2 <= 0; end
        else begin tx_rst1 <= 1; tx_rst2 <= tx_rst1; end
    end
    always_ff @(posedge eth_rx_clk or negedge phy_ready) begin
        if (!phy_ready) begin rx_rst1 <= 0; rx_rst2 <= 0; end
        else begin rx_rst1 <= 1; rx_rst2 <= rx_rst1; end
    end

    logic rx_req_toggle, rx_good_toggle, rx_reject_toggle, rx_ack_toggle;
    wire [127:0] rx_payload;
    mii_udp_rx u_mii (
        .rx_clk(eth_rx_clk), .rst_n(rx_rst2),
        .eth_rx_dv(eth_rx_dv), .eth_rxerr(eth_rxerr), .eth_rxd(eth_rxd),
        .ack_toggle_async(rx_ack_toggle), .req_toggle(rx_req_toggle),
        .payload(rx_payload), .good_toggle(rx_good_toggle),
        .reject_toggle(rx_reject_toggle)
    );
    (* ASYNC_REG="TRUE" *) logic req_meta, req_sync;
    (* ASYNC_REG="TRUE" *) logic bad_meta, bad_sync;
    (* ASYNC_REG="TRUE" *) logic tx_ack_meta, tx_ack_sync;
    logic tx_req_toggle;
    wire tx_ack_toggle;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin req_meta<=0; req_sync<=0; bad_meta<=0; bad_sync<=0; tx_ack_meta<=0; tx_ack_sync<=0; end
        else begin
            req_meta <= rx_req_toggle; req_sync <= req_meta;
            bad_meta <= rx_reject_toggle; bad_sync <= bad_meta;
            tx_ack_meta <= tx_ack_toggle; tx_ack_sync <= tx_ack_meta;
        end
    end

    logic [127:0] record_buf;
    logic [3:0] byte_index;
    logic [3:0] state;
    localparam logic [3:0] WAIT_FRAME=0, SEND_BYTES=1, WAIT_RESULT=2,
        TX_LOAD=3, TX_WAIT_BUSY=4, TX_WAIT_READY=5, WAIT_NET_REPLY=6;
    wire feed_ready, parse_error, ignored, report_valid;
    wire [31:0] report_seq,report_bid,report_ask;
    wire report_signal;
    wire feed_valid=(state==SEND_BYTES);
    wire [7:0] feed_byte=record_buf[127-byte_index*8 -:8];
    wire feed_last=(byte_index==15);
    wire report_ready=(state==WAIT_RESULT);

    feed_pipeline u_core (
        .clk(clk), .rst_n(sys_rst_n),
        .s_data(feed_byte), .s_valid(feed_valid),
        .s_ready(feed_ready), .s_last(feed_last),
        .parse_error(parse_error), .event_ignored(ignored),
        .report_valid(report_valid), .report_ready(report_ready),
        .report_seq(report_seq), .report_bid(report_bid),
        .report_ask(report_ask), .report_signal(report_signal)
    );

    logic tx_valid;
    logic [7:0] tx_byte;
    wire tx_ready;
    uart_tx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_uart (
        .clk(clk),.rst_n(sys_rst_n),.data(tx_byte),
        .valid(tx_valid),.ready(tx_ready),.tx_pin(uart_tx_o)
    );
    logic [111:0] tx_data_buf;
    logic [3:0] tx_len, tx_index;
    mii_udp_tx u_mii_tx (
        .tx_clk(eth_tx_clk), .rst_n(tx_rst2),
        .req_toggle_async(tx_req_toggle),
        .response_data(tx_data_buf), .response_len(tx_len),
        .ack_toggle(tx_ack_toggle),
        .eth_tx_en(eth_tx_en), .eth_txd(eth_txd)
    );
    logic led_accept, led_reply, led_error;
    // Rejection-event history is registered in the destination domain.
    // Never use bad_meta (the first asynchronous sampling stage) in application logic.
    logic bad_seen;
    logic [24:0] heartbeat;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            state<=WAIT_FRAME; rx_ack_toggle<=0; tx_req_toggle<=0;
            record_buf<=0; byte_index<=0;
            tx_valid<=0; tx_byte<=0;
            tx_data_buf<=0; tx_len<=0; tx_index<=0;
            led_accept<=0; led_reply<=0; led_error<=0; bad_seen<=0; heartbeat<=0;
        end else begin
            heartbeat<=heartbeat+1'b1;
            tx_valid<=0;
            // Event detection only after the two-flop ASYNC_REG synchronizer.
            // The event is sticky on LD6; a toggle is safe for this slow diagnostic.
            if (bad_sync != bad_seen) begin
                bad_seen <= bad_sync;
                led_error <= 1'b1;
            end
            case (state)
                WAIT_FRAME: begin
                    if (req_sync != rx_ack_toggle) begin
                        // Stable multi-bit mailbox: data changes before the
                        // synchronised request and is held until acknowledgement.
                        record_buf<=rx_payload;
                        byte_index<=0;
                        led_accept<=~led_accept;
                        state<=SEND_BYTES;
                    end
                end
                SEND_BYTES: if (feed_ready) begin
                    if (byte_index==15) state<=WAIT_RESULT;
                    else byte_index<=byte_index+1'b1;
                end
                WAIT_RESULT: begin
                    if (parse_error) begin
                        tx_data_buf<={8'h45,104'b0}; tx_len<=1; tx_index<=0;
                        state<=TX_LOAD;
                    end else if (ignored) begin
                        tx_data_buf<={8'h49,104'b0}; tx_len<=1; tx_index<=0;
                        state<=TX_LOAD;
                    end else if (report_valid) begin
                        tx_data_buf<={8'h52,report_seq,report_bid,report_ask,7'b0,report_signal};
                        tx_len<=14; tx_index<=0;
                        state<=TX_LOAD;
                    end
                end
                TX_LOAD: if (tx_ready) begin
                    tx_byte<=tx_data_buf[111-tx_index*8 -:8];
                    tx_valid<=1;
                    state<=TX_WAIT_BUSY;
                end
                TX_WAIT_BUSY: if (!tx_ready) state<=TX_WAIT_READY;
                TX_WAIT_READY: if (tx_ready) begin
                    if (tx_index==tx_len-1'b1) begin
                        // Ethernet TX sees the same stable 1/14-byte response.
                        // Keep response and incoming mailbox held until TX ack.
                        tx_req_toggle<=~tx_req_toggle;
                        state<=WAIT_NET_REPLY;
                    end else begin
                        tx_index<=tx_index+1'b1;
                        state<=TX_LOAD;
                    end
                end
                WAIT_NET_REPLY: if (tx_ack_sync == tx_req_toggle) begin
                    rx_ack_toggle<=req_sync;
                    led_reply<=~led_reply;
                    state<=WAIT_FRAME;
                end
                default: state<=WAIT_FRAME;
            endcase
        end
    end
    assign led={led_reply, led_error, led_accept, heartbeat[24]};
endmodule
