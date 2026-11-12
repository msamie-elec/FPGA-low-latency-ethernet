`timescale 1ns/1ps
module tb_mii_feed_tx;
    logic clk=0,rst_n=0,req=0;
    always #20 clk=~clk;
    logic [127:0] data=0;
    wire ack,txen;
    wire [3:0] txd;
    mii_feed_tx dut(.tx_clk(clk),.rst_n(rst_n),.req_toggle_async(req),
        .feed_data(data),.ack_toggle(ack),.eth_tx_en(txen),.eth_txd(txd));
    reg [7:0] expected0[0:71],expected1[0:71],expected2[0:71];
    reg [7:0] b;
    task automatic verify(input integer id);
        begin
            wait (txen === 1'b1);
            for(integer i=0;i<72;i=i+1) begin
                b=id==0?expected0[i]:(id==1?expected1[i]:expected2[i]);
                @(posedge clk);
                if(txen!==1 || txd!==b[3:0])
                    $fatal(1,"feed TX byte %0d low expected %h got %h",i,b[3:0],txd);
                @(posedge clk);
                if(txen!==1 || txd!==b[7:4])
                    $fatal(1,"feed TX byte %0d high expected %h got %h",i,b[7:4],txd);
            end
            @(posedge clk);
            if(txen!==0) $fatal(1,"TX EN did not drop after FCS");
            wait(ack==req);
            repeat (4) @(posedge clk);
        end
    endtask
    initial begin
        $readmemh("tests/generated/m2c_a_standard.hex",expected0);
        $readmemh("tests/generated/m2c_a_ignored.hex",expected1);
        $readmemh("tests/generated/m2c_a_error.hex",expected2);
        repeat(4) @(negedge clk);rst_n=1;
        repeat(4) @(negedge clk);
        data={8'h42,8'h01,32'd1,32'd10001,32'd1,16'd0};req=1;
        verify(0);
        @(negedge clk);
        data={8'h41,8'h02,32'd2,32'd10002,32'd1,16'd0};req=0;
        verify(1);
        @(negedge clk);
        data={8'h58,8'h01,32'd3,32'd10003,32'd1,16'd0};req=1;
        verify(2);
        $display("PASS tb_mii_feed_tx: 3 independent Python frames including CRC/IP/UDP");
        $finish;
    end
    initial begin #2000000; $fatal(1,"mii_feed_tx timeout"); end
endmodule
