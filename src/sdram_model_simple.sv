// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Simple behavioral SDRAM model for controller/store-backend simulations.
// It understands the limited command subset used by sdram_controller:
// ACTIVE, READ (auto-precharge), WRITE (auto-precharge), and PRECHARGE.
module sdram_model_simple (
    input  logic clk,
    input  logic cke,
    input  logic csn,
    input  logic rasn,
    input  logic casn,
    input  logic wen,
    input  logic [params::SDRAM_ADDR_BITS-1:0] addr,
    input  logic [params::SDRAM_BANK_BITS-1:0] bank,
    input  logic [params::SDRAM_DATA_BITS-1:0] dq_in,
    input  logic dq_oe,
    output logic [params::SDRAM_DATA_BITS-1:0] dq_out
);
    localparam int unsigned MEM_DEPTH = 1 << (params::SDRAM_BANK_BITS + params::SDRAM_ROW_BITS + params::SDRAM_COLUMN_BITS);

    logic [params::SDRAM_DATA_BITS-1:0] mem[MEM_DEPTH];
    logic [params::SDRAM_ROW_BITS-1:0] open_row[1 << params::SDRAM_BANK_BITS];
    logic                               row_open[1 << params::SDRAM_BANK_BITS];
    logic [params::SDRAM_BANK_BITS-1:0] read_bank_q;
    logic [params::SDRAM_ROW_BITS-1:0]  read_row_q;
    logic [params::SDRAM_COLUMN_BITS-1:0] read_col_q;
    logic [params::SDRAM_BANK_BITS-1:0] write_bank_q;
    logic [params::SDRAM_ROW_BITS-1:0]  write_row_q;
    logic [params::SDRAM_COLUMN_BITS-1:0] write_col_q;
    logic [calc::safe_clog2(params::SDRAM_CAS_LATENCY + 1)-1:0] read_latency_count;
    logic [calc::safe_clog2(params::SDRAM_BURST_LENGTH)-1:0] read_beat_index;
    logic [calc::safe_clog2(params::SDRAM_BURST_LENGTH)-1:0] write_beat_index;
    logic read_active;
    logic write_active;

    function automatic logic [params::SDRAM_COLUMN_BITS-1:0] burst_col(
        input logic [params::SDRAM_COLUMN_BITS-1:0] start_col,
        input logic [calc::safe_clog2(params::SDRAM_BURST_LENGTH)-1:0] beat_index
    );
        logic [params::SDRAM_COLUMN_BITS-1:0] burst_mask;
        burst_mask = params::SDRAM_COLUMN_BITS'(params::SDRAM_BURST_LENGTH - 1);
        burst_col = (start_col & ~burst_mask)
                    | ((start_col + params::SDRAM_COLUMN_BITS'(beat_index)) & burst_mask);
    endfunction

    function automatic int unsigned mem_index(
        input logic [params::SDRAM_BANK_BITS-1:0] bank_idx,
        input logic [params::SDRAM_ROW_BITS-1:0] row_idx,
        input logic [params::SDRAM_COLUMN_BITS-1:0] col_idx
    );
        mem_index = int'({bank_idx, row_idx, col_idx});
    endfunction

    always_ff @(posedge clk) begin
        if (!cke) begin
            dq_out <= '0;
        end else begin
            dq_out <= '0;

            if (read_active) begin
                if (read_latency_count != 0) begin
                    read_latency_count <= read_latency_count - 'd1;
                end else begin
                    dq_out <= mem[mem_index(read_bank_q, read_row_q, burst_col(read_col_q, read_beat_index))];
                    if (read_beat_index == $bits(read_beat_index)'(params::SDRAM_BURST_LENGTH - 1)) begin
                        read_active <= 1'b0;
                        row_open[read_bank_q] <= 1'b0;
                    end else begin
                        read_beat_index <= read_beat_index + 'd1;
                    end
                end
            end

            if (write_active) begin
                if (!dq_oe) begin
                    $fatal(1, "controller stopped driving dq during write burst");
                end
                mem[mem_index(write_bank_q, write_row_q, burst_col(write_col_q, write_beat_index))] <= dq_in;
                if (write_beat_index == $bits(write_beat_index)'(params::SDRAM_BURST_LENGTH - 1)) begin
                    write_active <= 1'b0;
                    row_open[write_bank_q] <= 1'b0;
                end else begin
                    write_beat_index <= write_beat_index + 'd1;
                end
            end

            if (!csn) begin
                if (!rasn && casn && wen) begin
                    open_row[bank] <= addr[params::SDRAM_ROW_BITS-1:0];
                    row_open[bank] <= 1'b1;
                end else if (rasn && !casn && wen) begin
                    assert (row_open[bank]) else $fatal(1, "read issued without open row");
                    read_active <= 1'b1;
                    read_bank_q <= bank;
                    read_row_q <= open_row[bank];
                    read_col_q <= addr[params::SDRAM_COLUMN_BITS-1:0];
                    read_beat_index <= '0;
                    read_latency_count <= $bits(read_latency_count)'(params::SDRAM_CAS_LATENCY - 1);
                end else if (rasn && !casn && !wen) begin
                    assert (row_open[bank]) else $fatal(1, "write issued without open row");
                    assert (dq_oe) else $fatal(1, "controller failed to drive dq on write command cycle");
                    mem[mem_index(bank, open_row[bank], burst_col(addr[params::SDRAM_COLUMN_BITS-1:0], '0))] <= dq_in;
                    write_active <= 1'b1;
                    write_bank_q <= bank;
                    write_row_q <= open_row[bank];
                    write_col_q <= addr[params::SDRAM_COLUMN_BITS-1:0];
                    write_beat_index <= $bits(write_beat_index)'(1);
                    if (params::SDRAM_BURST_LENGTH == 1) begin
                        write_active <= 1'b0;
                        row_open[bank] <= 1'b0;
                    end
                end else if (!rasn && casn && !wen) begin
                    if (addr[10]) begin
                        for (int bank_idx = 0; bank_idx < (1 << params::SDRAM_BANK_BITS); bank_idx++) begin
                            row_open[bank_idx] <= 1'b0;
                        end
                    end else begin
                        row_open[bank] <= 1'b0;
                    end
                end
            end
        end
    end

    initial begin
        dq_out = '0;
        read_active = 1'b0;
        write_active = 1'b0;
        read_bank_q = '0;
        read_row_q = '0;
        read_col_q = '0;
        write_bank_q = '0;
        write_row_q = '0;
        write_col_q = '0;
        read_latency_count = '0;
        read_beat_index = '0;
        write_beat_index = '0;
        for (int idx = 0; idx < MEM_DEPTH; idx++) begin
            mem[idx] = '0;
        end
        for (int bank_idx = 0; bank_idx < (1 << params::SDRAM_BANK_BITS); bank_idx++) begin
            open_row[bank_idx] = '0;
            row_open[bank_idx] = 1'b0;
        end
    end

    wire _unused_ok = &{1'b0, addr[params::SDRAM_ADDR_BITS-1:params::SDRAM_COLUMN_BITS], 1'b0};
endmodule
