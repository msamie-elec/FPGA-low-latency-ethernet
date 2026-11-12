`timescale 1ns/1ps
// M4C Board A hardware-paced burst generator -> M4B buffered Board B.
// Simulated ideal MII connection, not analogue PHY or board-skew qualification.
module tb_m4c_board_pair;
    logic sysclk=0,miiclk=0,btn=1,hostuart=1;
    always #5 sysclk=~sysclk;
    always #20 miiclk=~miiclk;
    wire [3:0] led_a,led_b,atxd,btxd;
    wire atxen,btxen,aref,bref,arstn,brstn,uart_a,uart_b;
    localparam integer PACKETS=8;
    ethernet_generator_a7_m4c #(
        .PHY_RESET_CYCLES(16),.BURST_PACKETS(PACKETS),
        .DRAIN_CYCLES(30000)
    ) board_a(
        .clk(sysclk),.btn0(btn),.led(led_a),
        .eth_rx_clk(miiclk),.eth_tx_clk(miiclk),
        .eth_rx_dv(btxen),.eth_rxerr(1'b0),.eth_rxd(btxd),
        .eth_ref_clk(aref),.eth_rstn(arstn),
        .eth_tx_en(atxen),.eth_txd(atxd),
        .uart_rx_i(hostuart),.uart_tx_o(uart_a)
    );
    ethernet_udp_a7_buffered #(
        .PHY_RESET_CYCLES(16)
    ) board_b(
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
    reg [7:0] captured[0:39];
    integer count=0,tx_frame_count=0;
    logic last_tx_en=0;
    always @(posedge sysclk) begin
        if(btn) count<=0;
        else if(tel_valid) begin
            if(count>=40) $fatal(1,"Too many UART bytes");
            captured[count]<=tel_byte;
            count<=count+1;
        end
        if(tel_err && !btn) $fatal(1,"UART framing error");
    end
    always @(posedge miiclk) begin
        if(btn) begin tx_frame_count<=0;last_tx_en<=0;end
        else begin
            last_tx_en<=atxen;
            if(atxen && !last_tx_en) tx_frame_count<=tx_frame_count+1;
        end
    end
    task automatic send_host(input [7:0] cmd);
        begin
            hostuart=0;#8680;
            for(integer i=0;i<8;i=i+1) begin hostuart=cmd[i];#8680;end
            hostuart=1;#8680;
        end
    endtask
    task automatic run_profile(input [7:0] cmd);
        reg [31:0] sent,received,dup,unexpected,invalid,late,min_gap,max_gap,span;
        begin
            @(negedge sysclk);count=0;
            send_host(cmd);
            wait(count==40);
            @(negedge sysclk);
            sent={captured[4],captured[5],captured[6],captured[7]};
            received={captured[8],captured[9],captured[10],captured[11]};
            dup={captured[12],captured[13],captured[14],captured[15]};
            unexpected={captured[16],captured[17],captured[18],captured[19]};
            invalid={captured[20],captured[21],captured[22],captured[23]};
            late={captured[24],captured[25],captured[26],captured[27]};
            min_gap={captured[28],captured[29],captured[30],captured[31]};
            max_gap={captured[32],captured[33],captured[34],captured[35]};
            span={captured[36],captured[37],captured[38],captured[39]};
            if(captured[0]!==8'h42 || captured[1]!==cmd ||
               captured[2]!==8'h01 || captured[3]!==8'h00)
               $fatal(1,"Wrong M4C UART header");
            if(sent!=PACKETS || received!=PACKETS || dup!=0 || unexpected!=0 || invalid!=0)
               $fatal(1,"M4C profile %c count mismatch sent=%d good=%d dup=%d unexp=%d invalid=%d",
                     cmd,sent,received,dup,unexpected,invalid);
            if(tx_frame_count!=PACKETS)
               $fatal(1,"M4C profile %c expected %d MII TX frames but saw %d",
                      cmd,PACKETS,tx_frame_count);
            if(span==0 || min_gap==0 || max_gap<min_gap)
               $fatal(1,"M4C timing telemetry invalid");
            // The testbench has an idealised 25MHz PHY; the hardware paced
            // generator must honour the selected interval, within a few
            // sysclk cycles of synchroniser/scheduler variation.
            if(cmd==8'h41 && (min_gap<9990 || max_gap>10010))
               $fatal(1,"Profile A inaccurate gap: %d..%d",min_gap,max_gap);
            if(cmd==8'h42 && (min_gap<1990 || max_gap>2010))
               $fatal(1,"Profile B inaccurate gap: %d..%d",min_gap,max_gap);
            if(cmd==8'h43 && (min_gap<990 || max_gap>1010))
               $fatal(1,"Profile C inaccurate gap: %d..%d",min_gap,max_gap);
            $display("PASS M4C profile %c: sent=%0d unique=%0d late=%0d gap=%0d..%0d cycles",
                     cmd,sent,received,late,min_gap,max_gap);
        end
    endtask
    task automatic reset_boards;
        begin
            @(negedge sysclk);btn=1;
            repeat(20) @(negedge sysclk);
            btn=0;
            repeat(200) @(negedge sysclk);
        end
    endtask
    initial begin
        repeat(20) @(posedge sysclk);
        reset_boards();
        run_profile(8'h41);
        reset_boards();
        run_profile(8'h42);
        reset_boards();
        run_profile(8'h43);
        $display("PASS tb_m4c_board_pair: three hardware-paced profiles and reply scoreboard");
        $finish;
    end
    initial begin #30000000; $fatal(1,"M4C TB timeout");end
endmodule
