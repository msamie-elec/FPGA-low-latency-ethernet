// SPDX-License-Identifier: MIT
// UART 8N1, stable data accepted on valid && ready; ready is high when idle.
module uart_tx #(
    parameter integer CLOCK_HZ = 100000000,
    parameter integer BAUD = 115200
) (
    input  logic clk, rst_n,
    input  logic [7:0] data,
    input  logic valid,
    output wire ready,
    output logic tx_pin
);
    localparam integer CPB = (CLOCK_HZ + BAUD/2) / BAUD;
    localparam integer CW = (CPB > 1) ? $clog2(CPB+1) : 1;
    localparam logic [1:0] IDLE=0, START=1, BITS=2, STOP=3;
    logic [1:0] state;
    logic [CW-1:0] ticks;
    logic [2:0] index;
    logic [7:0] shift;
    assign ready = (state == IDLE);
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; ticks <= 0; index <= 0; shift <= 0; tx_pin <= 1;
        end else begin
            case (state)
                IDLE: if (valid) begin
                    shift <= data;
                    tx_pin <= 0;
                    ticks <= CPB-1;
                    state <= START;
                end
                START: if (ticks == 0) begin
                    tx_pin <= shift[0]; index <= 0;
                    ticks <= CPB-1; state <= BITS;
                end else ticks <= ticks-1'b1;
                BITS: if (ticks == 0) begin
                    ticks <= CPB-1;
                    if (index == 3'd7) begin
                        tx_pin <= 1;
                        state <= STOP;
                    end else begin
                        index <= index+1'b1;
                        tx_pin <= shift[index+1'b1];
                    end
                end else ticks <= ticks-1'b1;
                STOP: if (ticks == 0) state <= IDLE;
                      else ticks <= ticks-1'b1;
                default: state <= IDLE;
            endcase
        end
    end
endmodule
