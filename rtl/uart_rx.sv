// SPDX-License-Identifier: MIT
// 8N1 UART receiver, clock-synchronous output pulse. No hardware flow control.
module uart_rx #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input  logic clk, rst_n,
    input  logic rx_pin,
    output logic [7:0] data,
    output logic valid,
    output logic framing_error
);
    localparam integer CPB = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam integer CW = (CPB > 1) ? $clog2(CPB+1) : 1;
    localparam logic [1:0] IDLE=0, START=1, BITS=2, STOP=3;
    logic [1:0] state;
    logic rx_meta, rx_sync;
    logic [CW-1:0] ticks;
    logic [2:0] index;
    logic [7:0] shift;
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx_pin;
            rx_sync <= rx_meta;
        end
    end
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; ticks <= 0; index <= 0; shift <= 0;
            data <= 0; valid <= 0; framing_error <= 0;
        end else begin
            valid <= 0;
            framing_error <= 0;
            case (state)
                IDLE: if (!rx_sync) begin
                    ticks <= CPB/2;
                    state <= START;
                end
                START: if (ticks == 0) begin
                    if (!rx_sync) begin
                        state <= BITS;
                        ticks <= CPB-1;
                        index <= 0;
                    end else state <= IDLE;
                end else ticks <= ticks-1'b1;
                BITS: if (ticks == 0) begin
                    shift[index] <= rx_sync;
                    ticks <= CPB-1;
                    if (index == 3'd7) state <= STOP;
                    else index <= index+1'b1;
                end else ticks <= ticks-1'b1;
                STOP: if (ticks == 0) begin
                    if (rx_sync) begin
                        data <= shift;
                        valid <= 1;
                    end else framing_error <= 1;
                    state <= IDLE;
                end else ticks <= ticks-1'b1;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
