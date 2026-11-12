`timescale 1ns/1ps
module tb_mii_udp_tx;
    logic tx_clk=0, rst_n=0, req_toggle_async=0;
    always #20 tx_clk=~tx_clk;
    logic [111:0] response_data=0;
    logic [3:0] response_len=0;
    wire ack_toggle,eth_tx_en;
    wire [3:0] eth_txd;
    mii_udp_tx dut(
        .tx_clk(tx_clk),.rst_n(rst_n),.req_toggle_async(req_toggle_async),
        .response_data(response_data),.response_len(response_len),
        .ack_toggle(ack_toggle),.eth_tx_en(eth_tx_en),.eth_txd(eth_txd)
    );
    reg [7:0] report_frame[0:71];
    reg [7:0] ignore_frame[0:71];
    reg [7:0] error_frame[0:71];
    reg [7:0] b;
    integer idx;

    task automatic verify_frame(input integer which);
        begin
            // Each output nibble is launched on negedge and observed on posedge.
            wait (eth_tx_en === 1'b1);
            for (integer i=0;i<72;i=i+1) begin
                b=which==0 ? report_frame[i] : (which==1 ? ignore_frame[i] : error_frame[i]);
                @(posedge tx_clk);
                if (eth_tx_en!==1'b1 || eth_txd!==b[3:0])
                    $fatal(1,"TX low nibble %0d expected %h got %h en=%b",i,b[3:0],eth_txd,eth_tx_en);
                @(posedge tx_clk);
                if (eth_tx_en!==1'b1 || eth_txd!==b[7:4])
                    $fatal(1,"TX high nibble %0d expected %h got %h en=%b",i,b[7:4],eth_txd,eth_tx_en);
            end
            @(posedge tx_clk);
            if (eth_tx_en!==1'b0) $fatal(1,"TX_EN not deasserted after FCS");
            wait (ack_toggle==req_toggle_async);
            // IFG is enforced before acknowledgement; no further packet.
            repeat(5) @(posedge tx_clk);
        end
    endtask
    initial begin
        $readmemh("tests/generated/mii_tx_report.hex",report_frame);
        $readmemh("tests/generated/mii_tx_ignored.hex",ignore_frame);
        $readmemh("tests/generated/mii_tx_error.hex",error_frame);
        repeat (4) @(negedge tx_clk); rst_n=1;
        repeat (4) @(negedge tx_clk);
        response_data={8'h52,32'd1,32'd10000,32'd0,7'b0,1'b0};
        response_len=14;
        req_toggle_async=1;
        verify_frame(0);
        @(negedge tx_clk);
        response_data={8'h49,104'b0};
        response_len=1;
        req_toggle_async=0;
        verify_frame(1);
        @(negedge tx_clk);
        response_data={8'h45,104'b0};
        response_len=1;
        req_toggle_async=1;
        verify_frame(2);
        // An unsupported mailbox length must NOT produce an Ethernet
        // frame, and MUST still be acknowledged so the sender can recover.
        @(negedge tx_clk);
        response_data={8'h58,104'b0};
        response_len=2;
        req_toggle_async=0;
        for (integer n=0;n<12;n=n+1) begin
            @(posedge tx_clk);
            if (eth_tx_en !== 1'b0)
                $fatal(1,"Invalid-length mailbox request generated TX_EN");
        end
        if (ack_toggle !== req_toggle_async)
            $fatal(1,"Invalid-length mailbox request not acknowledged");
        $display("PASS tb_mii_udp_tx: report, ignored, error frames and invalid-length handling, preamble/IP/UDP/padding/FCS/IFG");
        $finish;
    end
    initial begin #2000000; $fatal(1,"Timeout in MII UDP TX test"); end
endmodule
