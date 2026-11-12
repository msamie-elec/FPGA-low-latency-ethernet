// SPDX-License-Identifier: MIT
module feed_pipeline #(
    parameter logic [7:0] SYMBOL_ID = 8'h01,
    parameter logic [31:0] SPREAD_THRESHOLD_TICKS = 32'd5
) (
    input  logic clk,
    input  logic rst_n,
    input  logic [7:0] s_data,
    input  logic s_valid,
    output logic s_ready,
    input  logic s_last,
    output logic parse_error,
    output logic event_ignored,
    output logic report_valid,
    input  logic report_ready,
    output logic [31:0] report_seq,
    output logic [31:0] report_bid,
    output logic [31:0] report_ask,
    output logic report_signal
);
    logic event_valid, event_ready;
    logic [7:0] event_type, event_symbol;
    logic [31:0] event_seq, event_price, event_qty;

    feed_parser u_parser (
        .clk(clk), .rst_n(rst_n), .s_data(s_data), .s_valid(s_valid),
        .s_ready(s_ready), .s_last(s_last), .event_valid(event_valid),
        .event_ready(event_ready), .event_type(event_type),
        .event_symbol(event_symbol), .event_seq(event_seq),
        .event_price(event_price), .event_qty(event_qty),
        .parse_error(parse_error)
    );

    top_of_book #(.SYMBOL_ID(SYMBOL_ID), .SPREAD_THRESHOLD_TICKS(SPREAD_THRESHOLD_TICKS)) u_book (
        .clk(clk), .rst_n(rst_n), .event_valid(event_valid),
        .event_ready(event_ready), .event_ignored(event_ignored), .event_type(event_type),
        .event_symbol(event_symbol), .event_seq(event_seq),
        .event_price(event_price), .event_qty(event_qty),
        .report_valid(report_valid), .report_ready(report_ready),
        .report_seq(report_seq), .report_bid(report_bid),
        .report_ask(report_ask), .report_signal(report_signal)
    );
endmodule
