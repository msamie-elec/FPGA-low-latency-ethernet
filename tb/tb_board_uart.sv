// SPDX-License-Identifier: MIT
// End-to-end UART loopback test, FPGA top through UART RX -> parser -> book -> UART TX.
`timescale 1ns/1ps
module tb_board_uart;
    logic clk=0;
    always #5 clk=~clk;
    `ifdef REAL_UART_BAUD
    // Physical A7 configuration: 100 MHz clock and 115200 baud.
    localparam integer CLOCK_HZ=100000000;
    localparam integer BAUD=115200;
    localparam integer LIMIT=3000000;
`else
    // Accelerated simulation for fast regressions.
    localparam integer CLOCK_HZ=10000000;
    localparam integer BAUD=1000000;
    localparam integer LIMIT=100000;
`endif
    localparam integer CPB=(CLOCK_HZ+BAUD/2)/BAUD;
    logic [0:0] btn=1'b1;
    logic uart_rx_i=1'b1;
    wire uart_tx_o;
    wire [3:0] led;
    board_uart_demo #(.CLOCK_HZ(CLOCK_HZ),.BAUD(BAUD)) dut (
        .clk(clk),.btn(btn),.led(led),
        .uart_rx_i(uart_rx_i),.uart_tx_o(uart_tx_o)
    );
    function automatic [127:0] record(input byte side, input byte symbol,
                                      input logic [31:0] seq,
                                      input logic [31:0] price,
                                      input logic [31:0] qty,
                                      input logic [15:0] reserved);
        record={side,symbol,seq,price,qty,reserved};
    endfunction
    task automatic tx_byte(input logic [7:0] b);
        integer j;
        begin
            @(negedge clk); uart_rx_i=0;
            repeat(CPB) @(negedge clk);
            for (j=0;j<8;j=j+1) begin
                uart_rx_i=b[j];
                repeat(CPB) @(negedge clk);
            end
            uart_rx_i=1;
            repeat(CPB) @(negedge clk);
        end
    endtask
    task automatic tx_record(input logic [127:0] r);
        integer j;
        logic [7:0] b;
        begin
            for (j=0;j<16;j=j+1) begin
                b=(r >> ((15-j)*8));
                tx_byte(b);
            end
        end
    endtask
    task automatic rx_byte(output logic [7:0] b);
        integer j;
        begin
            @(negedge uart_tx_o);
            repeat(CPB+CPB/2) @(posedge clk);
            for (j=0;j<8;j=j+1) begin
                b[j]=uart_tx_o;
                repeat(CPB) @(posedge clk);
            end
            if (uart_tx_o !== 1'b1) $fatal(1,"UART stop bit low");
        end
    endtask
    task automatic check_single(input byte expected);
        logic [7:0] got;
        begin
            rx_byte(got);
            if (got !== expected) $fatal(1,"UART status 0x%02x != 0x%02x",got,expected);
        end
    endtask
    task automatic check_report(input integer expected_seq,
                                input integer expected_bid,
                                input integer expected_ask,
                                input bit expected_signal);
        logic [7:0] b;
        logic [31:0] seq,bid,ask;
        logic [7:0] signal_byte;
        integer j;
        begin
            check_single(8'h52);
            seq=0;bid=0;ask=0;
            for(j=0;j<4;j=j+1) begin rx_byte(b); seq=(seq<<8)|b; end
            for(j=0;j<4;j=j+1) begin rx_byte(b); bid=(bid<<8)|b; end
            for(j=0;j<4;j=j+1) begin rx_byte(b); ask=(ask<<8)|b; end
            rx_byte(signal_byte);
            if(seq!==expected_seq || bid!==expected_bid || ask!==expected_ask ||
               signal_byte!=={7'b0,expected_signal})
                $fatal(1,"wrong UART report seq=%0d bid=%0d ask=%0d signal=%0d",seq,bid,ask,signal_byte);
        end
    endtask
    initial begin
        repeat(8) @(negedge clk); btn=0;
        repeat(8) @(negedge clk);
        fork tx_record(record("B",1,1,10000,5,0));
             check_report(1,10000,0,0); join
        fork tx_record(record("A",1,2,10003,2,0));
             check_report(2,10000,10003,1); join
        fork tx_record(record("A",1,3,10008,1,16'h0001));
             check_single(8'h45); join
        fork tx_record(record("B",2,4,10001,1,0));
             check_single(8'h49); join
        fork tx_record(record("B",1,5,10006,0,0));
             check_single(8'h49); join
        if(!led[1] || !led[2]) $fatal(1,"LED signal/error not latched");
        $display("PASS tb_board_uart: 2 correct reports, malformed and ignored responses");
        $finish;
    end
    initial begin
        repeat(LIMIT) @(posedge clk);
        $fatal(1,"TIMEOUT tb_board_uart");
    end
endmodule
