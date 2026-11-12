// SPDX-License-Identifier: MIT
// M4B single-clock ready/valid FIFO. Full-depth capacity, FWFT read.
// Supports same-cycle enqueue/dequeue when full (no unnecessary bubble).
module m4b_sync_fifo #(
    parameter integer WIDTH = 116,
    parameter integer DEPTH = 8
)(
    input wire clk,
    input wire rst_n,
    input wire in_valid,
    input wire [WIDTH-1:0] in_data,
    output wire in_ready,
    output wire out_valid,
    output wire [WIDTH-1:0] out_data,
    input wire out_ready,
    output wire full,
    output wire empty
);
    localparam integer AW = $clog2(DEPTH);
    localparam integer CW = $clog2(DEPTH+1);
    (* ram_style = "distributed" *) logic [WIDTH-1:0] storage [0:DEPTH-1];
    logic [AW-1:0] head, tail;
    logic [CW-1:0] used;
    wire pop = out_valid && out_ready;
    wire push = in_valid && in_ready;
    assign empty = (used == 0);
    assign full = (used == DEPTH);
    assign out_valid = !empty;
    assign in_ready = !full || pop;
    assign out_data = storage[head];
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            head <= 0;
            tail <= 0;
            used <= 0;
        end else begin
            if (push) begin
                storage[tail] <= in_data;
                tail <= (tail == DEPTH-1) ? 0 : tail + 1'b1;
            end
            if (pop) head <= (head == DEPTH-1) ? 0 : head + 1'b1;
            case ({push,pop})
                2'b10: used <= used + 1'b1;
                2'b01: used <= used - 1'b1;
                default: ;
            endcase
        end
    end
endmodule
