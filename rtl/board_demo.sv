// SPDX-License-Identifier: MIT
// Minimal physical FPGA smoke demo. No Ethernet/MII implementation in v0.1.
// In both Arty pin-maps, btn[0] is an active-high reset button.
module board_demo (
    input  logic       clk,
    input  logic [0:0] btn,
    output logic [3:0] led
);
    logic [5:0] byte_index = 6'd0;
    logic done = 1'b0;
    logic signal_seen = 1'b0, error_seen = 1'b0;
    logic [24:0] counter = 25'd0;
    wire [7:0] stream_data;
    wire stream_valid = !done;
    wire stream_last = (byte_index[3:0] == 4'd15);
    wire stream_ready, parse_error, report_valid, report_signal;
    wire [31:0] unused_seq, unused_bid, unused_ask;
    wire rst_n = ~btn[0];

    // B/1 seq=1 bid=10000 qty=5; A/1 seq=2 ask=10003 qty=8;
    // A/1 seq=3 ask=10020 qty=1 with invalid reserved byte.
    // Hex frames are built into a small case ROM for easy board smoke-testing.
    function automatic [7:0] rom_byte(input logic [5:0] addr);
        case (addr)
          0:rom_byte=8'h42; 1:rom_byte=8'h01; 2:rom_byte=0; 3:rom_byte=0;
          4:rom_byte=0; 5:rom_byte=1; 6:rom_byte=0; 7:rom_byte=0;
          8:rom_byte=8'h27; 9:rom_byte=8'h10; 10:rom_byte=0; 11:rom_byte=0;
          12:rom_byte=0; 13:rom_byte=5; 14:rom_byte=0; 15:rom_byte=0;
          16:rom_byte=8'h41; 17:rom_byte=8'h01; 18:rom_byte=0; 19:rom_byte=0;
          20:rom_byte=0; 21:rom_byte=2; 22:rom_byte=0; 23:rom_byte=0;
          24:rom_byte=8'h27; 25:rom_byte=8'h13; 26:rom_byte=0; 27:rom_byte=0;
          28:rom_byte=0; 29:rom_byte=8; 30:rom_byte=0; 31:rom_byte=0;
          32:rom_byte=8'h41; 33:rom_byte=8'h01; 34:rom_byte=0; 35:rom_byte=0;
          36:rom_byte=0; 37:rom_byte=3; 38:rom_byte=0; 39:rom_byte=0;
          40:rom_byte=8'h27; 41:rom_byte=8'h24; 42:rom_byte=0; 43:rom_byte=0;
          44:rom_byte=0; 45:rom_byte=1; 46:rom_byte=8'h01; 47:rom_byte=0;
          default:rom_byte=0;
        endcase
    endfunction
    assign stream_data = rom_byte(byte_index);
    feed_pipeline dut(
      .clk(clk), .rst_n(rst_n), .s_data(stream_data), .s_valid(stream_valid),
      .s_ready(stream_ready), .s_last(stream_last), .parse_error(parse_error),
      .report_valid(report_valid), .report_ready(1'b1),
      .report_seq(unused_seq), .report_bid(unused_bid),
      .report_ask(unused_ask), .report_signal(report_signal)
    );
    always_ff @(posedge clk) begin
      if (!rst_n) begin
        byte_index <= 0;
        done <= 0;
        signal_seen <= 0;
        error_seen <= 0;
        counter <= 0;
      end else begin
        counter <= counter + 1'b1;
        if (!done && stream_ready) begin
          if (byte_index == 6'd47) done <= 1'b1;
          else byte_index <= byte_index + 1'b1;
        end
        if (report_valid && report_signal) signal_seen <= 1'b1;
        if (parse_error) error_seen <= 1'b1;
      end
    end
    // LEDs 0: heartbeat; 1: qualifying spread seen; 2: bad frame seen; 3: ROM finished.
    assign led = {done, error_seen, signal_seen, counter[24]};
endmodule
