// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module sdram_burst (
    input  logic clk_in,
    input  logic reset,
    input  logic start,
    input  logic req_write,
    input  logic [params::SDRAM_BANK_BITS-1:0] req_bank,
    input  logic [params::SDRAM_ROW_BITS-1:0] req_row,
    input  logic [params::SDRAM_COLUMN_BITS-1:0] req_col,
    input  logic [(params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH)-1:0] req_write_data,
    input  logic [params::SDRAM_DATA_BITS-1:0] dq_in,
    output logic busy,
    output logic done,
    output logic [(params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH)-1:0] read_data,
    output logic cmd_valid,
    output enums::sdram_cmd_e cmd_code,
    output logic [params::SDRAM_ADDR_BITS-1:0] cmd_addr,
    output logic [params::SDRAM_BANK_BITS-1:0] cmd_bank,
    output logic [params::SDRAM_DATA_BITS-1:0] dq_out,
    output logic dq_oe
);
    localparam int unsigned BURST_WORD_BITS = params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH;
    localparam logic [params::SDRAM_ADDR_BITS-1:0] AUTO_PRECHARGE_BIT = {
        {(params::SDRAM_ADDR_BITS - 11){1'b0}},
        1'b1,
        10'b0
    };

    typedef enum logic [3:0] {
        BURST_IDLE,
        BURST_ACTIVATE,
        BURST_WAIT_TRCD,
        BURST_ISSUE_WRITE,
        BURST_WRITE_DATA,
        BURST_ISSUE_READ,
        BURST_WAIT_READ,
        BURST_READ_DATA,
        BURST_WAIT_TRP,
        BURST_DONE
    } burst_state_e;

    burst_state_e state;
    logic                   write_q;
    logic [params::SDRAM_BANK_BITS-1:0] bank_q;
    logic [params::SDRAM_ROW_BITS-1:0] row_q;
    logic [params::SDRAM_COLUMN_BITS-1:0] col_q;
    logic [BURST_WORD_BITS-1:0] write_data_q;
    logic [BURST_WORD_BITS-1:0] read_data_q;
    logic [calc::safe_clog2(params::SDRAM_TRCD_CYCLES + 1)-1:0] trcd_count;
    logic [calc::safe_clog2(params::SDRAM_TRP_CYCLES + 1)-1:0] trp_count;
    logic [calc::safe_clog2(params::SDRAM_CAS_LATENCY + 1)-1:0] cas_count;
    logic [calc::safe_clog2(params::SDRAM_BURST_LENGTH)-1:0] beat_index;

    function automatic logic [params::SDRAM_DATA_BITS-1:0] burst_word(
        input logic [BURST_WORD_BITS-1:0] burst_data,
        input logic [calc::safe_clog2(params::SDRAM_BURST_LENGTH)-1:0] word_index
    );
        burst_word = burst_data[(word_index * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS];
    endfunction

    always_ff @(posedge clk_in) begin
        if (reset) begin
            state <= BURST_IDLE;
            write_q <= 1'b0;
            bank_q <= '0;
            row_q <= '0;
            col_q <= '0;
            write_data_q <= '0;
            read_data_q <= '0;
            trcd_count <= '0;
            trp_count <= '0;
            cas_count <= '0;
            beat_index <= '0;
        end else begin
            case (state)
                BURST_IDLE: begin
                    if (start) begin
                        write_q <= req_write;
                        bank_q <= req_bank;
                        row_q <= req_row;
                        col_q <= req_col;
                        write_data_q <= req_write_data;
                        read_data_q <= '0;
                        beat_index <= '0;
                        state <= BURST_ACTIVATE;
                    end
                end
                BURST_ACTIVATE: begin
                    state <= BURST_WAIT_TRCD;
                    trcd_count <= '0;
                end
                BURST_WAIT_TRCD: begin
                    if (trcd_count == $bits(trcd_count)'(params::SDRAM_TRCD_CYCLES - 1)) begin
                        state <= write_q ? BURST_ISSUE_WRITE : BURST_ISSUE_READ;
                    end else begin
                        trcd_count <= trcd_count + 'd1;
                    end
                end
                BURST_ISSUE_WRITE: begin
                    beat_index <= $bits(beat_index)'(1);
                    if (params::SDRAM_BURST_LENGTH == 1) begin
                        state <= BURST_WAIT_TRP;
                        trp_count <= '0;
                    end else begin
                        state <= BURST_WRITE_DATA;
                    end
                end
                BURST_WRITE_DATA: begin
                    if (beat_index == $bits(beat_index)'(params::SDRAM_BURST_LENGTH - 1)) begin
                        state <= BURST_WAIT_TRP;
                        trp_count <= '0;
                    end else begin
                        beat_index <= beat_index + 'd1;
                    end
                end
                BURST_ISSUE_READ: begin
                    cas_count <= '0;
                    beat_index <= '0;
                    state <= BURST_WAIT_READ;
                end
                BURST_WAIT_READ: begin
                    if (cas_count == $bits(cas_count)'(params::SDRAM_CAS_LATENCY - 1)) begin
                        state <= BURST_READ_DATA;
                    end else begin
                        cas_count <= cas_count + 'd1;
                    end
                end
                BURST_READ_DATA: begin
                    read_data_q[(beat_index * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS] <= dq_in;
                    if (beat_index == $bits(beat_index)'(params::SDRAM_BURST_LENGTH - 1)) begin
                        state <= BURST_WAIT_TRP;
                        trp_count <= '0;
                    end else begin
                        beat_index <= beat_index + 'd1;
                    end
                end
                BURST_WAIT_TRP: begin
                    if (trp_count == $bits(trp_count)'(params::SDRAM_TRP_CYCLES - 1)) begin
                        state <= BURST_DONE;
                    end else begin
                        trp_count <= trp_count + 'd1;
                    end
                end
                BURST_DONE: begin
                    state <= BURST_IDLE;
                end
                default: begin
                    state <= BURST_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        busy = (state != BURST_IDLE) && (state != BURST_DONE);
        done = (state == BURST_DONE);
        read_data = read_data_q;
        cmd_valid = 1'b1;
        cmd_code = enums::SDRAM_CMD_NOP;
        cmd_addr = '0;
        cmd_bank = bank_q;
        dq_out = '0;
        dq_oe = 1'b0;

        case (state)
            BURST_ACTIVATE: begin
                cmd_code = enums::SDRAM_CMD_ACTIVE;
                cmd_addr[params::SDRAM_ROW_BITS-1:0] = row_q;
            end
            BURST_ISSUE_WRITE: begin
                cmd_code = enums::SDRAM_CMD_WRITE;
                cmd_addr[params::SDRAM_COLUMN_BITS-1:0] = col_q;
                cmd_addr = cmd_addr | AUTO_PRECHARGE_BIT;
                dq_out = burst_word(write_data_q, '0);
                dq_oe = 1'b1;
            end
            BURST_WRITE_DATA: begin
                dq_out = burst_word(write_data_q, beat_index);
                dq_oe = 1'b1;
            end
            BURST_ISSUE_READ: begin
                cmd_code = enums::SDRAM_CMD_READ;
                cmd_addr[params::SDRAM_COLUMN_BITS-1:0] = col_q;
                cmd_addr = cmd_addr | AUTO_PRECHARGE_BIT;
            end
            default: begin
            end
        endcase
    end
endmodule
