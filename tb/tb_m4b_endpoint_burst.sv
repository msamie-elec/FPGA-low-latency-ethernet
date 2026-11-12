`timescale 1ns/1ps
// Idealised 100-Mbps MII: 22 minimum frames, 12-byte IFG, no UART pacing.
// Assertions cover exact reply ordering, valid MII FCS/IP/UDP, RX overflow,
// malformed FCS rejection, and intentional independent UART diagnostic drops.
module tb_m4b_endpoint_burst;
    logic clk=0,rxclk=0,txclk=0,btn=1;
    always #5 clk=~clk;
    always #20 rxclk=~rxclk;
    initial begin #13; forever #20 txclk=~txclk; end
    logic rx_dv=0,rx_err=0;
    logic [3:0] rxd=0;
    wire [3:0] led,txd;
    wire refclk,rstn,tx_en,uart_out;
    ethernet_udp_a7_buffered #(
        .UART_BAUD(115200),.PHY_RESET_CYCLES(32),
        .RX_DEPTH(16),.TX_DEPTH(16),.UART_DEPTH(8)
    ) dut (
        .clk(clk),.btn0(btn),.led(led),
        .eth_rx_clk(rxclk),.eth_tx_clk(txclk),
        .eth_rx_dv(rx_dv),.eth_rxerr(rx_err),.eth_rxd(rxd),
        .eth_ref_clk(refclk),.eth_rstn(rstn),
        .eth_tx_en(tx_en),.eth_txd(txd),.uart_tx_o(uart_out)
    );
    reg [7:0] stimuli [0:22*72-1];
    reg [7:0] bad_frame [0:71];
    wire reply_req;
    wire [111:0] reply_bytes;
    wire [3:0] reply_len;
    wire reply_reject;
    logic reply_ack=0;
    mii_reply_rx monitor (
        .rx_clk(txclk),.rst_n(rstn),
        .eth_rx_dv(tx_en),.eth_rxerr(1'b0),.eth_rxd(txd),
        .ack_toggle_async(reply_ack),.req_toggle(reply_req),
        .response(reply_bytes),.response_len(reply_len),
        .reject_toggle(reply_reject)
    );
    integer seen=0;
    always @(posedge txclk) begin
        if (!rstn) begin reply_ack<=0; seen<=0; end
        else if (reply_req != reply_ack) begin
            if (seen < 20) begin
                if (reply_len!==4'd14 || reply_bytes[111:104]!==8'h52)
                    $fatal(1,"Report type/length wrong at %0d",seen);
                if (reply_bytes[103:72] !== (seen + 1))
                    $fatal(1,"Reply out of order: got %0d expected %0d",reply_bytes[103:72],seen+1);
            end else if (seen==20) begin
                if (reply_len!==1 || reply_bytes[111:104]!==8'h49)
                    $fatal(1,"Ignored response invalid");
            end else if (seen==21) begin
                if (reply_len!==1 || reply_bytes[111:104]!==8'h45)
                    $fatal(1,"Error response invalid");
            end else $fatal(1,"Extra Ethernet reply");
            seen<=seen+1;
            reply_ack<=reply_req;
        end
        if (rstn && reply_reject !== 0) $fatal(1,"Reply FCS or headers rejected");
    end
    task automatic send_frame(input integer idx);
        reg [7:0] d;
        begin
            for(integer j=0;j<72;j=j+1) begin
                d=stimuli[idx*72+j];
                @(negedge rxclk); rx_dv=1; rxd=d[3:0];
                @(negedge rxclk); rxd=d[7:4];
            end
            @(negedge rxclk);rx_dv=0;rxd=0;
            // 24 more nibble clocks, so >=96 bit-time Ethernet IFG.
            repeat(24) @(negedge rxclk);
        end
    endtask
    task automatic send_bad;
        reg [7:0] d;
        begin
            for(integer j=0;j<72;j=j+1) begin
                d=bad_frame[j];
                @(negedge rxclk);rx_dv=1;rxd=d[3:0];
                @(negedge rxclk);rxd=d[7:4];
            end
            @(negedge rxclk);rx_dv=0;rxd=0;
            repeat(24) @(negedge rxclk);
        end
    endtask
    initial begin
        $readmemh("tests/generated/m4b_22_frames.hex",stimuli);
        $readmemh("tests/generated/m4b_bad_fcs.hex",bad_frame);
        repeat(20) @(posedge clk);
        @(negedge clk);btn=0;
        wait(rstn);
        repeat(40) @(posedge clk);
        // No host-scheduled gaps: 22 frames arrive consecutively at MII speed.
        for(integer i=0;i<22;i=i+1) send_frame(i);
        wait(seen==22);
        repeat(200) @(posedge clk);
        if (dut.debug_rx_overflows!==0)
            $fatal(1,"Unexpected RX FIFO overflow: %0d",dut.debug_rx_overflows);
        if (dut.debug_uart_drops==0)
            $fatal(1,"UART diagnostic queue did not overflow under sustained burst");
        if (dut.debug_tx_frames!=22)
            $fatal(1,"Missing TX-frame count: %0d",dut.debug_tx_frames);
        send_bad();
        repeat(60) @(posedge clk);
        if(dut.debug_rx_invalid_frames==0 || seen!=22)
            $fatal(1,"Malformed-FCS frame was accepted or not counted");
        $display("PASS tb_m4b_endpoint_burst: 22 ordered Ethernet UDP/FCS replies from back-to-back frames");
        $display("PASS RX drops=%0d; UART diagnostic drops=%0d; malformed CRC rejected=%0d",
                 dut.debug_rx_overflows,dut.debug_uart_drops,dut.debug_rx_invalid_frames);
        $finish;
    end
    initial begin #1500000; $fatal(1,"M4B burst test timeout: saw %0d replies",seen); end
endmodule
