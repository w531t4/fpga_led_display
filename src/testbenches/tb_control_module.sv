// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"
`include "tb_cmd_line_state_checker.svh"
`include "tb_spi_streamer.svh"

module tb_control_module;
    `include "row4.svh"
    localparam types::brightness_level_t EXPECTED_BRIGHTNESS =
        cmd_brightness_3.level.brightness.level;

    localparam time CLK_HALF_PERIOD = time'($rtoi(params::SIM_HALF_PERIOD_NS));
    // Mirror the same SPI path used in tb_main (spi_master -> spi_slave -> ff_sync).
    localparam logic [1:0] SPI_CDIV = 2'b0;
    localparam int unsigned SPI_CLK_DIVIDE = 4 << SPI_CDIV;  // spi_master: 00=/4, 01=/8, 10=/16, 11=/32
    localparam int unsigned SPI_BITS_PER_BYTE = $bits(byte);
    localparam longint unsigned SPI_BYTE_CYCLES = longint'(SPI_CLK_DIVIDE) * SPI_BITS_PER_BYTE;
    localparam integer TB_CONTROL_WAIT_SECS = 2;
    localparam integer TB_CONTROL_WAIT_CYCLES = params::ROOT_CLOCK * TB_CONTROL_WAIT_SECS;

    // === DUT IO ===
    logic clk;
    logic reset;
    wire                    [7:0] data_rx;
    wire                          data_ready_n;
    wire types::rgb_signals_t rgb_enable;
    wire types::brightness_level_t brightness_enable;
    wire types::mem_write_data_t ram_data_out;
    wire types::mem_write_addr_t ram_address;
    wire ram_write_enable;
`ifdef USE_SDRAM_FB
    // This testbench never issues COPYFRAME, so the copy-engine arbiter port
    // is left dangling (no consumer) and the write path is always told it's
    // ready, matching this testbench's pre-USE_SDRAM_FB backpressure-free
    // behavior.
    wire copyframe_sdram_req;
    wire copyframe_sdram_we;
    wire types::sdram_word_addr_t copyframe_sdram_addr;
    wire types::sdram_byte_en_t copyframe_sdram_wdata_we;
    wire types::sdram_word_data_t copyframe_sdram_wdata;
`else
    localparam types::mem_write_data_t RAM_DATA_STUB = '0;
    mem_copy_if copy_int();
`endif
    wire                         busy;
    wire                         ready_for_data;
    wire ram_clk_enable;
    wire                         watchdog_reset;
    wire                         frame_select;

    // === SPI model (mirror tb_main) ===
    logic spi_start;
    wire spi_done;
    wire spi_clk_en;
    wire spi_clk;
    wire spi_cs;
    wire spi_mosi;

    integer writes_seen;
    // Track that FILLRECT is both issued and actually entered by the DUT.
    logic saw_fillrect_opcode;
    logic saw_fillrect_state;
    // Sequence completion flag for the tb_main-style state walk.
    logic cmd_line_state_seq_done;
    // Prove we observe at least one IDLE cycle between FILLPANEL and FILLRECT.
    typedef enum logic [1:0] {
        IDLE_SEQ_WAIT_FILLPANEL,
        IDLE_SEQ_WAIT_IDLE,
        IDLE_SEQ_WAIT_FILLRECT,
        IDLE_SEQ_DONE
    } idle_seq_t;
    idle_seq_t idle_seq_state;
    logic saw_idle_between_fillpanel_fillrect;
    logic saw_fillrect_after_idle;

`ifdef DEBUGGER
    debugger_if debug_if (clk);
`endif

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
`ifdef USE_SDRAM_FB
        .sdram_copyframe_req(copyframe_sdram_req),
        .sdram_copyframe_we(copyframe_sdram_we),
        .sdram_copyframe_addr(copyframe_sdram_addr),
        .sdram_copyframe_wdata_we(copyframe_sdram_wdata_we),
        .sdram_copyframe_wdata(copyframe_sdram_wdata),
        .sdram_copyframe_done(1'b0),
        .sdram_copyframe_rdata('0),
`else
        .cmd_copyframe_if(copy_int),
`endif
        .busy(busy),
        .ready_for_data(ready_for_data),
        .ram_clk_enable(ram_clk_enable),
        .watchdog_reset(watchdog_reset),
`ifdef DEBUGGER
        .debug_if(debug_if),
