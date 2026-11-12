// SPDX-License-Identifier: MIT
// M4B: bounded dual-clock FIFO; binary local pointers, Gray-coded crossing.
// DEPTH must be power of two >=4. First-word fall-through output. The
// consumer samples rd_data only on rd_valid && rd_ready. Reset must be
// asserted to both sides before either begins operating.
// Uses read/write pointer synchronisers; no unqualified multi-bit data bus
// sampling across clocks. Separate clock domains may have unrelated phase.
module m4b_async_fifo #(
    parameter integer WIDTH = 128,
    parameter integer DEPTH = 8,
    parameter bit READ_NEGEDGE = 1'b0
)(
    input  wire             wr_clk,
    input  wire             wr_rst_n,
    input  wire             wr_valid,
    input  wire [WIDTH-1:0] wr_data,
    output wire             wr_ready,
    output wire             wr_full,
    input  wire             rd_clk,
    input  wire             rd_rst_n,
    output wire             rd_valid,
    output wire [WIDTH-1:0] rd_data,
    input  wire             rd_ready,
    output wire             rd_empty
);
    localparam integer AB = $clog2(DEPTH);
    // Depth is constrained by the project checker, testbench, and parameter
    // assumptions. The two high-order Gray bits are inverted for full test.
    (* ram_style = "distributed" *) logic [WIDTH-1:0] mem [0:DEPTH-1];
    logic [AB:0] wr_bin, wr_gray, rd_bin, rd_gray;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [AB:0] rd_gray_meta, rd_gray_sync;
    (* ASYNC_REG = "TRUE", SHREG_EXTRACT = "NO" *) logic [AB:0] wr_gray_meta, wr_gray_sync;
    logic full_reg, empty_reg;
    wire wr_fire = wr_valid && !full_reg;
    wire rd_fire = rd_ready && !empty_reg;
    wire [AB:0] wb_next = wr_bin + wr_fire;
    wire [AB:0] wg_next = (wb_next >> 1) ^ wb_next;
    wire [AB:0] rb_next = rd_bin + rd_fire;
    wire [AB:0] rg_next = (rb_next >> 1) ^ rb_next;
    wire [AB:0] rd_gray_full = {~rd_gray_sync[AB:AB-1],rd_gray_sync[AB-2:0]};

    assign wr_full = full_reg;
    assign wr_ready = !full_reg;
    assign rd_empty = empty_reg;
    assign rd_valid = !empty_reg;
    assign rd_data = mem[rd_bin[AB-1:0]];

    always_ff @(posedge wr_clk or negedge wr_rst_n) begin
        if (!wr_rst_n) begin
            wr_bin <= 0;
            wr_gray <= 0;
            rd_gray_meta <= 0;
            rd_gray_sync <= 0;
            full_reg <= 0;
        end else begin
            rd_gray_meta <= rd_gray;
            rd_gray_sync <= rd_gray_meta;
            if (wr_fire) begin
                mem[wr_bin[AB-1:0]] <= wr_data;
                wr_bin <= wb_next;
                wr_gray <= wg_next;
            end
            full_reg <= (wg_next == rd_gray_full);
        end
    end

    generate if (READ_NEGEDGE) begin: g_rd_neg
        always_ff @(negedge rd_clk or negedge rd_rst_n) begin
            if (!rd_rst_n) begin
                rd_bin <= 0;
                rd_gray <= 0;
                wr_gray_meta <= 0;
                wr_gray_sync <= 0;
                empty_reg <= 1;
            end else begin
                wr_gray_meta <= wr_gray;
                wr_gray_sync <= wr_gray_meta;
                if (rd_fire) begin
                    rd_bin <= rb_next;
                    rd_gray <= rg_next;
                end
                empty_reg <= (rg_next == wr_gray_sync);
            end
        end
    end else begin: g_rd_pos
        always_ff @(posedge rd_clk or negedge rd_rst_n) begin
            if (!rd_rst_n) begin
                rd_bin <= 0;
                rd_gray <= 0;
                wr_gray_meta <= 0;
                wr_gray_sync <= 0;
                empty_reg <= 1;
            end else begin
                wr_gray_meta <= wr_gray;
                wr_gray_sync <= wr_gray_meta;
                if (rd_fire) begin
                    rd_bin <= rb_next;
                    rd_gray <= rg_next;
                end
                empty_reg <= (rg_next == wr_gray_sync);
            end
        end
    end endgenerate
endmodule
