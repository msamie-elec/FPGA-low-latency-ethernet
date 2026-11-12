// SPDX-License-Identifier: MIT
// Physical USB-UART test top. Not an Ethernet/MII implementation.
// FPGA-centric UART naming: RX from host, TX to host.
// Arty A7: FPGA RX=A9, FPGA TX=D10 (confirmed by v0.4 echo hardware test).
// Accepts 16 raw bytes per synthetic feed record; host must wait for response.
// Response: R + seq[4] + bid[4] + ask[4] + signal[1], E (malformed), I (ignored).
module board_uart_demo #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input logic clk,
    input logic [0:0] btn,
    output logic [3:0] led,
    input logic uart_rx_i,
    output logic uart_tx_o
);
    logic [2:0] reset_pipe = 3'b000;
    always_ff @(posedge clk or posedge btn[0]) begin
        if (btn[0]) reset_pipe <= 3'b000;
        else reset_pipe <= {reset_pipe[1:0],1'b1};
    end
    wire rst_n = reset_pipe[2];

    wire [7:0] rx_data;
    wire rx_valid, rx_error;
    uart_rx #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_rx (
        .clk(clk), .rst_n(rst_n), .rx_pin(uart_rx_i),
        .data(rx_data), .valid(rx_valid), .framing_error(rx_error)
    );
    logic [3:0] rx_index;
    wire ready_in, parse_error, ignored, report_valid;
    wire [31:0] seq, bid, ask;
    wire signal_hit, report_ready;
    feed_pipeline u_core (
        .clk(clk), .rst_n(rst_n),
        .s_data(rx_data), .s_valid(rx_valid),
        .s_ready(ready_in), .s_last(rx_index == 4'd15),
        .parse_error(parse_error), .event_ignored(ignored),
        .report_valid(report_valid), .report_ready(report_ready),
        .report_seq(seq), .report_bid(bid), .report_ask(ask),
        .report_signal(signal_hit)
    );
    // The UART does not support flow control. The host always sends exactly
    // one 16-byte request and waits for the complete response before continuing.
    // Unexpected traffic while the processor is stalled is not guaranteed.
    logic [111:0] tx_payload;
    logic [3:0] tx_length, tx_index;
    logic tx_start;
    logic [7:0] tx_data;
    wire tx_ready;
    localparam logic [2:0] IDLE=0, LOAD=1, WAIT_BUSY=2, WAIT_READY=3;
    logic [2:0] tx_state;
    assign report_ready = (tx_state == IDLE) && !parse_error && !ignored;
    uart_tx #(.CLOCK_HZ(CLOCK_HZ), .BAUD(BAUD)) u_tx (
        .clk(clk), .rst_n(rst_n), .data(tx_data),
        .valid(tx_start), .ready(tx_ready), .tx_pin(uart_tx_o)
    );
    logic signal_seen, error_seen, activity;
    logic [24:0] heartbeat;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_index <= 0;
            tx_payload <= 0; tx_length <= 0; tx_index <= 0;
            tx_state <= IDLE; tx_start <= 0; tx_data <= 0;
            signal_seen <= 0; error_seen <= 0; activity <= 0;
            heartbeat <= 0;
        end else begin
            heartbeat <= heartbeat+1'b1;
            tx_start <= 0;
            if (rx_error || (rx_valid && !ready_in)) error_seen <= 1;
            if (rx_error) rx_index <= 0;
            else if (rx_valid && ready_in) rx_index <= rx_index+1'b1;
            if (parse_error) error_seen <= 1;
            if (report_valid && signal_hit) signal_seen <= 1;
            case (tx_state)
                IDLE: begin
                    if (parse_error) begin
                        tx_payload <= {8'h45,104'b0}; tx_length <= 4'd1;
                        tx_index <= 0; tx_state <= LOAD; activity <= ~activity;
                    end else if (ignored) begin
                        tx_payload <= {8'h49,104'b0}; tx_length <= 4'd1;
                        tx_index <= 0; tx_state <= LOAD; activity <= ~activity;
                    end else if (report_valid) begin
                        tx_payload <= {8'h52, seq, bid, ask, 7'b0, signal_hit};
                        tx_length <= 4'd14;
                        tx_index <= 0; tx_state <= LOAD; activity <= ~activity;
                    end
                end
                LOAD: if (tx_ready) begin
                    tx_data <= tx_payload[111-(tx_index*8) -: 8];
                    tx_start <= 1; tx_state <= WAIT_BUSY;
                end
                WAIT_BUSY: if (!tx_ready) tx_state <= WAIT_READY;
                WAIT_READY: if (tx_ready) begin
                    if (tx_index == tx_length-1'b1) tx_state <= IDLE;
                    else begin tx_index <= tx_index+1'b1; tx_state <= LOAD; end
                end
                default: tx_state <= IDLE;
            endcase
        end
    end
    assign led = {activity, error_seen, signal_seen, heartbeat[24]};
endmodule

module board_uart_a7 (
    input logic clk, input logic [0:0] btn, output logic [3:0] led,
    input logic uart_rx_i, output logic uart_tx_o
);
    board_uart_demo #(.CLOCK_HZ(100000000)) u_board(.*);
endmodule

module board_uart_s7 (
    input logic clk, input logic [0:0] btn, output logic [3:0] led,
    input logic uart_rx_i, output logic uart_tx_o
);
    board_uart_demo #(.CLOCK_HZ(12000000)) u_board(.*);
endmodule
