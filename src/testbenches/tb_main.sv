// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"
`include "tb_cmd_line_state_checker.svh"
`include "tb_spi_streamer.svh"
module tb_main #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    // Board-agnostic core signals (no physical pin names -- so this testbench is
    // identical for every board). The board wrappers own the pin mapping.
    wire clk_pixel;
    wire row_latch;
    wire OE;
    wire types::row_subpanel_addr_t row_addr_active;
    wire types::rgb_signals_t rgb[NUM_SUBPANELS];
`ifdef DEBUGGER
    wire debugger_txout;
    logic debugger_rxin;
`endif

    logic reset;
    `include "row4.svh"
    localparam integer TB_MAIN_WAIT_SECS = 2;
    localparam integer TB_MAIN_WAIT_CYCLES = params::ROOT_CLOCK * TB_MAIN_WAIT_SECS;
    localparam integer CMD_LINE_STATE_STEP_SECS = 0;  // use nanos below
    localparam integer CMD_LINE_STATE_STEP_NS = 500_000;  // 500us per step
    localparam longint CMD_LINE_STATE_STEP_CYCLES = (CMD_LINE_STATE_STEP_SECS == 0)
        ? ((64'd1 * params::ROOT_CLOCK * CMD_LINE_STATE_STEP_NS) / 1_000_000_000)
        : (64'd1 * params::ROOT_CLOCK * CMD_LINE_STATE_STEP_SECS);
    // Readframe payload is large; compute a safe wait window for the idle transition after it.
    localparam logic [1:0] SPI_CDIV = 2'b0;
    localparam int unsigned SPI_CLK_DIVIDE = 4 << SPI_CDIV;  // spi_master: 00=/4, 01=/8, 10=/16, 11=/32
    localparam int unsigned SPI_BITS_PER_BYTE = $bits(byte);
    localparam longint unsigned SPI_BYTE_CYCLES = longint'(SPI_CLK_DIVIDE) * SPI_BITS_PER_BYTE;
    localparam longint unsigned READFRAME_TOTAL_BYTES =
        longint'(params::PIXEL_WIDTH) * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Add a full row of bytes as margin for SPI idle/finish overheads.
    localparam longint unsigned READFRAME_WAIT_EXTRA_BYTES = longint'(params::PIXEL_WIDTH) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READFRAME_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        (longint'(READFRAME_TOTAL_BYTES + READFRAME_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);
    // Readrect payload is smaller; still compute a safe wait window for pipelined follow-ups.
    localparam longint unsigned READRECT_WAIT_EXTRA_BYTES = longint'(READRECT_W) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READRECT_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        ((longint'(READRECT_TOTAL_BYTES) + READRECT_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);
    logic cmd_line_state_seq_done;

    wire mosi;
    wire spi_done;
    wire spi_clk_en;
    wire spi_clk;
    wire spi_cs;
    logic spi_start;
    wire fpga_ready;
    wire ctrl_busy;
`ifdef USE_STATUS_SPI
    localparam int unsigned STATUS_REPLY_BITS = $bits(types::status_reply_t);
    logic status_sck;
    logic status_cs_n;
    wire status_miso;
    logic [STATUS_REPLY_BITS-1:0] status_cap;
    logic status_read_done;
`endif
`ifdef USE_PASSTHRU
    logic ftdi_txd;
    logic wifi_txd;
    logic ftdi_ndtr;
    logic ftdi_nrts;

    logic ftdi_rxd;
    logic wifi_rxd;
    logic wifi_en;
    logic wifi_gpio0;
`endif

    // Instantiate the board-agnostic core directly (the board wrappers are not
    // part of simulation). Instance name kept as `tbi_main` so the hierarchical
    // probes below (tb_main.tbi_main.*) stay valid.
    display_core #(
        ._UNUSED('d0)
    ) tbi_main (
        .spi_clk           (spi_clk),
        .spi_cs            (spi_cs),
        .mosi              (mosi),
        .ctrl_busy         (ctrl_busy),
        .fpga_ready        (fpga_ready),
`ifdef USE_STATUS_SPI
        .status_sck        (status_sck),
        .status_cs_n       (status_cs_n),
        .status_miso       (status_miso),
`endif
        .rgb               (rgb),
        .clk_pixel         (clk_pixel),
        .row_latch         (row_latch),
        .nOE               (OE),
        .row_address_active(row_addr_active),
`ifdef USE_PASSTHRU
        .ftdi_txd (ftdi_txd),
        .wifi_txd (wifi_txd),
        .ftdi_ndtr(ftdi_ndtr),
        .ftdi_nrts(ftdi_nrts),

        .ftdi_rxd   (ftdi_rxd),
        .wifi_rxd   (wifi_rxd),
        .wifi_en    (wifi_en),
        .wifi_gpio0 (wifi_gpio0),
