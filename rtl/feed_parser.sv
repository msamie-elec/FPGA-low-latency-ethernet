// SPDX-License-Identifier: MIT
// Fixed 16-byte synthetic feed record decoder. This is NOT an exchange protocol.
// AXI4-Stream-like 8-bit payload input; a packet ends when s_last is accepted.
module feed_parser (
    input  logic        clk,
    input  logic        rst_n,
    input  logic [7:0]  s_data,
    input  logic        s_valid,
    output logic        s_ready,
    input  logic        s_last,
    output logic        event_valid,
    input  logic        event_ready,
    output logic [7:0]  event_type,
    output logic [7:0]  event_symbol,
    output logic [31:0] event_seq,
    output logic [31:0] event_price,
    output logic [31:0] event_qty,
    output logic        parse_error
);
    logic [4:0] count;
    logic       drop_frame;
    logic       malformed;
    logic [31:0] seq_acc, price_acc, qty_acc;
    logic [7:0]  type_acc, symbol_acc;

    // Hold decoded output until consumed. No overwrite under backpressure.
    assign s_ready = !event_valid || event_ready;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count        <= '0;
            drop_frame   <= 1'b0;
            malformed    <= 1'b0;
            seq_acc      <= '0;
            price_acc    <= '0;
            qty_acc      <= '0;
            type_acc     <= '0;
            symbol_acc   <= '0;
            event_valid  <= 1'b0;
            event_type   <= '0;
            event_symbol <= '0;
            event_seq    <= '0;
            event_price  <= '0;
            event_qty    <= '0;
            parse_error  <= 1'b0;
        end else begin
            parse_error <= 1'b0;
            if (event_valid && event_ready)
                event_valid <= 1'b0;

            if (s_valid && s_ready) begin
                if (drop_frame) begin
                    if (s_last) begin
                        drop_frame <= 1'b0;
                        count      <= '0;
                    end
                end else begin
                    // Big-endian fields: type, symbol, sequence, price, quantity, reserved.
                    case (count)
                        5'd0: begin
                            type_acc  <= s_data;
                            malformed <= (s_data != 8'h41 && s_data != 8'h42);
                        end
                        5'd1: symbol_acc <= s_data;
                        5'd2: seq_acc[31:24] <= s_data;
                        5'd3: seq_acc[23:16] <= s_data;
                        5'd4: seq_acc[15:8]  <= s_data;
                        5'd5: seq_acc[7:0]   <= s_data;
                        5'd6: price_acc[31:24] <= s_data;
                        5'd7: price_acc[23:16] <= s_data;
                        5'd8: price_acc[15:8]  <= s_data;
                        5'd9: price_acc[7:0]   <= s_data;
                        5'd10: qty_acc[31:24] <= s_data;
                        5'd11: qty_acc[23:16] <= s_data;
                        5'd12: qty_acc[15:8]  <= s_data;
                        5'd13: qty_acc[7:0]   <= s_data;
                        5'd14: if (s_data != 8'h00) malformed <= 1'b1;
                        default: ; // Byte 15 checked below.
                    endcase

                    if (s_last && count != 5'd15) begin
                        // Truncated frame: discard state and flag one error.
                        parse_error <= 1'b1;
                        count       <= '0;
                    end else if (count == 5'd15) begin
                        count <= '0;
                        if (!s_last) begin
                            // More than 16 bytes. Discard through tlast.
                            parse_error <= 1'b1;
                            drop_frame  <= 1'b1;
                        end else if (malformed || s_data != 8'h00) begin
                            parse_error <= 1'b1;
                        end else begin
                            event_type   <= type_acc;
                            event_symbol <= symbol_acc;
                            event_seq    <= seq_acc;
                            event_price  <= price_acc;
                            event_qty    <= qty_acc;
                            event_valid  <= 1'b1;
                        end
                    end else begin
                        count <= count + 5'd1;
                    end
                end
            end
        end
    end
endmodule
