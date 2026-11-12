`timescale 1ns/1ps
module tb_m4b_sync_fifo;
    logic clk=0,rst=0,valid=0,ready=0;
    logic [15:0] in_data=0;
    wire in_ready,out_valid,full,empty;
    wire [15:0] out_data;
    m4b_sync_fifo #(.WIDTH(16),.DEPTH(4)) dut (
        .clk(clk),.rst_n(rst),.in_valid(valid),.in_data(in_data),
        .in_ready(in_ready),.out_valid(out_valid),.out_data(out_data),
        .out_ready(ready),.full(full),.empty(empty)
    );
    always #5 clk=~clk;
    task automatic push(input [15:0] v);
        begin
            @(negedge clk);valid=1;in_data=v;ready=0;
            @(posedge clk);if(!in_ready) $fatal(1,"Unexpected FIFO full");
            @(negedge clk);valid=0;
        end
    endtask
    task automatic pop(input [15:0] expected);
        begin
            @(negedge clk);ready=1;
            if(!out_valid || out_data !== expected) $fatal(1,"FIFO order: expected %d got %d",expected,out_data);
            @(posedge clk);
            @(negedge clk);ready=0;
        end
    endtask
    initial begin
        repeat(3) @(posedge clk);
        @(negedge clk);rst=1;
        push(1);push(2);push(3);push(4);
        if(!full || empty) $fatal(1,"Failed full-boundary check");
        // Full can accept simultaneous pop/push; oldest value is popped.
        @(negedge clk);valid=1;in_data=5;ready=1;
        // Combinational ready/pop must settle after the same-timestep stimulus.
        // Without a delta-cycle wait, this assertion can read stale in_ready=0.
        #1;
        if(!in_ready || !out_valid || out_data!==16'd1)
            $fatal(1,"Simultaneous full pop/push unsupported");
        @(posedge clk);
        @(negedge clk);valid=0;ready=0;
        pop(2);pop(3);pop(4);pop(5);
        if(!empty || full) $fatal(1,"Empty boundary check failed");
        $display("PASS tb_m4b_sync_fifo: full-depth, FIFO ordering, simultaneous full pop/push");
        $finish;
    end
    initial begin #20000; $fatal(1,"Synchronous FIFO TB timeout");end
endmodule
