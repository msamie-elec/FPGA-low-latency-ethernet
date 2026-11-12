`timescale 1ns/1ps
module tb_mii_reply_rx;
    logic clk=0,rst_n=0,dv=0,err=0,ack=0;
    logic [3:0] rxd=0;
    always #20 clk=~clk;
    wire req,reject;
    wire [111:0] response;
    wire [3:0] len;
    mii_reply_rx dut(.rx_clk(clk),.rst_n(rst_n),
        .eth_rx_dv(dv),.eth_rxerr(err),.eth_rxd(rxd),
        .ack_toggle_async(ack),.req_toggle(req),
        .response(response),.response_len(len),.reject_toggle(reject));
    reg [7:0] report_frame[0:71],ignore_frame[0:71],error_frame[0:71],bad_frame[0:71];
    reg [7:0] b;
    task automatic send(input integer which);
        begin
            for(integer i=0;i<72;i=i+1) begin
                b=which==0?report_frame[i]:(which==1?ignore_frame[i]:(which==2?error_frame[i]:bad_frame[i]));
                @(negedge clk); dv=1; rxd=b[3:0];
                @(negedge clk); rxd=b[7:4];
            end
            @(negedge clk); dv=0;rxd=0;
            repeat(5) @(posedge clk);
        end
    endtask
    initial begin
        $readmemh("tests/generated/m2c_b_report.hex",report_frame);
        $readmemh("tests/generated/m2c_b_ignored.hex",ignore_frame);
        $readmemh("tests/generated/m2c_b_error.hex",error_frame);
        $readmemh("tests/generated/m2c_b_bad_fcs.hex",bad_frame);
        repeat(4) @(negedge clk); rst_n=1;
        send(0);
        if(req!==1 || len!==14 || response[111:104]!==8'h52 ||
           response[103:72]!==32'd1) $fatal(1,"Valid report frame rejected");
        @(negedge clk);ack=req;repeat(4) @(posedge clk);
        send(1);
        if(req!==0 || len!==1 || response[111:104]!==8'h49) $fatal(1,"Ignore frame rejected");
        @(negedge clk);ack=req;repeat(4) @(posedge clk);
        send(2);
        if(req!==1 || len!==1 || response[111:104]!==8'h45) $fatal(1,"Error frame rejected");
        @(negedge clk);ack=req;repeat(4) @(posedge clk);
        send(3);
        if(req!==1 || reject!==1) $fatal(1,"Corrupted FCS not rejected");
        $display("PASS tb_mii_reply_rx: R/I/E accepted and bad FCS rejected");
        $finish;
    end
    initial begin #2000000; $fatal(1,"mii_reply_rx timeout"); end
endmodule
