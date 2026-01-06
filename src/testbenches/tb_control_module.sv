// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_control_module;
    `include "row4.svh"
    localparam integer unsigned CMD_BYTES = $bits(cmd_series) / 8;
    localparam types::brightness_level_t EXPECTED_BRIGHTNESS =
        cmd_brightness_3.level.brightness.level;

    localparam time CLK_HALF_PERIOD = time'($rtoi(params::SIM_HALF_PERIOD_NS));

    // === DUT IO ===
    logic clk;
    logic reset;
    logic [7:0]                   data_rx;
    logic                         data_ready_n;
    wire types::rgb_signals_t rgb_enable;
    wire types::brightness_level_t brightness_enable;
    wire types::mem_write_data_t ram_data_out;
    wire types::mem_write_addr_t ram_address;
    wire ram_write_enable;
    wire                         busy;
    wire                         ready_for_data;
    wire ram_clk_enable;
    wire                         watchdog_reset;
    wire                         frame_select;

    integer writes_seen;

    // === DUT ===
    control_module #(
        .WATCHDOG_CONTROL_TICKS(params::WATCHDOG_CONTROL_TICKS),
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk),
        .data_rx(data_rx),
        .data_ready_n(data_ready_n),
        .rgb_enable(rgb_enable),
        .brightness_enable(brightness_enable),
        .ram_data_out(ram_data_out),
        .ram_address(ram_address),
        .ram_write_enable(ram_write_enable),
        .busy(busy),
        .ready_for_data(ready_for_data),
        .ram_clk_enable(ram_clk_enable),
        .frame_select(frame_select),
        .watchdog_reset(watchdog_reset)
    );

    // === Stimulus helpers ===
    task automatic stream_byte(input logic [7:0] byte_value);
        begin
            while (!ready_for_data) @(posedge clk);
            data_rx = byte_value;
            data_ready_n = 1'b0;
            @(posedge clk);
            data_ready_n = 1'b1;
            @(posedge clk);
        end
    endtask

    task automatic stream_cmd_series();
        integer idx;
        begin
            for (idx = 0; idx < CMD_BYTES; idx = idx + 1) begin
                stream_byte(cmd_series[$bits(cmd_series)-1-(idx*8)-:8]);
            end
        end
    endtask

    // === Scoreboard ===
    always @(posedge clk) begin
        if (reset) begin
            writes_seen <= 0;
        end else if (ram_write_enable) begin
            writes_seen <= writes_seen + 1;
        end
    end

    // === Clocking ===
    always begin
        #(CLK_HALF_PERIOD) clk <= !clk;
    end

    // === Test sequence ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_module);
        clk = 0;
        reset = 1;
        data_rx = 8'b0;
        data_ready_n = 1'b1;
        writes_seen = 0;
        @(posedge clk);
        @(posedge clk) reset = 0;
        @(posedge clk);
        stream_cmd_series();
        repeat (64) @(posedge clk);
        repeat (1000) @(posedge clk);
        if (!ready_for_data)
            $fatal(1, "ready_for_data stuck low after streaming commands");
        if (brightness_enable != EXPECTED_BRIGHTNESS)
            $fatal(1, "brightness mismatch: saw 0x%0h expected 0x%0h",
                   brightness_enable, EXPECTED_BRIGHTNESS);
        if (writes_seen == 0)
            $fatal(1, "expected at least one RAM write during command series");
        $finish;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        rgb_enable,
                        brightness_enable,
                        ram_data_out,
                        ram_address,
                        watchdog_reset,
                        frame_select,
                        busy,
                        ram_clk_enable,
                        1'b0};
    // verilog_format: on
endmodule
