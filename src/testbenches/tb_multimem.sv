// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
module tb_multimem #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params::PIXEL_HALFHEIGHT,
    parameter real SIM_HALF_PERIOD_NS = params::SIM_HALF_PERIOD_NS,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam int ADDR_A_BITS = calc::num_address_a_bits(PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT);
    localparam int ADDR_B_BITS = calc::num_address_b_bits(PIXEL_WIDTH, PIXEL_HALFHEIGHT);
    localparam int DATA_A_BITS = calc::num_data_a_bits();
    localparam int DATA_B_BITS = calc::num_data_b_bits(PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT);
    localparam int SUBPANEL_BITS = calc::num_subpanelselect_bits(PIXEL_HEIGHT, PIXEL_HALFHEIGHT);
    localparam int PIXELSEL_BITS = calc::num_pixelcolorselect_bits(BYTES_PER_PIXEL);
    localparam int STRUCTURE_BITS = calc::num_structure_bits(
        PIXEL_WIDTH, PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT
    );
    localparam int LANES = (1 << STRUCTURE_BITS);
    localparam int DEPTH_B = (1 << ADDR_B_BITS);
    localparam logic [SUBPANEL_BITS-1:0] SUBPANEL0 = {SUBPANEL_BITS{1'b0}};
    localparam logic [SUBPANEL_BITS-1:0] SUBPANEL1 = {{(SUBPANEL_BITS - 1) {1'b0}}, 1'b1};
    localparam logic [PIXELSEL_BITS-1:0] PIXSEL0 = {PIXELSEL_BITS{1'b0}};
    localparam logic [PIXELSEL_BITS-1:0] PIXSEL1 = {{(PIXELSEL_BITS - 1) {1'b0}}, 1'b1};
    localparam logic [ADDR_B_BITS-1:0] ADDR_B_MAX = {ADDR_B_BITS{1'b1}};
    localparam logic [ADDR_B_BITS-1:0] ADDR_B_TOP0_MAX = {1'b0, {ADDR_B_BITS - 1{1'b1}}};

    logic clk_a;
    logic clk_b;
    logic [ADDR_A_BITS-1:0] ram_a_address;
    logic [ADDR_B_BITS-1:0] ram_b_address;
    logic [DATA_A_BITS-1:0] ram_a_data_in;
    logic ram_a_clk_enable;
    logic ram_b_clk_enable;
    logic ram_a_wr;
    wire [DATA_B_BITS-1:0] ram_b_data_out;
    logic ram_a_reset;
    logic ram_b_reset;

    wire [DATA_A_BITS-1:0] _unused_ok_QA;
    logic [DATA_A_BITS-1:0] model_mem[LANES][DEPTH_B];

    multimem #(
        .BYTES_PER_PIXEL(BYTES_PER_PIXEL),
        .PIXEL_HEIGHT(PIXEL_HEIGHT),
        .PIXEL_WIDTH(PIXEL_WIDTH),
        .PIXEL_HALFHEIGHT(PIXEL_HALFHEIGHT),
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

    function automatic logic [ADDR_A_BITS-1:0] pack_addr_a(input logic [SUBPANEL_BITS-1:0] subpanel,
                                                           input logic [ADDR_B_BITS-1:0] addr_b,
                                                           input logic [PIXELSEL_BITS-1:0] pixel_sel);
        pack_addr_a = {subpanel, addr_b, pixel_sel};
    endfunction

    function automatic logic [STRUCTURE_BITS-1:0] lane_index(input logic [SUBPANEL_BITS-1:0] subpanel,
                                                             input logic [PIXELSEL_BITS-1:0] pixel_sel);
        lane_index = {subpanel, pixel_sel};
    endfunction

    function automatic logic [DATA_B_BITS-1:0] build_expected(input logic [ADDR_B_BITS-1:0] addr_b);
        logic [DATA_B_BITS-1:0] expected;
        expected = '0;
        for (int lane = 0; lane < LANES; lane = lane + 1) begin
            expected[lane*DATA_A_BITS+:DATA_A_BITS] = model_mem[lane][addr_b];
        end
        build_expected = expected;
    endfunction

    task automatic write_lane(input logic [SUBPANEL_BITS-1:0] subpanel, input logic [PIXELSEL_BITS-1:0] pixel_sel,
                              input logic [ADDR_B_BITS-1:0] addr_b, input logic [DATA_A_BITS-1:0] data);
        logic [STRUCTURE_BITS-1:0] lane_idx;
        logic [ADDR_A_BITS-1:0] addr_a;
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

    task automatic read_check(input logic [ADDR_B_BITS-1:0] addr_b);
        logic [DATA_B_BITS-1:0] expected;
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
