// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_sdram_controller;
    localparam int unsigned BURST_WORD_BITS = params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH;
    logic clk;
    logic reset;
    logic host_req_valid;
    wire host_req_ready;
    logic host_req_write;
    logic [params::SDRAM_BANK_BITS-1:0] host_req_bank;
    logic [params::SDRAM_ROW_BITS-1:0] host_req_row;
    logic [params::SDRAM_COLUMN_BITS-1:0] host_req_col;
    logic [BURST_WORD_BITS-1:0] host_req_write_data;
    wire host_resp_valid;
    wire [BURST_WORD_BITS-1:0] host_resp_read_data;
    wire init_done;
    wire refresh_active;
    wire controller_busy;

    wire sdram_clk;
    wire sdram_cke;
    wire sdram_csn;
    wire sdram_rasn;
    wire sdram_casn;
    wire sdram_wen;
    wire [params::SDRAM_ADDR_BITS-1:0] sdram_a;
    wire [params::SDRAM_BANK_BITS-1:0] sdram_ba;
    wire [params::SDRAM_DQM_BITS-1:0] sdram_dqm;
    wire [params::SDRAM_DATA_BITS-1:0] sdram_dq_out;
    wire sdram_dq_oe;
    wire [params::SDRAM_DATA_BITS-1:0] sdram_dq_in;

    logic [15:0] refresh_cmd_count;

    sdram_controller dut (
        .clk_in(clk),
        .reset(reset),
        .host_req_valid(host_req_valid),
        .host_req_ready(host_req_ready),
        .host_req_write(host_req_write),
        .host_req_bank(host_req_bank),
        .host_req_row(host_req_row),
        .host_req_col(host_req_col),
        .host_req_write_data(host_req_write_data),
        .host_resp_valid(host_resp_valid),
        .host_resp_read_data(host_resp_read_data),
        .init_done(init_done),
        .refresh_active(refresh_active),
        .controller_busy(controller_busy),
        .sdram_clk(sdram_clk),
        .sdram_cke(sdram_cke),
        .sdram_csn(sdram_csn),
        .sdram_rasn(sdram_rasn),
        .sdram_casn(sdram_casn),
        .sdram_wen(sdram_wen),
        .sdram_a(sdram_a),
        .sdram_ba(sdram_ba),
        .sdram_dqm(sdram_dqm),
        .sdram_dq_out(sdram_dq_out),
        .sdram_dq_oe(sdram_dq_oe),
        .sdram_dq_in(sdram_dq_in)
    );

    sdram_model_simple model (
        .clk(sdram_clk),
        .cke(sdram_cke),
        .csn(sdram_csn),
        .rasn(sdram_rasn),
        .casn(sdram_casn),
        .wen(sdram_wen),
        .addr(sdram_a),
        .bank(sdram_ba),
        .dq_in(sdram_dq_out),
        .dq_oe(sdram_dq_oe),
        .dq_out(sdram_dq_in)
    );

    function automatic logic [params::SDRAM_DATA_BITS-1:0] burst_word(
        input logic [BURST_WORD_BITS-1:0] burst_data,
        input int unsigned word_index
    );
        burst_word = burst_data[(word_index * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS];
    endfunction

    function automatic logic [BURST_WORD_BITS-1:0] make_burst(
        input logic [params::SDRAM_DATA_BITS-1:0] w0,
        input logic [params::SDRAM_DATA_BITS-1:0] w1,
        input logic [params::SDRAM_DATA_BITS-1:0] w2,
        input logic [params::SDRAM_DATA_BITS-1:0] w3
    );
        logic [BURST_WORD_BITS-1:0] burst_data;
        burst_data = '0;
        burst_data[(0 * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS] = w0;
        burst_data[(1 * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS] = w1;
        burst_data[(2 * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS] = w2;
        burst_data[(3 * params::SDRAM_DATA_BITS) +: params::SDRAM_DATA_BITS] = w3;
        return burst_data;
    endfunction

    task automatic issue_request(input logic write_not_read,
                                 input logic [params::SDRAM_BANK_BITS-1:0] bank,
                                 input logic [params::SDRAM_ROW_BITS-1:0] row,
                                 input logic [params::SDRAM_COLUMN_BITS-1:0] col,
                                 input logic [BURST_WORD_BITS-1:0] write_data);
        begin
            @(negedge clk);
            host_req_write = write_not_read;
            host_req_bank = bank;
            host_req_row = row;
            host_req_col = col;
            host_req_write_data = write_data;
            host_req_valid = 1'b1;
            while (host_req_ready !== 1'b1) begin
                @(posedge clk);
            end
            @(posedge clk);
            @(negedge clk);
            host_req_valid = 1'b0;
        end
    endtask

    task automatic expect_read_response(input logic [BURST_WORD_BITS-1:0] expected_data, input string label);
        begin
            `WAIT_ASSERT(clk, host_resp_valid === 1'b1, 512)
            assert (host_resp_read_data === expected_data)
            else
                $fatal(1, "%s expected=0x%0h got=0x%0h", label, expected_data, host_resp_read_data);
        end
    endtask

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            refresh_cmd_count <= '0;
        end else if (!sdram_csn && !sdram_rasn && !sdram_casn && sdram_wen) begin
            refresh_cmd_count <= refresh_cmd_count + 'd1;
        end
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_controller);
        clk = 1'b0;
        reset = 1'b1;
        host_req_valid = 1'b0;
        host_req_write = 1'b0;
        host_req_bank = '0;
        host_req_row = '0;
        host_req_col = '0;
        host_req_write_data = '0;
        refresh_cmd_count = '0;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        // Initialization must complete before any host traffic is accepted.
        `WAIT_ASSERT(clk, init_done === 1'b1, 256)
        assert (host_req_ready === 1'b1)
        else $fatal(1, "host_req_ready should be high after init completes");

        // Burst write followed by readback.
        issue_request(1'b1,
                      params::SDRAM_BANK_BITS'(1),
                      params::SDRAM_ROW_BITS'(3),
                      params::SDRAM_COLUMN_BITS'(2),
                      make_burst(16'h1111, 16'h2222, 16'h3333, 16'h4444));
        `WAIT_ASSERT(clk, controller_busy === 1'b0, 256)
        issue_request(1'b0, params::SDRAM_BANK_BITS'(1), params::SDRAM_ROW_BITS'(3), params::SDRAM_COLUMN_BITS'(2), '0);
        expect_read_response(make_burst(16'h1111, 16'h2222, 16'h3333, 16'h4444), "write/readback");

        // Verify SDRAM burst wrap behavior by reading from column 0 after a burst
        // started at column 3. Sequential burst-of-4 wraps inside that boundary.
        issue_request(1'b1,
                      params::SDRAM_BANK_BITS'(0),
                      params::SDRAM_ROW_BITS'(4),
                      params::SDRAM_COLUMN_BITS'(3),
                      make_burst(16'hAAAA, 16'hBBBB, 16'hCCCC, 16'hDDDD));
        `WAIT_ASSERT(clk, controller_busy === 1'b0, 256)
        issue_request(1'b0, params::SDRAM_BANK_BITS'(0), params::SDRAM_ROW_BITS'(4), params::SDRAM_COLUMN_BITS'(0), '0);
        expect_read_response(make_burst(16'hBBBB, 16'hCCCC, 16'hDDDD, 16'hAAAA), "wrapped readback");

        // Back-to-back independent transactions.
        issue_request(1'b1,
                      params::SDRAM_BANK_BITS'(1),
                      params::SDRAM_ROW_BITS'(1),
                      params::SDRAM_COLUMN_BITS'(0),
                      make_burst(16'h0A0A, 16'h0B0B, 16'h0C0C, 16'h0D0D));
        `WAIT_ASSERT(clk, controller_busy === 1'b0, 256)
        issue_request(1'b1,
                      params::SDRAM_BANK_BITS'(1),
                      params::SDRAM_ROW_BITS'(2),
                      params::SDRAM_COLUMN_BITS'(0),
                      make_burst(16'h1A1A, 16'h1B1B, 16'h1C1C, 16'h1D1D));
        `WAIT_ASSERT(clk, controller_busy === 1'b0, 256)
        issue_request(1'b0, params::SDRAM_BANK_BITS'(1), params::SDRAM_ROW_BITS'(2), params::SDRAM_COLUMN_BITS'(0), '0);
        expect_read_response(make_burst(16'h1A1A, 16'h1B1B, 16'h1C1C, 16'h1D1D), "back-to-back readback");

        // Allow the controller to sit idle long enough that refreshes must occur,
        // then confirm traffic resumes correctly afterward.
        repeat (params::SDRAM_REFRESH_INTERVAL_CYCLES * 3) @(posedge clk);
        assert (refresh_cmd_count >= 2)
        else $fatal(1, "expected at least two refresh commands, saw %0d", refresh_cmd_count);
        issue_request(1'b0, params::SDRAM_BANK_BITS'(1), params::SDRAM_ROW_BITS'(3), params::SDRAM_COLUMN_BITS'(2), '0);
        expect_read_response(make_burst(16'h1111, 16'h2222, 16'h3333, 16'h4444), "idle resume readback");

        $display("tb_sdram_controller: PASS");
        $finish;
    end

    wire _unused_ok = &{1'b0,
                        refresh_active,
                        controller_busy,
                        sdram_dqm,
                        1'b0};
endmodule

/* verilator lint_off DECLFILENAME */
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
/* verilator lint_on DECLFILENAME */
