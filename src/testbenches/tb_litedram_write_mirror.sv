// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_litedram_write_mirror #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int unsigned MAX_TEST_CYCLES = 64;

    logic clk;
    logic reset;
    logic init_done;
    logic init_error;
    types::mem_write_addr_t source_addr;
    types::mem_write_data_t source_data;
    logic source_write_valid;
    logic source_frame;
    wire busy;
    wire seen_write;
    wire dropped;
    wire dropped_before_init;
    wire error;
    wire cmd_valid;
    logic cmd_ready;
    wire cmd_we;
    wire [23:0] cmd_addr;
    wire wdata_valid;
    logic wdata_ready;
    wire [1:0] wdata_we;
    wire [15:0] wdata_data;
    logic rdata_valid;
    wire rdata_ready;
    logic [15:0] rdata_data;

    logic [7:0] cycle_count;
    int unsigned cmd_count;
    int unsigned data_count;
    int unsigned busy_cycle;

    litedram_write_mirror #(
        .MAX_WAIT_TICKS(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .init_done(init_done),
        .init_error(init_error),
        .source_addr(source_addr),
        .source_data(source_data),
        .source_write_valid(source_write_valid),
        .source_frame(source_frame),
        .busy(busy),
        .seen_write(seen_write),
        .dropped(dropped),
        .dropped_before_init(dropped_before_init),
        .error(error),
        .cmd_valid(cmd_valid),
        .cmd_ready(cmd_ready),
        .cmd_we(cmd_we),
        .cmd_addr(cmd_addr),
        .wdata_valid(wdata_valid),
        .wdata_ready(wdata_ready),
        .wdata_we(wdata_we),
        .wdata_data(wdata_data),
        .rdata_valid(rdata_valid),
        .rdata_ready(rdata_ready),
        .rdata_data(rdata_data)
    );

    function automatic logic [23:0] expected_addr(input logic frame, input types::mem_write_addr_t addr);
        expected_addr = 24'({frame, addr});
    endfunction

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_litedram_write_mirror);
        clk = 1'b0;
        reset = 1'b1;
        init_done = 1'b0;
        init_error = 1'b0;
        source_addr = '0;
        source_data = '0;
        source_write_valid = 1'b0;
        source_frame = 1'b0;
        cycle_count = '0;
        cmd_count = 0;
        data_count = 0;
        busy_cycle = 0;
        rdata_valid = 1'b0;
        rdata_data = '0;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        source_addr = '{subpanel: types::subpanel_addr_t'(1'b0), row: types::row_subpanel_addr_t'(4'h2), col: types::col_addr_t'(10'h015), pixel: types::pixel_addr_t'(2'h1)};
        source_data = 8'ha5;
        source_frame = 1'b1;
        source_write_valid = 1'b1;
        @(posedge clk);
        source_write_valid = 1'b0;
        if (!dropped_before_init || dropped) begin
            $fatal(1, "write before init was not reported separately dropped=%0b before_init=%0b", dropped,
                   dropped_before_init);
        end

        repeat (2) @(posedge clk);
        init_done = 1'b1;
        source_addr = '{subpanel: types::subpanel_addr_t'(1'b1), row: types::row_subpanel_addr_t'(4'h3), col: types::col_addr_t'(10'h02a), pixel: types::pixel_addr_t'(2'h2)};
        source_data = 8'h3c;
        source_frame = 1'b0;
        source_write_valid = 1'b1;
        @(posedge clk);
        source_write_valid = 1'b0;

        source_addr = '{subpanel: types::subpanel_addr_t'(1'b0), row: types::row_subpanel_addr_t'(4'h1), col: types::col_addr_t'(10'h001), pixel: types::pixel_addr_t'(2'h0)};
        source_data = 8'h55;
        source_write_valid = 1'b1;
        @(posedge clk);
        source_write_valid = 1'b0;
        if (!dropped) begin
            $fatal(1, "write while busy was not reported as dropped");
        end

        for (int unsigned cycle = 0; cycle < MAX_TEST_CYCLES && !seen_write; cycle++) begin
            @(posedge clk);
        end

        if (!seen_write) begin
            $fatal(1, "mirror did not complete a write within %0d cycles", MAX_TEST_CYCLES);
        end
        if (busy) begin
            $fatal(1, "mirror still busy after seen_write");
        end
        if (error) begin
            $fatal(1, "mirror reported error");
        end
        if (cmd_count != 1 || data_count != 1) begin
            $fatal(1, "unexpected native write counts cmd=%0d data=%0d", cmd_count, data_count);
        end

        $display("tb_litedram_write_mirror: PASS cmd=%0d data=%0d busy_cycle=%0d", cmd_count, data_count,
                 busy_cycle);
        $finish;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    always_comb begin
        cmd_ready = !reset && init_done && cycle_count[0] == 1'b1;
        wdata_ready = !reset && init_done && cycle_count[1:0] == 2'b10;
    end

    wire _unused_ok_rdata_ready = &{1'b0, rdata_ready, 1'b0};

    always_ff @(posedge clk) begin
        if (reset) begin
            cycle_count <= '0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            if (busy) begin
                busy_cycle <= busy_cycle + 1;
            end
            if (cmd_valid && cmd_ready) begin
                if (!cmd_we || cmd_addr !== expected_addr(1'b0, '{subpanel: types::subpanel_addr_t'(1'b1), row: types::row_subpanel_addr_t'(4'h3), col: types::col_addr_t'(10'h02a), pixel: types::pixel_addr_t'(2'h2)})) begin
                    $fatal(1, "unexpected cmd we=%0b addr=%0h", cmd_we, cmd_addr);
                end
                cmd_count <= cmd_count + 1;
            end
            if (wdata_valid && wdata_ready) begin
                if (wdata_we !== 2'b01 || wdata_data !== 16'h003c) begin
                    $fatal(1, "unexpected wdata we=%0b data=%0h", wdata_we, wdata_data);
                end
                data_count <= data_count + 1;
            end
        end
    end
endmodule
