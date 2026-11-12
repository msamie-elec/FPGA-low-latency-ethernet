`timescale 1ns/1ps
module tb_mii_udp_rx;
    logic rx_clk=0;
    always #20 rx_clk=~rx_clk;
    logic rst_n=0,eth_rx_dv=0,eth_rxerr=0;
    logic [3:0] eth_rxd=0;
    logic ack_toggle=0;
    wire req_toggle,good_toggle,reject_toggle;
    wire [127:0] payload;
    mii_udp_rx dut(.rx_clk(rx_clk),.rst_n(rst_n),.eth_rx_dv(eth_rx_dv),
        .eth_rxerr(eth_rxerr),.eth_rxd(eth_rxd),.ack_toggle_async(ack_toggle),
        .req_toggle(req_toggle),.payload(payload),.good_toggle(good_toggle),
        .reject_toggle(reject_toggle));
    reg [7:0] bid[0:71], bad_fcs[0:71], bad_port[0:71];
    integer i;
    task automatic send_bid;
        begin
            for (integer j=0;j<72;j=j+1) begin
                @(negedge rx_clk); eth_rx_dv=1;eth_rxd=bid[j][3:0];
                @(negedge rx_clk); eth_rxd=bid[j][7:4];
            end
            @(negedge rx_clk); eth_rx_dv=0;eth_rxd=0;
            repeat(8) @(posedge rx_clk);
        end
    endtask
    task automatic send_bad_fcs;
        begin
            for (integer j=0;j<72;j=j+1) begin
                @(negedge rx_clk); eth_rx_dv=1;eth_rxd=bad_fcs[j][3:0];
                @(negedge rx_clk); eth_rxd=bad_fcs[j][7:4];
            end
            @(negedge rx_clk);eth_rx_dv=0;eth_rxd=0;
            repeat(8) @(posedge rx_clk);
        end
    endtask
    task automatic send_bad_port;
        begin
            for (integer j=0;j<72;j=j+1) begin
                @(negedge rx_clk); eth_rx_dv=1;eth_rxd=bad_port[j][3:0];
                @(negedge rx_clk); eth_rxd=bad_port[j][7:4];
            end
            @(negedge rx_clk);eth_rx_dv=0;eth_rxd=0;
            repeat(8) @(posedge rx_clk);
        end
    endtask
    initial begin
        $readmemh("tests/generated/mii_bid.hex",bid);
        $readmemh("tests/generated/mii_bad_fcs.hex",bad_fcs);
        $readmemh("tests/generated/mii_wrong_port.hex",bad_port);
        repeat (5) @(negedge rx_clk);rst_n=1;
        repeat (4) @(posedge rx_clk);
        send_bid();
        if (req_toggle!==1 || good_toggle!==1 || payload!==128'h42010000000100002710000000050000)
            $fatal(1,"good MII UDP frame not accepted req=%b good=%b payload=%h",req_toggle,good_toggle,payload);
        ack_toggle=1;
        repeat (5) @(posedge rx_clk);
        send_bad_fcs();
        if (req_toggle!==1 || reject_toggle!==1)
            $fatal(1,"bad FCS should reject");
        send_bad_port();
        if (req_toggle!==1 || reject_toggle!==0)
            $fatal(1,"nonmatching UDP port should reject");
        $display("PASS tb_mii_udp_rx: valid UDP accepted; bad FCS and port rejected");
        $finish;
    end
endmodule
