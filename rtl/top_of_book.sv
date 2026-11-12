// SPDX-License-Identifier: MIT
// One-symbol top-of-book demonstrator; NOT a complete exchange order book.
module top_of_book #(
    parameter logic [7:0] SYMBOL_ID = 8'h01,
    parameter logic [31:0] SPREAD_THRESHOLD_TICKS = 32'd5
) (
    input  logic clk,
    input  logic rst_n,
    input  logic        event_valid,
    output logic        event_ready,
    output logic        event_ignored,
    input  logic [7:0]  event_type,
    input  logic [7:0]  event_symbol,
    input  logic [31:0] event_seq,
    input  logic [31:0] event_price,
    input  logic [31:0] event_qty,
    output logic        report_valid,
    input  logic        report_ready,
    output logic [31:0] report_seq,
    output logic [31:0] report_bid,
    output logic [31:0] report_ask,
    output logic        report_signal
);
    logic [31:0] bid_price, ask_price;
    logic have_bid, have_ask;
    logic [31:0] new_bid, new_ask;
    logic new_have_bid, new_have_ask;

    // `qty=0` and other symbols are ignored (not book deletes).
    assign event_ready = !report_valid || report_ready;
    always_comb begin
        new_bid = bid_price;
        new_ask = ask_price;
        new_have_bid = have_bid;
        new_have_ask = have_ask;
        if (event_type == 8'h42) begin
            new_bid = event_price;
            new_have_bid = 1'b1;
        end else if (event_type == 8'h41) begin
            new_ask = event_price;
            new_have_ask = 1'b1;
        end
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bid_price     <= '0;
            ask_price     <= '0;
            have_bid      <= 1'b0;
            have_ask      <= 1'b0;
            report_valid  <= 1'b0;
            event_ignored <= 1'b0;
            report_seq    <= '0;
            report_bid    <= '0;
            report_ask    <= '0;
            report_signal <= 1'b0;
        end else begin
            event_ignored <= 1'b0;
            if (event_valid && event_ready &&
                (event_symbol != SYMBOL_ID || event_qty == 32'd0))
                event_ignored <= 1'b1;
            if (report_valid && report_ready)
                report_valid <= 1'b0;
            if (event_valid && event_ready && event_symbol == SYMBOL_ID && event_qty != 32'd0) begin
                bid_price     <= new_bid;
                ask_price     <= new_ask;
                have_bid      <= new_have_bid;
                have_ask      <= new_have_ask;
                report_seq    <= event_seq;
                report_bid    <= new_bid;
                report_ask    <= new_ask;
                // `signal` is a purely synthetic boolean exercise, NOT a trade order.
                report_signal <= new_have_bid && new_have_ask &&
                                 (new_ask > new_bid) &&
                                 ((new_ask - new_bid) <= SPREAD_THRESHOLD_TICKS);
                report_valid  <= 1'b1;
            end
        end
    end
endmodule
