`timescale 1ns/1ps
// FIFO wrap, clock-phase difference, read backpressure, full and empty.
module tb_m4b_async_fifo;
    logic wc=0,rc=0,wrst=0,rrst=0;
    always #7 wc=~wc;
    initial begin #3; forever #11 rc=~rc; end
    logic wvalid=0, rready=0;
    logic [15:0] wdata=0;
    wire wready,full,rvalid,empty;
    wire [15:0] rdata;
    m4b_async_fifo #(.WIDTH(16),.DEPTH(8)) dut (
        .wr_clk(wc),.wr_rst_n(wrst),.wr_valid(wvalid),
        .wr_data(wdata),.wr_ready(wready),.wr_full(full),
        .rd_clk(rc),.rd_rst_n(rrst),.rd_valid(rvalid),
        .rd_data(rdata),.rd_ready(rready),.rd_empty(empty)
    );
    integer sent=0,got=0;
    integer saw_full=0,saw_empty=0,rd_cycle=0;
    always @(posedge wc) if(wrst && wvalid && wready) sent<=sent+1;
    always @(negedge wc) begin
        wvalid=(wrst && sent<64);
        wdata=sent[15:0];
        if(full) saw_full=1;
    end
    always @(negedge rc) begin
        // Stall the reader during the initial fill and intermittently.
        rd_cycle=rd_cycle+1;
        rready=rrst && (sent>=8) && ((rd_cycle%11)<6);
        if (empty) saw_empty=1;
    end
    always @(posedge rc) if(rrst && rvalid && rready) begin
        if(rdata !== got[15:0]) $fatal(1,"FIFO sequence error: got=%d expected=%d",rdata,got);
        got<=got+1;
    end
    initial begin
        repeat(4) @(posedge wc);
        @(negedge wc);wrst=1;rrst=1;
        wait(got==64);
        repeat(8) @(posedge wc);
        if(sent!=64 || saw_full==0 || saw_empty==0)
            $fatal(1,"FIFO boundary coverage incomplete: sent=%d got=%d full=%d empty=%d",sent,got,saw_full,saw_empty);
        // Reset after traffic and ensure pointer state returns to empty.
        wrst=0;rrst=0;
        repeat(7) @(posedge wc);
        if(!empty || full) $fatal(1,"Reset did not clear FIFO pointers");
        $display("PASS tb_m4b_async_fifo: 64 ordered words, wrap/full/empty/phase/backpressure and reset");
        $finish;
    end
    initial begin #200000; $fatal(1,"Async FIFO timeout sent=%d got=%d",sent,got);end
endmodule
