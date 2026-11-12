`timescale 1ns/1ps
// PHY-valid packets under processing backpressure: 4 FIFO slots, 8 inputs.
// Valid frames beyond capacity must drop AND increment the overflow counter.
// Later reads preserve order; the FIFO must work again across pointer wrap.
module tb_m4b_rx_overflow;
    logic rc=0,sc=0,rrst=0,srst=0;
    always #20 rc=~rc;
    always #5 sc=~sc;
    logic dv=0,err=0;
    logic [3:0] rxd=0;
    wire frame_valid;
    wire [127:0] frame_data;
    wire [15:0] drops,invalid,drops_gray,invalid_gray;
    wire full,valid,empty;
    wire [127:0] fifo_data;
    logic ready=0;
    reg [7:0] frames[0:22*72-1];
    reg [7:0] bad[0:71];
    mii_udp_rx_m4b rx (
        .rx_clk(rc),.rst_n(rrst),.eth_rx_dv(dv),
        .eth_rxerr(err),.eth_rxd(rxd),.fifo_full(full),
        .frame_valid(frame_valid),.frame_data(frame_data),
        .overflow_count(drops),.invalid_frame_count(invalid),
        .overflow_gray(drops_gray),.invalid_frame_gray(invalid_gray)
    );
    m4b_async_fifo #(.WIDTH(128),.DEPTH(4)) fifo (
        .wr_clk(rc),.wr_rst_n(rrst),.wr_valid(frame_valid),
        .wr_data(frame_data),.wr_ready(),.wr_full(full),
        .rd_clk(sc),.rd_rst_n(srst),.rd_valid(valid),
        .rd_data(fifo_data),.rd_ready(ready),.rd_empty(empty)
    );
    task automatic send_frame(input integer ix);
        reg [7:0] b;
        begin
            for(integer j=0;j<72;j=j+1) begin
                b=frames[ix*72+j];
                @(negedge rc);dv=1;rxd=b[3:0];
                @(negedge rc);rxd=b[7:4];
            end
            @(negedge rc);dv=0;rxd=0;
            repeat(24) @(negedge rc);
        end
    endtask
    task automatic send_bad;
        reg [7:0] b;
        begin
            for(integer j=0;j<72;j=j+1) begin
                b=bad[j];
                @(negedge rc);dv=1;rxd=b[3:0];
                @(negedge rc);rxd=b[7:4];
            end
            @(negedge rc);dv=0;rxd=0;
            repeat(24) @(negedge rc);
        end
    endtask
    integer got=0,expected_seq=1;
    always @(posedge sc) if(srst && valid && ready) begin
        if(fifo_data[111:80] !== expected_seq)
            $fatal(1,"RX input FIFO order error: got %0d expected %0d",fifo_data[111:80],expected_seq);
        got<=got+1;
        expected_seq<=expected_seq+1;
    end
    initial begin
        $readmemh("tests/generated/m4b_22_frames.hex",frames);
        $readmemh("tests/generated/m4b_bad_fcs.hex",bad);
        repeat(5) @(posedge sc);
        @(negedge sc);rrst=1;srst=1;
        for(integer i=0;i<8;i=i+1) send_frame(i);
        repeat(5) @(posedge rc);
        if(drops!==4 || !full || invalid!==0)
            $fatal(1,"Full FIFO must count exactly 4 dropped frames: drops=%d full=%b bad=%d",drops,full,invalid);
        @(negedge sc);ready=1;
        wait(got==4);
        @(negedge sc);ready=0;
        repeat(10) @(posedge rc);
        if(!empty) $fatal(1,"RX FIFO did not drain");
        // Re-fill after pointer wrap with sequences 9..12 (indices 8..11).
        @(negedge sc);expected_seq=9;
        for(integer i=8;i<12;i=i+1) send_frame(i);
        repeat(5) @(posedge rc);
        if(full!==1 || drops!==4) $fatal(1,"RX FIFO wrap/refill failed");
        @(negedge sc);ready=1;
        wait(got==8);
        @(negedge sc);ready=0;
        send_bad();
        repeat(5) @(posedge rc);
        if(invalid!==1 || drops!==4 || got!==8)
            $fatal(1,"Malformed FCS or overflow count incorrect bad=%d drops=%d got=%d",invalid,drops,got);
        $display("PASS tb_m4b_rx_overflow: 4 accepted + 4 counted drops, FIFO wrap, 4 reaccepted, bad CRC rejected");
        $finish;
    end
    initial begin #2000000; $fatal(1,"RX overflow test timeout got=%d drops=%d",got,drops);end
endmodule
