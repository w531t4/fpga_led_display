// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_litedram_init #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int unsigned EXPECTED_WRITES = 30;
    localparam int unsigned MAX_INIT_CYCLES = 22000;

    localparam logic [29:0] CSR_DDRCTRL_INIT_DONE_WORD      = 30'h000;
    localparam logic [29:0] CSR_DDRCTRL_INIT_ERROR_WORD     = 30'h001;
    localparam logic [29:0] CSR_SDRAM_DFII_CONTROL_WORD     = 30'h200;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_COMMAND_WORD = 30'h201;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_ISSUE_WORD   = 30'h202;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_ADDRESS_WORD = 30'h203;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_BADDR_WORD   = 30'h204;

    localparam logic [31:0] DFII_CONTROL_SOFTWARE = 32'h0000_000e;
    localparam logic [31:0] DFII_CONTROL_HARDWARE = 32'h0000_0001;
    localparam logic [31:0] SDRAM_CMD_PRECHARGE_ALL = 32'h0000_000b;
    localparam logic [31:0] SDRAM_CMD_LOAD_MODE     = 32'h0000_000f;
    localparam logic [31:0] SDRAM_CMD_AUTO_REFRESH  = 32'h0000_000d;
    localparam logic [31:0] SDRAM_ADDR_PRECHARGE_ALL = 32'h0000_0400;
    localparam logic [31:0] SDRAM_MODE_RESET_DLL     = 32'h0000_0120;
    localparam logic [31:0] SDRAM_MODE_NORMAL        = 32'h0000_0020;

    logic        clk;
    logic        reset;
    wire [29:0]  wb_adr;
    wire [31:0]  wb_dat_w;
    logic [31:0] wb_dat_r;
    wire [3:0]   wb_sel;
    wire         wb_cyc;
    wire         wb_stb;
    wire         wb_we;
    logic        wb_ack;
    wire [2:0]   wb_cti;
    wire [1:0]   wb_bte;
    wire         done;

    int unsigned write_index;
    int unsigned done_cycle;
    logic        saw_done;

    litedram_init dut (
        .clk(clk),
        .reset(reset),
        .wb_adr(wb_adr),
        .wb_dat_w(wb_dat_w),
        .wb_dat_r(wb_dat_r),
        .wb_sel(wb_sel),
        .wb_cyc(wb_cyc),
        .wb_stb(wb_stb),
        .wb_we(wb_we),
        .wb_ack(wb_ack),
        .wb_cti(wb_cti),
        .wb_bte(wb_bte),
        .done(done)
    );

    function automatic logic [29:0] expected_addr(input int unsigned idx);
        case (idx)
            0: expected_addr = CSR_DDRCTRL_INIT_DONE_WORD;
            1: expected_addr = CSR_DDRCTRL_INIT_ERROR_WORD;
            2, 3: expected_addr = CSR_SDRAM_DFII_CONTROL_WORD;
            4, 8, 12, 16, 20, 24: expected_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
            5, 9, 13, 17, 21, 25: expected_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
            6, 10, 14, 18, 22, 26: expected_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
            7, 11, 15, 19, 23, 27: expected_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
            28: expected_addr = CSR_SDRAM_DFII_CONTROL_WORD;
            29: expected_addr = CSR_DDRCTRL_INIT_DONE_WORD;
            default: expected_addr = 'x;
        endcase
    endfunction

    function automatic logic [31:0] expected_data(input int unsigned idx);
        case (idx)
            0, 1, 5, 9, 13, 16, 17, 20, 21, 25: expected_data = 32'h0000_0000;
            2, 3: expected_data = DFII_CONTROL_SOFTWARE;
            4, 12: expected_data = SDRAM_ADDR_PRECHARGE_ALL;
            6, 14: expected_data = SDRAM_CMD_PRECHARGE_ALL;
            7, 11, 15, 19, 23, 27, 29: expected_data = 32'h0000_0001;
            8: expected_data = SDRAM_MODE_RESET_DLL;
            10, 26: expected_data = SDRAM_CMD_LOAD_MODE;
            18, 22: expected_data = SDRAM_CMD_AUTO_REFRESH;
            24: expected_data = SDRAM_MODE_NORMAL;
            28: expected_data = DFII_CONTROL_HARDWARE;
            default: expected_data = 'x;
        endcase
    endfunction

    task automatic check_write;
        if (write_index >= EXPECTED_WRITES) begin
            $fatal(1, "extra write idx=%0d addr=%0h data=%0h", write_index, wb_adr, wb_dat_w);
        end
        if (wb_adr !== expected_addr(write_index)) begin
            $fatal(1, "write addr mismatch idx=%0d expected=%0h got=%0h", write_index,
                   expected_addr(write_index), wb_adr);
        end
        if (wb_dat_w !== expected_data(write_index)) begin
            $fatal(1, "write data mismatch idx=%0d expected=%0h got=%0h", write_index,
                   expected_data(write_index), wb_dat_w);
        end
        if (wb_sel !== 4'hf || wb_cti !== 3'b000 || wb_bte !== 2'b00) begin
            $fatal(1, "unexpected Wishbone controls idx=%0d sel=%0h cti=%0b bte=%0b", write_index, wb_sel,
                   wb_cti, wb_bte);
        end
        write_index++;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_litedram_init);
        clk = 1'b0;
        reset = 1'b1;
        wb_ack = 1'b0;
        wb_dat_r = 32'h0000_0000;
        write_index = 0;
        done_cycle = 0;
        saw_done = 1'b0;

        repeat (4) @(posedge clk);
        reset = 1'b0;

        for (int unsigned cycle = 0; cycle < MAX_INIT_CYCLES && !saw_done; cycle++) begin
            @(posedge clk);
            if (done) begin
                saw_done = 1'b1;
                done_cycle = cycle;
            end
        end

        if (!saw_done) begin
            $fatal(1, "init did not complete within %0d cycles; writes=%0d", MAX_INIT_CYCLES, write_index);
        end

        repeat (4) @(posedge clk);
        if (write_index != EXPECTED_WRITES) begin
            $fatal(1, "done after %0d writes, expected %0d", write_index, EXPECTED_WRITES);
        end
        $display("tb_litedram_init: PASS writes=%0d done_cycle=%0d", write_index, done_cycle);
        $finish;
    end

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    always_ff @(posedge clk) begin
        if (reset) begin
            wb_ack <= 1'b0;
        end else begin
            wb_ack <= wb_cyc & wb_stb;
            if (wb_cyc && wb_stb && wb_we && wb_ack) begin
                check_write();
            end
        end
    end
endmodule