`endif
`ifdef DEBUGGER
        .debug_uart_rx(debugger_rxin),
        .debug_uart_tx(debugger_txout),
`endif
        .clk_25mhz    (clk)
    );
    // verilog_format: off

    wire _unused_ok_ctrlbusy = &{1'b0,
                                 ctrl_busy,
                                 1'b0};
    // verilog_format: on
    wire [7:0] _unused_data_rx;
    wire _unused_data_ready_n;
    tb_spi_streamer #(
        .SPI_CDIV(SPI_CDIV),
        .DATA_BITS($bits(cmd_series)),
        .USE_SLAVE(1'b0)
    ) spi_streamer (
        .clk           (clk),
        .reset         (reset),
        .start         (spi_start),
        .ready_for_data(tb_main.tbi_main.ctrl.ready_for_data),
        .data          (cmd_series),
        .done          (spi_done),
        .spi_clk_en    (spi_clk_en),
        .spi_mosi      (mosi),
        .spi_clk       (spi_clk),
        .spi_cs        (spi_cs),
        .data_rx       (_unused_data_rx),
        .data_ready_n  (_unused_data_ready_n)
    );
    // verilog_format: off
    wire _unused_ok_ifdef_spi = &{1'b0,
                                  spi_clk_en,
                                  spi_done,
                                  _unused_data_rx,
                                  _unused_data_ready_n,
                                  1'b0};
    // verilog_format: on
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_main);
        clk = 0;
        spi_start = 1'b0;

`ifdef DEBUGGER
        debugger_rxin = 0;
`endif
        reset = 1;
`ifdef USE_PASSTHRU
        // Match the board-level pull-ups on the passthrough inputs.
        ftdi_txd  = 1'b1;
        ftdi_ndtr = 1'b1;
        ftdi_nrts = 1'b1;
        wifi_txd  = 1'b1;
