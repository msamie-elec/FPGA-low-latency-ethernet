// SPDX-License-Identifier: MIT
`timescale 1ns/1ps
module tb_feed_pipeline;
    logic clk = 1'b0;
    always #5 clk = ~clk; // Simulation clock only; 100 MHz.
    logic rst_n = 1'b0;
    logic [7:0] s_data = 8'd0;
    logic s_valid = 1'b0, s_last = 1'b0;
    wire s_ready, parse_error, report_valid;
    logic report_ready = 1'b1;
    wire [31:0] report_seq, report_bid, report_ask;
    wire report_signal;
    integer reports = 0, errors = 0;
    integer cycle = 0;
    logic prior_stall = 0;
    logic [96:0] prior_report;

    feed_pipeline dut(
        .clk(clk), .rst_n(rst_n), .s_data(s_data), .s_valid(s_valid),
        .s_ready(s_ready), .s_last(s_last), .parse_error(parse_error),
        .report_valid(report_valid), .report_ready(report_ready),
        .report_seq(report_seq), .report_bid(report_bid),
        .report_ask(report_ask), .report_signal(report_signal)
    );

    function automatic [127:0] record(input byte side, input byte symbol,
                                     input logic [31:0] seq,
                                     input logic [31:0] price,
                                     input logic [31:0] qty,
                                     input logic [15:0] reserved);
        record = {side, symbol, seq, price, qty, reserved};
    endfunction

    // Allows deliberately short (8-byte) and long (17-byte) frames.
    task automatic send_packet(input logic [127:0] payload, input integer nbytes);
        logic [7:0] octet;
        integer j;
        begin
            for (j = 0; j < nbytes; j = j + 1) begin
                if (j < 16) octet = (payload >> ((15-j)*8));
                else octet = 8'hEE;
                @(negedge clk);
                s_data = octet;
                s_valid = 1'b1;
                s_last = (j == nbytes-1);
                @(posedge clk);
                while (!s_ready) @(posedge clk);
            end
            @(negedge clk);
            s_valid = 1'b0;
            s_last = 1'b0;
        end
    endtask

    task automatic check_report(input integer n, input integer seq,
                                input integer bid, input integer ask,
                                input integer sig);
        begin
            if (report_seq !== seq || report_bid !== bid ||
                report_ask !== ask || report_signal !== sig)
                $fatal(1, "Report #%0d mismatch: got (%0d,%0d,%0d,%0d); expected (%0d,%0d,%0d,%0d)",
                    n, report_seq, report_bid, report_ask, report_signal,
                    seq, bid, ask, sig);
        end
    endtask

    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            if (parse_error) errors <= errors + 1;
            if (prior_stall) begin
                if (!report_valid || {report_seq,report_bid,report_ask,report_signal} !== prior_report)
                    $fatal(1, "Report output changed during backpressure");
            end
            prior_stall <= report_valid && !report_ready;
            prior_report <= {report_seq,report_bid,report_ask,report_signal};
            if (report_valid && report_ready) begin
                case (reports)
                    0: check_report(reports,1,10000,0,0);
                    1: check_report(reports,2,10000,10003,1);
                    2: check_report(reports,3,10000,10020,0);
                    3: check_report(reports,6,10016,10020,1);
                    4: check_report(reports,7,10022,10020,0);
                    5: check_report(reports,8,10010,10020,0);
                    6: check_report(reports,9,10010,10011,1);
                    default: $fatal(1, "Unexpected extra report");
                endcase
                reports <= reports + 1;
            end
        end
    end

    initial begin
        repeat (5) @(negedge clk);
        rst_n = 1'b1;
        // Hold a report downstream to prove that upstream events do not overwrite it.
        report_ready = 1'b0;
        send_packet(record("B",8'd1,1,10000,5,0),16);
        fork
            begin
                send_packet(record("A",8'd1,2,10003,8,0),16);
                send_packet(record("A",8'd1,3,10020,7,0),16);
            end
            begin
                repeat (110) @(negedge clk);
                report_ready = 1'b1;
            end
        join
        send_packet(record("B",8'd2,4,10018,7,0),16); // wrong symbol
        send_packet(record("A",8'd1,5,10019,0,0),16); // qty zero
        send_packet(record("B",8'd1,6,10016,1,0),16);
        send_packet(record("B",8'd1,7,10022,1,0),16);
        send_packet(record("B",8'd1,8,10010,1,0),16);
        send_packet(record("A",8'd1,9,10011,1,0),16);
        send_packet(record("A",8'd1,10,10000,1,16'h0100),16); // bad reserved
        send_packet(record("B",8'd1,11,10000,1,0),8); // truncated
        send_packet(record("B",8'd1,12,10000,1,0),17); // overlong
        repeat (12) @(negedge clk);
        if (reports !== 7 || errors !== 3)
            $fatal(1,"FAIL reports=%0d (wanted 7), errors=%0d (wanted 3)", reports, errors);
        $display("PASS: 7 reports, 3 rejected frames, backpressure hold checked");
        $finish;
    end
    initial begin
        repeat (5000) @(posedge clk);
        $fatal(1,"TIMEOUT: testbench did not complete");
    end
endmodule
