// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_multimem #(
    parameter real SIM_HALF_PERIOD_NS = params::SIM_HALF_PERIOD_NS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int LANES = (1 << $bits(types::mem_structure_t));
    localparam int DEPTH_B = (1 << $bits(types::mem_read_addr_t));
    localparam types::subpanel_addr_t SUBPANEL0 = 'b0;
    localparam types::subpanel_addr_t SUBPANEL1 = types::subpanel_addr_t'(1);
    localparam types::pixel_addr_t PIXSEL0 = 'b0;
    localparam types::pixel_addr_t PIXSEL1 = types::pixel_addr_t'(1);
    localparam types::mem_read_addr_t ADDR_B_MAX = '1;  // all 1's
    localparam types::mem_read_addr_t ADDR_B_TOP0_MAX = {1'b0, {$bits(types::mem_read_addr_t) - 1{1'b1}}};

    logic clk_a;
    logic clk_b;
    types::mem_write_addr_t ram_a_address;
    types::mem_read_addr_t ram_b_address;
    types::mem_write_data_t ram_a_data_in;
    logic ram_a_clk_enable;
    logic ram_b_clk_enable;
    logic ram_a_wr;
    wire types::mem_read_data_t ram_b_data_out;
    logic ram_a_reset;
    logic ram_b_reset;

    wire types::mem_write_data_t _unused_ok_QA;
    types::mem_write_data_t model_mem[LANES][DEPTH_B];

    multimem #(
        ._UNUSED('d0)
    ) A (
        .DataInA(ram_a_data_in),
        .AddressA(ram_a_address),
        .AddressB(ram_b_address),
        .DataInB(16'b0),
        .WrB(1'b0),
        .QA(_unused_ok_QA),
        .ClockA(clk_a),
        .ClockB(clk_b),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable),
        .WrA(ram_a_wr),
        .ResetA(ram_a_reset),
        .ResetB(ram_b_reset),
        .QB(ram_b_data_out)
    );

    function automatic types::mem_write_addr_t pack_addr_a(input types::subpanel_addr_t subpanel,
                                                           input types::mem_read_addr_t addr_b,
                                                           input types::pixel_addr_t pixel_sel);
        pack_addr_a = {subpanel, addr_b, pixel_sel};
    endfunction

    function automatic types::mem_structure_t lane_index(input types::subpanel_addr_t subpanel,
                                                         input types::pixel_addr_t pixel_sel);
        lane_index = {subpanel, pixel_sel};
    endfunction

    function automatic types::mem_read_data_t build_expected(input types::mem_read_addr_t addr_b);
        types::mem_read_data_t expected;
        expected = '0;
        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            expected[lane*$bits(types::mem_write_data_t)+:$bits(types::mem_write_data_t)] = model_mem[lane][addr_b];
        end
        build_expected = expected;
    endfunction

    task automatic write_lane(input types::subpanel_addr_t subpanel, input types::pixel_addr_t pixel_sel,
                              input types::mem_read_addr_t addr_b, input types::mem_write_data_t data);
        types::mem_structure_t  lane_idx;
        types::mem_write_addr_t addr_a;
        lane_idx = lane_index(subpanel, pixel_sel);
        addr_a   = pack_addr_a(subpanel, addr_b, pixel_sel);
        @(negedge clk_a);
        ram_a_address = addr_a;
        ram_a_data_in = data;
        ram_a_clk_enable = 1'b1;
        ram_a_wr = 1'b1;
        @(posedge clk_a);
        @(posedge clk_a);
        model_mem[lane_idx][addr_b] = data;
        @(negedge clk_a);
        ram_a_clk_enable = 1'b0;
        ram_a_wr = 1'b0;
    endtask

    task automatic read_check(input types::mem_read_addr_t addr_b);
        types::mem_read_data_t expected;
        @(negedge clk_b);
        ram_b_clk_enable = 1'b1;
        ram_b_address = addr_b;
        expected = build_expected(addr_b);
        @(posedge clk_b);
        @(posedge clk_b);
        #1;
        if (ram_b_data_out !== expected) begin  // check read bus matches model for this address
            $fatal(1, "read mismatch addr_b=%0d expected=%0h got=%0h", addr_b, expected, ram_b_data_out);
        end
        @(negedge clk_b);
        ram_b_clk_enable = 1'b0;
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_multimem);
        clk_a = 0;
        clk_b = 0;
        ram_a_address = '0;
        ram_b_address = '0;
        ram_a_data_in = '0;
        ram_a_clk_enable = 0;
        ram_b_clk_enable = 0;
        ram_a_wr = 0;
        ram_a_reset = 0;
        ram_b_reset = 0;

        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            for (int idx = 0; idx < DEPTH_B; idx = idx + 1) begin
                model_mem[lane][idx] = '0;
            end
        end

        // Reset read data path and confirm it drives zero.
        @(negedge clk_b);
        ram_b_clk_enable = 1'b1;
        ram_b_address = '0;
        ram_a_reset = 1'b1;
        ram_b_reset = 1'b1;
        @(posedge clk_b);
        #1;
        if (ram_b_data_out !== '0) begin  // check reset forces read bus to zero
            $fatal(1, "reset failed expected=0 got=%0h", ram_b_data_out);
        end
        ram_a_reset = 1'b0;
        ram_b_reset = 1'b0;
        @(negedge clk_b);
        ram_b_clk_enable = 1'b0;

        // Baseline readback should be all zeros.
        read_check('0);

        // Write two lanes at the same address and read both back.
        write_lane(SUBPANEL0, PIXSEL0, ADDR_B_MAX, 8'hA1);
        write_lane(SUBPANEL0, PIXSEL1, ADDR_B_MAX, 8'hB2);
        read_check(ADDR_B_MAX);

        // Write a different subpanel at a different address.
        write_lane(SUBPANEL1, PIXSEL0, ADDR_B_TOP0_MAX, 8'hC3);
        read_check(ADDR_B_TOP0_MAX);

        // Overwrite an existing lane/address.
        write_lane(SUBPANEL0, PIXSEL0, ADDR_B_MAX, 8'h5A);
        read_check(ADDR_B_MAX);

        #200 $finish;
    end

    always begin
        #(SIM_HALF_PERIOD_NS) clk_a <= ~clk_a;
        #(SIM_HALF_PERIOD_NS) clk_b <= ~clk_b;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        ram_b_data_out,
                        1'b0};
    // verilog_format: on
endmodule