`endif

        // wait for global_reset pulse and its deassertion before releasing tb reset
        `WAIT_ASSERT(clk, tb_main.tbi_main.global_reset === 1'b1, TB_MAIN_WAIT_CYCLES)
        `WAIT_ASSERT(clk, tb_main.tbi_main.global_reset === 1'b0, TB_MAIN_WAIT_CYCLES)
        @(posedge clk) reset = 1'b0;

        // wait until next clk_root goes high
        `WAIT_ASSERT(clk, tb_main.tbi_main.clk_root === 1'b1, TB_MAIN_WAIT_CYCLES)
        // @(posedge tb_main.tbi_main.clk_root);
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.ready_for_data === 1'b1, TB_MAIN_WAIT_CYCLES)
        @(posedge clk) begin
            spi_start = 1;
        end
        @(posedge clk)
        #(($bits(
            cmd_series
        ) + 1000) * params::SIM_HALF_PERIOD_NS * 2 *
            4);  // HALF_CYCLE * 2, to get period. 4, because master spi divides primary clock by 4. 1000 for kicks
        `WAIT_ASSERT(clk, tb_main.tbi_main.row_address_active === types::row_subpanel_addr_t'('b0101),
                     TB_MAIN_WAIT_CYCLES)
        // `WAIT_ASSERT(clk, tb_main.tbi_main.row_address_active !== 4'b0101, TB_MAIN_WAIT_CYCLES)
        // tb_main.tbi_main.ctrl.frame_select_temp = ~tb_main.tbi_main.ctrl.frame_select_temp;
        // tb_main.tbi_main.ctrl.frame_select = ~tb_main.tbi_main.ctrl.frame_select;
        // `WAIT_ASSERT(clk, tb_main.tbi_main.row_address_active === 4'b0101, TB_MAIN_WAIT_CYCLES)
        // `WAIT_ASSERT(clk, tb_main.tbi_main.row_address_active !== 4'b0101, TB_MAIN_WAIT_CYCLES)
        // `WAIT_ASSERT(clk, tb_main.tbi_main.row_address_active === 4'b0101, TB_MAIN_WAIT_CYCLES)
        wait (cmd_line_state_seq_done);
`ifdef USE_STATUS_SPI
        wait (status_read_done);
`endif
        $finish;
    end

`ifdef USE_STATUS_SPI
    // Read the reset-state READSTATUS frame over the status port while command
    // traffic runs on the main bus (the ports are independent). No READSTATUS
    // is issued in cmd_series, so the mailbox must hold the 0xFF sentinel.
    initial begin : assert_status_readport
        status_sck       = 1'b1;  // mode 3: idle high
        status_cs_n      = 1'b1;
        status_read_done = 1'b0;
        `WAIT_ASSERT(clk, fpga_ready === 1'b1, TB_MAIN_WAIT_CYCLES)
        repeat (4) @(posedge clk);
        status_cs_n = 1'b0;
        #(params::SIM_HALF_PERIOD_NS * 4);
        for (int unsigned i = 0; i < STATUS_REPLY_BITS; i = i + 1) begin
            status_sck = 1'b0;
            #(params::SIM_HALF_PERIOD_NS * 4);
            status_cap = {status_cap[STATUS_REPLY_BITS-2:0], status_miso};
            status_sck = 1'b1;
            #(params::SIM_HALF_PERIOD_NS * 4);
        end
        status_cs_n = 1'b1;
        #(params::SIM_HALF_PERIOD_NS * 4);
        if (status_cap !== tb_main.tbi_main.reg_spi_responder_inst.frame)
            $fatal(1, "status port readout mismatch: got %0h, mailbox %0h", status_cap,
                   tb_main.tbi_main.reg_spi_responder_inst.frame);
        if (status_cap[STATUS_REPLY_BITS-1-:8] !== 8'hFF)
            $fatal(1, "status addr sentinel mismatch: got %02x, expected ff", status_cap[STATUS_REPLY_BITS-1-:8]);
        if (status_miso !== 1'b1) $fatal(1, "status_miso should idle high after CS deasserts");
        status_read_done = 1'b1;
    end
`endif

    initial begin : assert_fpga_ready_sequence
        `WAIT_ASSERT(clk, tb_main.tbi_main.global_reset === 1'b1, TB_MAIN_WAIT_CYCLES)
        if (fpga_ready !== 1'b0) $fatal(1, "fpga_ready should be low during global_reset");
        `WAIT_ASSERT(tb_main.tbi_main.clk_root, tb_main.tbi_main.global_reset_sync === 1'b0, TB_MAIN_WAIT_CYCLES)
        repeat (4) begin
            @(posedge tb_main.tbi_main.clk_root);
            if (fpga_ready !== 1'b0) $fatal(1, "fpga_ready should remain low after reset");
        end
        `WAIT_ASSERT(tb_main.tbi_main.clk_root, fpga_ready === 1'b1, TB_MAIN_WAIT_CYCLES)
    end

    // Shared cmd_line_state sequence checker (keep in sync with cmd_series).
    tb_cmd_line_state_checker #(
        .SPI_CDIV(SPI_CDIV),
        .READRECT_W(READRECT_W),
        .READRECT_TOTAL_BYTES(READRECT_TOTAL_BYTES)
    ) cmd_line_state_checker (
        .clk           (clk),
        .reset         (reset),
        .cmd_line_state(tb_main.tbi_main.ctrl.cmd_line_state),
        .seq_done      (cmd_line_state_seq_done)
    );

    initial begin : assert_readrect_pipelining
        // Verify that a readframe command following readrect is accepted without a host-side gap.
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == enums::STATE_CMD_READRECT, TB_MAIN_WAIT_CYCLES)
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == enums::STATE_CMD_READFRAME,
                     int'(READRECT_WAIT_CYCLES))
    end

    initial begin : assert_readframe_pipelining
        // Verify that a readpixel command following readframe is accepted without a host-side gap.
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == enums::STATE_CMD_READFRAME, TB_MAIN_WAIT_CYCLES)
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == enums::STATE_CMD_READPIXEL,
                     int'(READFRAME_WAIT_CYCLES))
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == enums::STATE_IDLE, int'(CMD_LINE_STATE_STEP_CYCLES))
    end
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
`ifdef USE_PASSTHRU
    wire _unused_ok_passthru = &{1'b0,
                                 ftdi_txd,
                                 wifi_txd,
                                 ftdi_ndtr,
                                 ftdi_nrts,

                                 ftdi_rxd,
                                 wifi_rxd,
                                 wifi_en,
                                 wifi_gpio0,
                                 1'b0};
`endif
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        clk_pixel,
                        OE,
                        row_addr_active,
                        rgb[0],
                        rgb[1],
                        row_latch,
                        1'b0};
`ifdef DEBUGGER
    wire _unused_ok_debug = &{1'b0,
                              debugger_txout,
                              1'b0};
`endif
    // verilog_format: on
endmodule
