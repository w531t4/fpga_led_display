// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_litedram_bist #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam logic [23:0] TEST_ADDR = 24'h000123;
    localparam logic [15:0] TEST_DATA = 16'hcafe;
    localparam int unsigned MAX_TEST_CYCLES = 64;

    logic        clk;
    logic        reset;
    logic        init_done;
    logic        init_error;
    wire         busy;
    wire         done;
    wire         error;
    wire         cmd_valid;
    logic        cmd_ready;
    wire         cmd_we;
    wire [23:0]  cmd_addr;
    wire         wdata_valid;
    logic        wdata_ready;
    wire [1:0]   wdata_we;
    wire [15:0]  wdata_data;
    logic        rdata_valid;
    wire         rdata_ready;
    logic [15:0] rdata_data;

    logic [7:0] cycle_count;
    logic [1:0] read_delay;
    logic [15:0] stored_data;
    int unsigned write_cmd_count;
    int unsigned write_data_count;
    int unsigned read_cmd_count;
    int unsigned read_data_count;

    litedram_bist #(
        .TEST_ADDR(TEST_ADDR),
        .TEST_DATA(TEST_DATA),
        .MAX_WAIT_TICKS(16)
    ) dut (
        .clk(clk),
        .reset(reset),
        .init_done(init_done),
        .init_error(init_error),
        .busy(busy),
        .done(done),
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

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_litedram_bist);
        clk = 1'b0;
        reset = 1'b1;
        init_done = 1'b0;
        init_error = 1'b0;
        cycle_count = '0;
        read_delay = '0;
        stored_data = '0;
        write_cmd_count = 0;
        write_data_count = 0;
        read_cmd_count = 0;
        read_data_count = 0;

        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (3) @(posedge clk);
        init_done = 1'b1;

        for (int unsigned cycle = 0; cycle < MAX_TEST_CYCLES && !done; cycle++) begin
            @(posedge clk);
        end

        if (!done) begin
            $fatal(1, "bist did not finish within %0d cycles", MAX_TEST_CYCLES);
        end
        if (error) begin
            $fatal(1, "bist reported error");
        end
        if (busy) begin
            $fatal(1, "bist still busy after done");
        end
        if (write_cmd_count != 1 || write_data_count != 1 || read_cmd_count != 1 || read_data_count != 1) begin
            $fatal(1, "unexpected native transactions wc=%0d wd=%0d rc=%0d rd=%0d", write_cmd_count,
                   write_data_count, read_cmd_count, read_data_count);
        end

        $display("tb_litedram_bist: PASS data=%0h", stored_data);
        $finish;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    always_comb begin
        cmd_ready = !reset && init_done && !done && cycle_count[0] == 1'b0;
        wdata_ready = !reset && init_done && !done && cycle_count[1:0] == 2'b01;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            cycle_count <= '0;
            read_delay <= '0;
            rdata_valid <= 1'b0;
            rdata_data <= '0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            rdata_valid <= 1'b0;

            if (cmd_valid && cmd_ready) begin
                if (cmd_addr !== TEST_ADDR) begin
                    $fatal(1, "cmd addr mismatch expected=%0h got=%0h", TEST_ADDR, cmd_addr);
                end
                if (cmd_we) begin
                    write_cmd_count <= write_cmd_count + 1;
                end else begin
                    read_cmd_count <= read_cmd_count + 1;
                    read_delay <= 2'd2;
                end
            end

            if (wdata_valid && wdata_ready) begin
                if (wdata_we !== 2'b11 || wdata_data !== TEST_DATA) begin
                    $fatal(1, "write data mismatch we=%0b data=%0h", wdata_we, wdata_data);
                end
                write_data_count <= write_data_count + 1;
                stored_data <= wdata_data;
            end

            if (read_delay != 2'd0) begin
                read_delay <= read_delay - 1'b1;
                if (read_delay == 2'd1) begin
                    if (!rdata_ready) begin
                        $fatal(1, "read data returned while bist was not ready");
                    end
                    rdata_valid <= 1'b1;
                    rdata_data <= stored_data;
                    read_data_count <= read_data_count + 1;
                end
            end
        end
    end
endmodule