`endif
`ifdef USE_SDRAM_FB
        .sdram_write_ready(1'b1),
        .sdram_write_drained(1'b1),
        .sdram_write_pressure(1'b0),
`endif
        .frame_select(frame_select)
    );
`ifndef USE_SDRAM_FB
    assign copy_int.read_data_in = RAM_DATA_STUB;
`endif

    // === SPI path (mirror tb_main) ===
    tb_spi_streamer #(
        .SPI_CDIV(SPI_CDIV),
        .DATA_BITS($bits(cmd_series)),
        .USE_SLAVE(1'b1)
    ) spi_streamer (
        .clk           (clk),
        .reset         (reset),
        .start         (spi_start),
        .ready_for_data(ready_for_data),
        .data          (cmd_series),
        .done          (spi_done),
        .spi_clk_en    (spi_clk_en),
        .spi_mosi      (spi_mosi),
        .spi_clk       (spi_clk),
        .spi_cs        (spi_cs),
        .data_rx       (data_rx),
        .data_ready_n  (data_ready_n)
    );

    // === Scoreboard ===
    always @(posedge clk) begin
        if (reset) begin
            writes_seen <= 0;
            saw_fillrect_opcode <= 1'b0;
            saw_fillrect_state <= 1'b0;
            idle_seq_state <= IDLE_SEQ_WAIT_FILLPANEL;
            saw_idle_between_fillpanel_fillrect <= 1'b0;
            saw_fillrect_after_idle <= 1'b0;
        end else begin
            if (ram_write_enable) begin
                writes_seen <= writes_seen + 1;
            end
            // Latch when the FILLRECT opcode is driven on the bus.
            if (!data_ready_n && data_rx == cmd::FILLRECT) begin
                saw_fillrect_opcode <= 1'b1;
            end
            // Latch when the DUT FSM actually enters FILLRECT.
            if (dut.cmd_line_state == enums::STATE_CMD_FILLRECT) begin
                saw_fillrect_state <= 1'b1;
            end
            // Measure the sequence: FILLPANEL -> IDLE -> FILLRECT.
            // This confirms an idle cycle exists between the two commands.
            case (idle_seq_state)
                IDLE_SEQ_WAIT_FILLPANEL: begin
                    if (dut.cmd_line_state == enums::STATE_CMD_FILLPANEL) begin
                        idle_seq_state <= IDLE_SEQ_WAIT_IDLE;
                    end
                end
                IDLE_SEQ_WAIT_IDLE: begin
                    if (dut.cmd_line_state == enums::STATE_IDLE) begin
                        saw_idle_between_fillpanel_fillrect <= 1'b1;
                        idle_seq_state <= IDLE_SEQ_WAIT_FILLRECT;
                    end
                end
                IDLE_SEQ_WAIT_FILLRECT: begin
                    if (dut.cmd_line_state == enums::STATE_CMD_FILLRECT) begin
                        saw_fillrect_after_idle <= 1'b1;
                        idle_seq_state <= IDLE_SEQ_DONE;
                    end
                end
                default: begin
                    idle_seq_state <= idle_seq_state;
                end
            endcase
        end
    end

    // === Expected cmd_line_state sequence (shared checker) ===
    tb_cmd_line_state_checker #(
        .SPI_CDIV(SPI_CDIV),
        .READRECT_W(READRECT_W),
        .READRECT_TOTAL_BYTES(READRECT_TOTAL_BYTES)
    ) cmd_line_state_checker (
        .clk          (clk),
        .reset        (reset),
        .cmd_line_state(dut.cmd_line_state),
        .seq_done     (cmd_line_state_seq_done)
    );

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
        spi_start = 1'b0;
        writes_seen = 0;
        @(posedge clk);
        @(posedge clk) reset = 0;
        @(posedge clk);
        `WAIT_ASSERT(clk, ready_for_data === 1'b1, TB_CONTROL_WAIT_CYCLES)
        @(posedge clk) begin
            spi_start = 1'b1;
        end
        wait (spi_done);
        repeat (int'(SPI_BYTE_CYCLES * 2)) @(posedge clk);
        repeat (1000) @(posedge clk);
        if (!ready_for_data)
            $fatal(1, "ready_for_data stuck low after streaming commands");
        if (brightness_enable != EXPECTED_BRIGHTNESS)
            $fatal(1, "brightness mismatch: saw 0x%0h expected 0x%0h",
                   brightness_enable, EXPECTED_BRIGHTNESS);
        if (writes_seen == 0)
            $fatal(1, "expected at least one RAM write during command series");
        if (!saw_fillrect_opcode)
            $fatal(1, "did not observe FILLRECT opcode in command stream");
        if (!saw_fillrect_state)
            $fatal(1, "DUT never entered STATE_CMD_FILLRECT");
        if (!saw_idle_between_fillpanel_fillrect)
            $fatal(1, "idle check: no STATE_IDLE observed between STATE_CMD_FILLPANEL and STATE_CMD_FILLRECT");
        if (!saw_fillrect_after_idle)
            $fatal(1, "idle check: STATE_IDLE observed, but STATE_CMD_FILLRECT occurred before that idle");
        $display("idle check: observed STATE_CMD_FILLPANEL -> STATE_IDLE -> STATE_CMD_FILLRECT");
        // Ensure the full command-state sequence was observed before finishing.
        wait (cmd_line_state_seq_done);
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
                        spi_clk_en,
                        spi_mosi,
                        spi_clk,
                        spi_cs,
                        spi_done,
                        1'b0};
    // verilog_format: on
`ifdef USE_SDRAM_FB
    wire _unused_ok_sdram_copyframe = &{1'b0,
                                        copyframe_sdram_req,
                                        copyframe_sdram_we,
                                        copyframe_sdram_addr,
                                        copyframe_sdram_wdata_we,
                                        copyframe_sdram_wdata,
                                        1'b0};
`endif
endmodule
