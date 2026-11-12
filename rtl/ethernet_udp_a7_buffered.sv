// SPDX-License-Identifier: MIT
// M4B v0.8B experimental buffered 100-Mbit Ethernet endpoint.
// Keeps the proven feed_pipeline and PHY MII timing scheme unchanged.
// RX MII clock -> depth-16 dual-clock record FIFO -> 100-MHz core ->
// depth-16 dual-clock Ethernet TX FIFO (TX clock falling-edge reader), and
// independent depth-8 100-MHz UART debug FIFO (drop debug if full).
// Fully bounded; overload counts drops rather than overwriting unread data.
// No ARP/ICMP/DHCP/IP/UDP checksum validation; narrow UDP broadcast protocol.
module ethernet_udp_a7_buffered #(
    parameter integer UART_BAUD=115200,
    parameter integer PHY_RESET_CYCLES=1000000,
    parameter integer RX_DEPTH=16,
    parameter integer TX_DEPTH=16,
    parameter integer UART_DEPTH=8
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
    // The clocking scheme and board XDC are inherited from v0.7. Still
    // requires physical duty cycle/skew qualification, as in the baseline.
    logic [1:0] div4 = 0;
    always_ff @(posedge clk) div4 <= div4 + 1'b1;
    assign eth_ref_clk = div4[1];
    logic [2:0] rst_pipe = 0;
    always_ff @(posedge clk or posedge btn0) begin
        if (btn0) rst_pipe <= 0;
        else rst_pipe <= {rst_pipe[1:0],1'b1};
    end
    wire sys_rst_n = rst_pipe[2];
    localparam integer RCW=$clog2(PHY_RESET_CYCLES+1);
    logic [RCW-1:0] reset_count = 0;
    logic phy_ready = 0;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin reset_count<=0;phy_ready<=0;end
        else if (!phy_ready) begin
            if (reset_count==PHY_RESET_CYCLES-1) phy_ready<=1;
            else reset_count<=reset_count+1'b1;
        end
    end
    assign eth_rstn=phy_ready;
    (* ASYNC_REG="TRUE" *) logic rx_rst1,rx_rst2,tx_rst1,tx_rst2;
    always_ff @(posedge eth_rx_clk or negedge phy_ready) begin
        if (!phy_ready) begin rx_rst1<=0; rx_rst2<=0; end
        else begin rx_rst1<=1; rx_rst2<=rx_rst1; end
    end
    always_ff @(posedge eth_tx_clk or negedge phy_ready) begin
        if (!phy_ready) begin tx_rst1<=0; tx_rst2<=0; end
        else begin tx_rst1<=1; tx_rst2<=tx_rst1; end
    end

    // ----- RX domain: validated packet enters a true async FIFO -----
    wire rx_frame_valid;
    wire [127:0] rx_frame_data;
    wire [15:0] rx_drop_src,rx_invalid_src;
    wire [15:0] rx_drop_gray,rx_invalid_gray;
    wire rx_full, rx_fifo_valid,rx_fifo_empty;
    wire [127:0] rx_fifo_data;
    wire rx_fifo_pop;
    mii_udp_rx_m4b u_rx (
        .rx_clk(eth_rx_clk),.rst_n(rx_rst2),
        .eth_rx_dv(eth_rx_dv),.eth_rxerr(eth_rxerr),.eth_rxd(eth_rxd),
        .fifo_full(rx_full),.frame_valid(rx_frame_valid),
        .frame_data(rx_frame_data),.overflow_count(rx_drop_src),
        .invalid_frame_count(rx_invalid_src),
        .overflow_gray(rx_drop_gray),.invalid_frame_gray(rx_invalid_gray)
    );
    m4b_async_fifo #(.WIDTH(128),.DEPTH(RX_DEPTH)) u_rx_fifo (
        .wr_clk(eth_rx_clk),.wr_rst_n(rx_rst2),
        .wr_valid(rx_frame_valid),.wr_data(rx_frame_data),
        .wr_ready(),.wr_full(rx_full),
        .rd_clk(clk),.rd_rst_n(sys_rst_n),
        .rd_valid(rx_fifo_valid),.rd_data(rx_fifo_data),
        .rd_ready(rx_fifo_pop),.rd_empty(rx_fifo_empty)
    );

    // ----- Original 100-MHz processing engine: byte-by-byte, in order -----
    logic [127:0] record_buf;
    logic [3:0] byte_index;
    logic [1:0] core_state;
    localparam logic [1:0] WAIT_FRAME=0, SEND_BYTES=1,
                           WAIT_RESULT=2, WAIT_PUSH=3;
    assign rx_fifo_pop = (core_state==WAIT_FRAME) && rx_fifo_valid;
    wire feed_ready,parse_error,ignored,report_valid;
    wire [31:0] report_seq,report_bid,report_ask;
    wire report_signal;
    wire feed_valid = (core_state==SEND_BYTES);
    wire [7:0] feed_byte = record_buf[127-byte_index*8 -: 8];
    wire feed_last = (byte_index==4'd15);
    wire report_ready = (core_state==WAIT_RESULT);
    feed_pipeline u_core (
        .clk(clk),.rst_n(sys_rst_n),
        .s_data(feed_byte),.s_valid(feed_valid),
        .s_ready(feed_ready),.s_last(feed_last),
        .parse_error(parse_error),.event_ignored(ignored),
        .report_valid(report_valid),.report_ready(report_ready),
        .report_seq(report_seq),.report_bid(report_bid),
        .report_ask(report_ask),.report_signal(report_signal)
    );

    // ----- TX: results enter 100-MHz write / 25-MHz negedge read FIFO -----
    logic [111:0] pending_data;
    logic [3:0] pending_len;
    wire [115:0] pending_entry={pending_data,pending_len};
    wire send_pending=(core_state==WAIT_PUSH);
    wire tx_wr_ready,tx_fifo_valid,tx_fifo_empty,tx_fifo_full;
    wire [115:0] tx_fifo_entry;
    wire tx_pop;
    wire [15:0] tx_sent_src,tx_sent_gray;
    m4b_async_fifo #(.WIDTH(116),.DEPTH(TX_DEPTH),.READ_NEGEDGE(1'b1)) u_tx_fifo (
        .wr_clk(clk),.wr_rst_n(sys_rst_n),
        .wr_valid(send_pending),.wr_data(pending_entry),
        .wr_ready(tx_wr_ready),.wr_full(tx_fifo_full),
        .rd_clk(eth_tx_clk),.rd_rst_n(tx_rst2),
        .rd_valid(tx_fifo_valid),.rd_data(tx_fifo_entry),
        .rd_ready(tx_pop),.rd_empty(tx_fifo_empty)
    );
    mii_udp_tx_m4b u_tx (
        .tx_clk(eth_tx_clk),.rst_n(tx_rst2),
        .response_valid(tx_fifo_valid),
        .response_data(tx_fifo_entry[115:4]),
        .response_len(tx_fifo_entry[3:0]),
        .response_ready(tx_pop),.tx_sent_count(tx_sent_src),
        .tx_sent_gray(tx_sent_gray),
        .eth_tx_en(eth_tx_en),.eth_txd(eth_txd)
    );

    // ----- UART: independent queue; Ethernet is never held for diagnostics -----
    wire dbg_push=send_pending && tx_wr_ready;
    wire dbg_ready,dbg_fifo_valid,dbg_fifo_empty,dbg_fifo_full;
    wire [115:0] dbg_fifo_entry;
    logic [111:0] uart_hold_data;
    logic [3:0] uart_hold_len,uart_index;
    logic [1:0] uart_state;
    localparam logic [1:0] UART_IDLE=0,UART_LOAD=1,
                           UART_WAIT_BUSY=2,UART_WAIT_READY=3;
    wire dbg_pop=(uart_state==UART_IDLE) && dbg_fifo_valid;
    m4b_sync_fifo #(.WIDTH(116),.DEPTH(UART_DEPTH)) u_uart_fifo (
        .clk(clk),.rst_n(sys_rst_n),
        .in_valid(dbg_push),.in_data(pending_entry),
        .in_ready(dbg_ready),.out_valid(dbg_fifo_valid),
        .out_data(dbg_fifo_entry),.out_ready(dbg_pop),
        .full(dbg_fifo_full),.empty(dbg_fifo_empty)
    );
    logic uart_valid;
    logic [7:0] uart_byte;
    wire uart_ready;
    uart_tx #(.CLOCK_HZ(100000000),.BAUD(UART_BAUD)) u_uart (
        .clk(clk),.rst_n(sys_rst_n),.data(uart_byte),
        .valid(uart_valid),.ready(uart_ready),.tx_pin(uart_tx_o)
    );
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if (!sys_rst_n) begin
            uart_state<=UART_IDLE;
            uart_hold_data<=0;uart_hold_len<=0;uart_index<=0;
            uart_valid<=0; uart_byte<=0;
        end else begin
            uart_valid<=0;
            case (uart_state)
                UART_IDLE: if (dbg_fifo_valid) begin
                    uart_hold_data<=dbg_fifo_entry[115:4];
                    uart_hold_len<=dbg_fifo_entry[3:0];
                    uart_index<=0;
                    uart_state<=UART_LOAD;
                end
                UART_LOAD: if (uart_ready) begin
                    uart_byte<=uart_hold_data[111-uart_index*8 -: 8];
                    uart_valid<=1;
                    uart_state<=UART_WAIT_BUSY;
                end
                UART_WAIT_BUSY: if (!uart_ready) uart_state<=UART_WAIT_READY;
                UART_WAIT_READY: if (uart_ready) begin
                    if (uart_index==uart_hold_len-1'b1) uart_state<=UART_IDLE;
                    else begin uart_index<=uart_index+1'b1;uart_state<=UART_LOAD;end
                end
                default: uart_state<=UART_IDLE;
            endcase
        end
    end

    // Gray-code counters before synchronising from PHY clocks. Counters
    // saturate and survive multiple events between destination samples.
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [15:0] drop_meta,drop_sync;
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [15:0] bad_meta,bad_sync;
    (* ASYNC_REG="TRUE", SHREG_EXTRACT="NO" *) logic [15:0] sent_meta,sent_sync;
    function automatic [15:0] gray_to_bin(input [15:0] g);
        integer i;
        begin
            gray_to_bin[15]=g[15];
            for(i=14;i>=0;i=i-1) gray_to_bin[i]=gray_to_bin[i+1]^g[i];
        end
    endfunction
    (* mark_debug = "true" *) wire [15:0] debug_rx_overflows=gray_to_bin(drop_sync);
    (* mark_debug = "true" *) wire [15:0] debug_rx_invalid_frames=gray_to_bin(bad_sync);
    (* mark_debug = "true" *) wire [15:0] debug_tx_frames=gray_to_bin(sent_sync);
    (* mark_debug = "true" *) logic [15:0] debug_uart_drops;
    logic [15:0] prev_tx_count;
    logic [24:0] heartbeat;
    logic led_accept,led_reply,led_error;
    always_ff @(posedge clk or negedge sys_rst_n) begin
        if(!sys_rst_n) begin
            core_state<=WAIT_FRAME;
            record_buf<=0;byte_index<=0;
            pending_data<=0;pending_len<=0;
            debug_uart_drops<=0;prev_tx_count<=0;
            heartbeat<=0;led_accept<=0;led_reply<=0;led_error<=0;
            drop_meta<=0;drop_sync<=0;bad_meta<=0;bad_sync<=0;
            sent_meta<=0;sent_sync<=0;
        end else begin
            heartbeat<=heartbeat+1'b1;
            drop_meta<=rx_drop_gray;drop_sync<=drop_meta;
            bad_meta<=rx_invalid_gray;bad_sync<=bad_meta;
            sent_meta<=tx_sent_gray;sent_sync<=sent_meta;
            if ((debug_rx_overflows!=0)||(debug_rx_invalid_frames!=0)||
                (debug_uart_drops!=0)) led_error<=1;
            if (debug_tx_frames!=prev_tx_count) begin
                prev_tx_count<=debug_tx_frames;
                led_reply<=~led_reply;
            end
            // Diagnostic overload is observable and does not backpressure RX.
            if (dbg_push && !dbg_ready && debug_uart_drops!=16'hffff)
                debug_uart_drops<=debug_uart_drops+1'b1;
            case (core_state)
                WAIT_FRAME: if (rx_fifo_valid) begin
                    record_buf<=rx_fifo_data;
                    byte_index<=0;
                    led_accept<=~led_accept;
                    core_state<=SEND_BYTES;
                end
                SEND_BYTES: if (feed_ready) begin
                    if (byte_index==4'd15) core_state<=WAIT_RESULT;
                    else byte_index<=byte_index+1'b1;
                end
                WAIT_RESULT: begin
                    if (parse_error) begin
                        pending_data<={8'h45,104'b0};pending_len<=1;
                        core_state<=WAIT_PUSH;
                    end else if(ignored) begin
                        pending_data<={8'h49,104'b0};pending_len<=1;
                        core_state<=WAIT_PUSH;
                    end else if(report_valid) begin
                        pending_data<={8'h52,report_seq,report_bid,report_ask,
                                       7'b0,report_signal};
                        pending_len<=14;
                        core_state<=WAIT_PUSH;
                    end
                end
                // Wait only for Ethernet response FIFO space, never UART.
                WAIT_PUSH: if(tx_wr_ready) core_state<=WAIT_FRAME;
                default: core_state<=WAIT_FRAME;
            endcase
        end
    end
    assign led={led_reply,led_error,led_accept,heartbeat[24]};
endmodule
