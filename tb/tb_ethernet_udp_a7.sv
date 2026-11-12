`timescale 1ns/1ps
module tb_ethernet_udp_a7;
    logic clk=0, eth_rx_clk=0,eth_tx_clk=0,btn0=1;
    always #5 clk=~clk;
    always #20 eth_rx_clk=~eth_rx_clk;
    initial begin #13; forever #20 eth_tx_clk=~eth_tx_clk; end
    logic eth_rx_dv=0,eth_rxerr=0;
    logic [3:0] eth_rxd=0;
    wire [3:0] led,eth_txd;
    wire eth_ref_clk,eth_rstn,eth_tx_en,uart_tx_o;
    ethernet_udp_a7 #(.UART_BAUD(1000000),.PHY_RESET_CYCLES(32)) dut (
        .clk(clk),.btn0(btn0),.led(led),
        .eth_rx_clk(eth_rx_clk),.eth_tx_clk(eth_tx_clk),.eth_rx_dv(eth_rx_dv),
        .eth_rxerr(eth_rxerr),.eth_rxd(eth_rxd),
        .eth_ref_clk(eth_ref_clk),.eth_rstn(eth_rstn),
        .eth_tx_en(eth_tx_en),.eth_txd(eth_txd),.uart_tx_o(uart_tx_o));
    reg [7:0] bid[0:71], ask[0:71], bad_fcs[0:71];
    reg [7:0] expected[0:27];
    reg [7:0] golden_tx1[0:71], golden_tx2[0:71];
    integer i, k;
    task automatic send_frame(input integer which);
        reg [7:0] b;
        begin
            for(integer j=0;j<72;j=j+1) begin
                b=which==0 ? bid[j] : (which==1 ? ask[j] : bad_fcs[j]);
                @(negedge eth_rx_clk);eth_rx_dv=1;eth_rxd=b[3:0];
                @(negedge eth_rx_clk);eth_rxd=b[7:4];
            end
            @(negedge eth_rx_clk);eth_rx_dv=0;eth_rxd=0;
        end
    endtask
    task automatic get_uart_byte(output reg [7:0] b);
        begin
            @(negedge uart_tx_o);
            #1500; // middle of first data bit at 1 Mbaud, 1.5 us after start edge
            for(integer j=0;j<8;j=j+1) begin
                b[j]=uart_tx_o;
                #1000;
            end
            if (uart_tx_o!==1'b1) $fatal(1,"UART missing stop bit");
        end
    endtask
    reg [7:0] observed;
    initial begin
        $readmemh("tests/generated/mii_bid.hex",bid);
        $readmemh("tests/generated/mii_ask.hex",ask);
        $readmemh("tests/generated/mii_bad_fcs.hex",bad_fcs);
        $readmemh("tests/generated/mii_tx_report.hex",golden_tx1);
        // second packet's report needs its own golden fixture (seq=2).
        $readmemh("tests/generated/mii_tx_report2.hex",golden_tx2);
        // Report 1: 'R' seq=1 bid=10000 ask=0 signal=0
        expected[0]=8'h52;
        expected[1]=0;expected[2]=0;expected[3]=0;expected[4]=1;
        expected[5]=0;expected[6]=0;expected[7]=8'h27;expected[8]=8'h10;
        expected[9]=0;expected[10]=0;expected[11]=0;expected[12]=0;
        expected[13]=0;
        // Report 2: seq=2 bid=10000 ask=10003 signal=1
        expected[14]=8'h52;
        expected[15]=0;expected[16]=0;expected[17]=0;expected[18]=2;
        expected[19]=0;expected[20]=0;expected[21]=8'h27;expected[22]=8'h10;
        expected[23]=0;expected[24]=0;expected[25]=8'h27;expected[26]=8'h13;
        expected[27]=1;
        repeat (6) @(negedge clk);btn0=0;
        wait (eth_rstn);
        repeat(12) @(posedge eth_rx_clk);
        fork
            begin
                // Exercise the diagnostic CDC: a rejected frame must
                // set the sticky error LED after synchronisation.
                send_frame(2);
                wait(led[2]===1'b1);
                repeat(16) @(posedge eth_rx_clk);
                send_frame(0);
                wait(led[3]===1'b1);
                repeat(16) @(posedge eth_rx_clk);
                send_frame(1);
            end
            begin
                for(k=0;k<28;k=k+1) begin
                    get_uart_byte(observed);
                    if (observed!==expected[k])
                        $fatal(1,"UART byte %0d expected %02x got %02x",k,expected[k],observed);
                end
                // UART finished. The Ethernet TX scoreboard below validates both
                // outgoing responses before the overall test can complete.
            end
            begin: CHECK_ETH_TX
                reg [7:0] expected_tx_byte;
                for (integer packet=0; packet<2; packet=packet+1) begin
                    wait (eth_tx_en===1'b1);
                    for (integer z=0;z<72;z=z+1) begin
                        expected_tx_byte=packet==0? golden_tx1[z] : golden_tx2[z];
                        @(posedge eth_tx_clk);
                        if (eth_tx_en!==1'b1 || eth_txd!==expected_tx_byte[3:0])
                            $fatal(1,"M2B TX packet=%0d low byte=%0d",packet,z);
                        @(posedge eth_tx_clk);
                        if (eth_tx_en!==1'b1 || eth_txd!==expected_tx_byte[7:4])
                            $fatal(1,"M2B TX packet=%0d high byte=%0d",packet,z);
                    end
                    @(posedge eth_tx_clk);
                    if (eth_tx_en!==1'b0) $fatal(1,"TX_EN held beyond FCS");
                    // Wait for transmitter ack; it guarantees IFG completed.
                    wait (dut.tx_ack_toggle == (packet==0 ? 1'b1 : 1'b0));
                    repeat (5) @(posedge eth_tx_clk);
                end
            end
        join
        $display("PASS tb_ethernet_udp_a7: rejected FCS LED, 2 UART reports + 2 correct Ethernet UDP replies");
        $finish;
    end
    initial begin #4000000; $fatal(1,"Timeout in bidirectional integration"); end
endmodule
