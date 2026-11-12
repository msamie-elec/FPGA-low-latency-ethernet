`timescale 1ns/1ps
// Lab-link simulation: Board A TX -> Board B RX, B TX -> A RX.
// Both MII interfaces are deliberately idealised: phase, PHY analogue
// behaviour, cable loss and clock tolerance are outside this RTL test.
module tb_m4b_board_pair;
    logic sysclk=0,miiclk=0,btn=1,hostuart=1;
    always #5 sysclk=~sysclk;
    always #20 miiclk=~miiclk;
    wire [3:0] led_a,led_b,atxd,btxd;
    wire atxen,btxen,aref,bref,arstn,brstn,uart_a,uart_b;
    ethernet_generator_a7_m2c #(.PHY_RESET_CYCLES(16),
        .REPLY_TIMEOUT_CYCLES(5000000)) board_a(
        .clk(sysclk),.btn0(btn),.led(led_a),
        .eth_rx_clk(miiclk),.eth_tx_clk(miiclk),
        .eth_rx_dv(btxen),.eth_rxerr(1'b0),.eth_rxd(btxd),
        .eth_ref_clk(aref),.eth_rstn(arstn),
        .eth_tx_en(atxen),.eth_txd(atxd),
        .uart_rx_i(hostuart),.uart_tx_o(uart_a)
    );
    ethernet_udp_a7_buffered #(.PHY_RESET_CYCLES(16)) board_b(
        .clk(sysclk),.btn0(btn),.led(led_b),
        .eth_rx_clk(miiclk),.eth_tx_clk(miiclk),
        .eth_rx_dv(atxen),.eth_rxerr(1'b0),.eth_rxd(atxd),
        .eth_ref_clk(bref),.eth_rstn(brstn),
        .eth_tx_en(btxen),.eth_txd(btxd),.uart_tx_o(uart_b)
    );
    wire [7:0] tel_byte;
    wire tel_valid,tel_err;
    uart_rx #(.CLOCK_HZ(100000000),.BAUD(115200)) telemetry_parser(
        .clk(sysclk),.rst_n(!btn),.rx_pin(uart_a),
        .data(tel_byte),.valid(tel_valid),.framing_error(tel_err)
    );
    reg [7:0] captured[0:23];
    integer count=0;
    always @(posedge sysclk) begin
        if(btn) count<=0;
        else if(tel_valid) begin
            if(count>=24) $fatal(1,"Unexpected telemetry after frame");
            captured[count]<=tel_byte;
            count<=count+1;
        end
        if(tel_err) $fatal(1,"UART framing error on Board A telemetry");
    end
    task automatic send_host_byte(input [7:0] ch);
        begin
            hostuart=0; #8680;
            for(integer k=0;k<8;k=k+1) begin
                hostuart=ch[k];#8680;
            end
            hostuart=1;#8680;
        end
    endtask
    // One early Ethernet reply for each requested packet.
    integer ethernet_first_replies=0;
    reg prev_b_txen=0;
    always @(posedge miiclk) begin
        prev_b_txen <= btxen;
        if (btxen && !prev_b_txen) begin
            // Ethernet TX must start while UART diagnostics are still active.
            if (board_b.uart_state == board_b.UART_IDLE &&
                board_b.debug_uart_drops == 0 && ethernet_first_replies == 0)
                $fatal(1,"Unexpected idle UART at first Ethernet response");
            ethernet_first_replies = ethernet_first_replies + 1;
        end
    end
    task automatic do_request(input [7:0] command,input integer seq,input [7:0] expected_code);
        reg [31:0] seen_seq;
        reg [31:0] rtt;
        begin
            @(negedge sysclk);count=0;
            send_host_byte(command);
            wait(count==24);
            @(negedge sysclk);
            seen_seq={captured[1],captured[2],captured[3],captured[4]};
            rtt={captured[20],captured[21],captured[22],captured[23]};
            if(captured[0]!==8'h4d || captured[5]!==8'h50 ||
               captured[6]!==expected_code || seen_seq!==seq || rtt==0)
                $fatal(1,"Telemetry mismatch cmd=%h code=%h seq=%d status=%h RTT=%d",
                       command,captured[6],seen_seq,captured[5],rtt);
            // v0.6 physical valid-report RTT was ~122,800 cycles, dominated
            // by UART. In the idealised RTL link, a parallel response should
            // complete well before 250us (25,000 cycles) for every type.
            if (rtt >= 32'd25000)
                $fatal(1,"M4B latency regression: RTT %0d cycles exceeds 25000", rtt);
            if(expected_code==8'h52 &&
               {captured[7],captured[8],captured[9],captured[10]}!==seq)
                $fatal(1,"Report sequence not returned: %d",seq);
            $display("PASS board-pair cmd=%c seq=%d code=%c RTT100MHz=%d",command,seq,expected_code,rtt);
            repeat(30) @(posedge sysclk);
        end
    endtask
    initial begin
        repeat(20) @(posedge sysclk);
        @(negedge sysclk);btn=0;
        repeat(200) @(posedge sysclk);
        do_request(8'h53,1,8'h52);
        do_request(8'h49,2,8'h49);
        do_request(8'h45,3,8'h45);
        do_request(8'h53,4,8'h52);
        if (ethernet_first_replies != 4)
            $fatal(1,"Expected 4 Ethernet-first replies, got %0d", ethernet_first_replies);
        $display("PASS tb_m4b_board_pair: 4 validated A/B exchanges, each <250us RTL RTT and Ethernet before B UART completion");
        $finish;
    end
    initial begin #30000000; $fatal(1,"M3 board-pair timeout");end
endmodule
