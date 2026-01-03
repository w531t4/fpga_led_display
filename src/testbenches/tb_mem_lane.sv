// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
// mem_lane: Single‑lane dual‑clock byte RAM
//      - writes on clka when enabled
//      - on clka, writes dia when enabled
//      - on clkb:
//          - outputs dob after two pipeline stages
//          - rstb forces dob to zero
//      - used as the per‑lane storage block in multimem
module tb_mem_lane #(
    parameter integer ADDR_BITS = 4,
    parameter integer DW = 8,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int DEPTH = (1 << ADDR_BITS);
    localparam int READ_LATENCY = 2;
    localparam real SIM_HALF_PERIOD_A_NS = params::SIM_HALF_PERIOD_NS;
    localparam real SIM_HALF_PERIOD_B_NS = params::SIM_HALF_PERIOD_NS + 1.0;
    localparam logic [ADDR_BITS-1:0] ADDR_MIN = '0;
    localparam logic [ADDR_BITS-1:0] ADDR_MAX = ADDR_BITS'(DEPTH - 1);
    localparam logic [DW-1:0] DATA_MIN = {DW{1'b0}};
    localparam logic [DW-1:0] DATA_MAX = {DW{1'b1}};
    localparam logic [DW-1:0] DATA_ALT = {{(DW - 1) {1'b0}}, 1'b1};
    logic clka;
    logic ena;
    logic wea;
    logic [ADDR_BITS-1:0] addra;
    logic [DW-1:0] dia;

    logic clkb;
    logic enb;
    logic rstb;
    logic [ADDR_BITS-1:0] addrb;
    wire [DW-1:0] dob;

    logic [DW-1:0] model_mem[DEPTH];

    mem_lane #(
        .ADDR_BITS(ADDR_BITS),
        .DW(DW)
    ) dut (
        .clka (clka),
        .ena  (ena),
        .wea  (wea),
        .addra(addra),
        .dia  (dia),
        .clkb (clkb),
        .enb  (enb),
        .rstb (rstb),
        .addrb(addrb),
        .dob  (dob)
    );

    task automatic write_word(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] data);
        @(negedge clka);
        ena   = 1'b1;
        wea   = 1'b1;
        addra = addr;
        dia   = data;
        @(posedge clka);
        model_mem[addr] = data;
        @(negedge clka);
        ena = 1'b0;
        wea = 1'b0;
    endtask

    task automatic write_no_ena(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] data);
        @(negedge clka);
        ena   = 1'b0;
        wea   = 1'b1;
        addra = addr;
        dia   = data;
        @(posedge clka);
        @(negedge clka);
        wea = 1'b0;
    endtask

    task automatic write_no_wea(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] data);
        @(negedge clka);
        ena   = 1'b1;
        wea   = 1'b0;
        addra = addr;
        dia   = data;
        @(posedge clka);
        @(negedge clka);
        ena = 1'b0;
    endtask

    task automatic read_expect(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] expected);
        @(negedge clkb);
        enb   = 1'b1;
        addrb = addr;
        repeat (READ_LATENCY) @(posedge clkb);
        #1;
        if (dob !== expected) begin  // check read data matches model after latency
            $fatal(1, "read mismatch addr=%0d expected=%0h got=%0h", addr, expected, dob);
        end
        @(negedge clkb);
        enb = 1'b0;
    endtask

    task automatic read_expect_latency(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] expected,
                                       input logic [DW-1:0] previous);
        @(negedge clkb);
        enb   = 1'b1;
        addrb = addr;
        @(posedge clkb);
        #1;
        if (dob !== previous) begin  // check dob still shows prior address data after 1st cycle
            $fatal(1, "latency early addr=%0d expected_prev=%0h got=%0h", addr, previous, dob);
        end
        @(posedge clkb);
        #1;
        if (dob !== expected) begin  // check dob updates after two cycles
            $fatal(1, "latency late addr=%0d expected=%0h got=%0h", addr, expected, dob);
        end
        @(negedge clkb);
        enb = 1'b0;
    endtask

    task automatic prove_read_latency_two(input logic [ADDR_BITS-1:0] prev_addr, input logic [DW-1:0] prev_data,
                                          input logic [ADDR_BITS-1:0] next_addr, input logic [DW-1:0] next_data);
        read_expect(prev_addr, prev_data);
        @(negedge clkb);
        enb   = 1'b1;
        addrb = next_addr;
        @(posedge clkb);
        #1;
        if (dob !== prev_data) begin  // check data has not advanced after 1 cycle
            $fatal(1, "latency short prev_addr=%0d expected=%0h got=%0h", prev_addr, prev_data, dob);
        end
        @(posedge clkb);
        #1;
        if (dob !== next_data) begin  // check data updates on the 2nd cycle
            $fatal(1, "latency long next_addr=%0d expected=%0h got=%0h", next_addr, next_data, dob);
        end
        @(negedge clkb);
        enb = 1'b0;
    endtask

    task automatic hold_expect(input logic [ADDR_BITS-1:0] addr, input logic [DW-1:0] expected);
        @(negedge clkb);
        enb   = 1'b0;
        addrb = addr;
        repeat (READ_LATENCY + 1) @(posedge clkb);
        #1;
        if (dob !== expected) begin  // check dob holds when enb is low
            $fatal(1, "dob changed while enb=0 expected=%0h got=%0h", expected, dob);
        end
    endtask

    task automatic prove_reset_clears_dob;
        // Prime dob with a known non-zero value before reset.
        write_word(ADDR_MIN, DATA_MAX);
        read_expect(ADDR_MIN, model_mem[ADDR_MIN]);
        #1;
        if (dob !== DATA_MAX) begin  // check dob is non-zero before reset
            $fatal(1, "pre-reset dob not set expected=%0h got=%0h", DATA_MAX, dob);
        end

        @(negedge clkb);
        rstb = 1'b1;
        @(posedge clkb);
        #1;
        if (dob !== DATA_MIN) begin  // check rstb drives dob to zero
            $fatal(1, "reset failed expected=%0h got=%0h", DATA_MIN, dob);
        end
        rstb = 1'b0;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_mem_lane);
        clka  = 0;
        clkb  = 0;
        ena   = 0;
        wea   = 0;
        addra = '0;
        dia   = '0;
        enb   = 0;
        rstb  = 0;
        addrb = '0;

        for (int i = 0; i < DEPTH; i++) begin
            model_mem[i] = DATA_MIN;
        end

        // Prep: reset read path to a known state.
        @(negedge clkb);
        rstb  = 1'b1;
        enb   = 1'b1;
        addrb = '0;
        @(posedge clkb);
        #1;
        rstb = 1'b0;
        enb  = 1'b0;

        // Baseline reads at min/max addresses should return zero.
        read_expect(ADDR_MIN, DATA_MIN);
        read_expect(ADDR_MAX, DATA_MIN);

        // Min/max address writes with min/max data.
        write_word(ADDR_MIN, DATA_MAX);
        write_word(ADDR_MAX, DATA_ALT);

        // Prove read latency is exactly 2 cycles when changing addresses.
        prove_read_latency_two(ADDR_MIN, model_mem[ADDR_MIN], ADDR_MAX, model_mem[ADDR_MAX]);
        prove_read_latency_two(ADDR_MAX, model_mem[ADDR_MAX], ADDR_MIN, model_mem[ADDR_MIN]);

        // Writes should be ignored when ena/wea are deasserted.
        write_no_wea(ADDR_MIN, DATA_MIN);
        read_expect(ADDR_MIN, model_mem[ADDR_MIN]);
        write_no_ena(ADDR_MAX, DATA_MAX);
        read_expect(ADDR_MAX, model_mem[ADDR_MAX]);

        // Overwrite max address with zero to verify clearing.
        write_word(ADDR_MAX, DATA_MIN);
        read_expect(ADDR_MAX, model_mem[ADDR_MAX]);

        // Hold behavior when enb is low.
        read_expect(ADDR_MIN, model_mem[ADDR_MIN]);
        hold_expect(ADDR_MAX, model_mem[ADDR_MIN]);

        // Prove that issuing a reset will present a 0 on dob.
        prove_reset_clears_dob();

        // Memory contents should survive rstb on read path.
        read_expect(ADDR_MIN, model_mem[ADDR_MIN]);
        read_expect(ADDR_MAX, model_mem[ADDR_MAX]);

        #100 $finish;
    end

    always begin
        #(SIM_HALF_PERIOD_A_NS) clka <= ~clka;
    end

    always begin
        #(SIM_HALF_PERIOD_B_NS) clkb <= ~clkb;
    end
endmodule
