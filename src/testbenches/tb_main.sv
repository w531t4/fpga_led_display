// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"
module tb_main #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);

    logic clk;
    wire clk_pixel;
    wire row_latch;
    wire OE;
    wire ROA0;
    wire ROA1;
    wire ROA2;
    wire ROA3;
    wire types::rgb_signals_t rgb2;
    wire types::rgb_signals_t rgb1;
    wire debugger_txout;
    logic debugger_rxin;

    logic reset;
    `include "row4.svh"
    localparam integer TB_MAIN_WAIT_SECS = 2;
    localparam integer TB_MAIN_WAIT_CYCLES = params::ROOT_CLOCK * TB_MAIN_WAIT_SECS;
    localparam int CMD_LINE_STATE_SEQ_LEN = 19;
    localparam logic [3:0] CMD_STATE_IDLE = 4'd0;
    localparam logic [3:0] CMD_STATE_READFRAME = 4'd7;
    localparam logic [3:0] CMD_STATE_READPIXEL = 4'd6;
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
    localparam longint unsigned READFRAME_WAIT_EXTRA_BYTES =
        longint'(params::PIXEL_WIDTH) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READFRAME_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        (longint'(READFRAME_TOTAL_BYTES + READFRAME_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);
    logic cmd_line_state_seq_done;

    wire  rxdata;
`ifdef SPI
    logic [7:0] thebyte;
    wire spi_master_txdone;
    integer i;
    logic spi_clk_en;
    wire spi_clk;
    wire spi_cs;
    logic spi_start;
`ifdef SPI_ESP32
    wire fpga_ready;
`endif
`else
    wire uart_rx_dataready;
`endif
    wire [13:0] _unused_output;

    main #(
        ._UNUSED('d0)
    ) tbi_main (
        .gp11       (clk_pixel),
        .gp12       (row_latch),
        .gp13       (OE),
        .clk_25mhz  (clk),
        .gp7        (ROA0),
        .gp8        (ROA1),
        .gp9        (ROA2),
        .gp10       (ROA3),
`ifdef SWAP_BLUE_GREEN_CHAN
        .gp0        (rgb1.red),
        .gp1        (rgb1.blue),
        .gp2        (rgb1.green),
        .gp3        (rgb2.red),
        .gp4        (rgb2.blue),
        .gp5        (rgb2.green),
`else
        .gp0        (rgb1.red),
        .gp1        (rgb1.green),
        .gp2        (rgb1.blue),
        .gp3        (rgb2.red),
        .gp4        (rgb2.green),
        .gp5        (rgb2.blue),
`endif
        .gp14       (rxdata),
        .gp16       (debugger_txout),
        .gp15       (debugger_rxin),
`ifdef SPI
`ifdef SPI_ESP32
        .sd_clk     (spi_clk),             // clk
        .sd_d       ({rxdata, 3'b0}),      // sd_d[3]=mosi
        .wifi_gpio21(spi_cs),
        .wifi_gpio27(fpga_ready),
`else
        .gp17       (rxdata),              // spi miso
        //.gp18()       // spi_mosi
        .gp19       (spi_clk),             // spi_clk
        .gp20       (spi_cs),              // spi_cs
`endif
`endif
        .gn11       (_unused_output[0]),
        .gn12       (_unused_output[1]),
        .gn13       (_unused_output[2]),
        .gn7        (_unused_output[3]),
        .gn8        (_unused_output[4]),
        .gn9        (_unused_output[5]),
        .gn10       (_unused_output[6]),
        .gn0        (_unused_output[7]),
        .gn1        (_unused_output[8]),
        .gn2        (_unused_output[9]),
        .gn3        (_unused_output[10]),
        .gn4        (_unused_output[11]),
        .gn5        (_unused_output[12]),
        .gn14       (_unused_output[13])
    );
    // verilog_format: off
    wire _unused_ok_main = &{1'b0,
                             _unused_output,
                             1'b0};
    // verilog_format: on
`ifdef SPI
    wire [7:0] _unused_ok_rdata;
    spi_master #() spimaster (
        .rstb (~reset),
        .clk  (clk && spi_clk_en),
        .mlb  (1'b1),               // shift msb first
        .start(spi_start),          // indicator to start activity
        .tdat (thebyte),
        .cdiv (SPI_CDIV),           // 2'b0 = divide by 4
        .din  (1'b0),               // data from slave, disable
        .ss   (spi_cs),             // chip select for slave
        .sck  (spi_clk),            // clock to send to slave
        .dout (rxdata),             // data to send to slave
        .done (spi_master_txdone),
        .rdata(_unused_ok_rdata)
    );
    // verilog_format: off
    wire _unused_ok_ifdef_spi = &{1'b0,
                                  1'b0};
    // verilog_format: on
`else
    debugger #(
        .DATA_WIDTH($bits(cmd_series)),
        // use smaller than normal so it doesn't require us to simulate to
        // infinity to see results
        .DIVIDER_TICKS(params::DEBUG_MSGS_PER_SEC_TICKS_SIM),

        // We're using the debugger here as a data transmitter only. Need
        // to transmit at the same speed as the controller is expecting to
        // receive at
        .UART_TICKS_PER_BIT(params::CTRLR_CLK_TICKS_PER_BIT)
    ) mydebug (
        .clk_in(clk),
        .reset(reset),
        .data_in(cmd_series),
        .debug_uart_rx_in(1'b0),
        .debug_command(debug_command),
        .debug_command_pulse(debug_command_pulse),
        .debug_command_busy(debug_command_busy),
        .tx_out(rxdata)
    );
`endif

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
`ifdef FOCUS_TB_MAIN_UART
        // $dumpvars(0, tb_main);
        $dumpvars(1, tb_main.mydebug.data_in);
        $dumpvars(1, tb_main.mydebug.debug_bits);
        $dumpvars(1, tb_main.mydebug.currentState);
        $dumpvars(1, tb_main.mydebug.tx_busy);
        $dumpvars(1, tb_main.mydebug.tx_done);
        $dumpvars(1, tb_main.mydebug.tx_out);
        $dumpvars(1, tb_main.mydebug.tx_start);
        // $dumpvars(1, tb_main.mydebug);
        // $dumpvars(1, tb_main.mydebug.tx_out);
        $dumpvars(1, tb_main.tbi_main.clk_root);
        $dumpvars(1, tb_main.mydebug.debug_command_busy);
        $dumpvars(1, tb_main.mydebug.debug_command_pulse);
        $dumpvars(1, tb_main.tbi_main.rxdata);
        $dumpvars(1, tb_main.tbi_main.ctrl);
`else
        $dumpvars(0, tb_main);
`endif
        clk = 0;
`ifdef SPI
        i = 0;
        thebyte = 8'd0;
        spi_clk_en = 1'b1;
`endif

        debugger_rxin = 0;
        reset = 1;

        // wait for global_reset pulse and its deassertion before releasing tb reset
        `WAIT_ASSERT(clk, tb_main.tbi_main.global_reset === 1'b1, TB_MAIN_WAIT_CYCLES)
        `WAIT_ASSERT(clk, tb_main.tbi_main.global_reset === 1'b0, TB_MAIN_WAIT_CYCLES)
        @(posedge clk) reset = 1'b0;

        // wait until next clk_root goes high
        `WAIT_ASSERT(clk, tb_main.tbi_main.clk_root === 1'b1, TB_MAIN_WAIT_CYCLES)
        // @(posedge tb_main.tbi_main.clk_root);
`ifdef SPI
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.ready_for_data === 1'b1, TB_MAIN_WAIT_CYCLES)
        @(posedge clk) begin
            spi_start = 1;
        end
`endif
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
        $finish;
    end

`ifdef SPI_ESP32
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
`endif

    function automatic logic [3:0] cmd_line_state_expected(input int idx);
        case (idx)
            0: cmd_line_state_expected = 4'd3;
            1: cmd_line_state_expected = 4'd0;
            2: cmd_line_state_expected = 4'd8;
            3: cmd_line_state_expected = 4'd0;
            4: cmd_line_state_expected = 4'd4;
            5: cmd_line_state_expected = 4'd0;
            6: cmd_line_state_expected = 4'd5;
            7: cmd_line_state_expected = 4'd0;
            8: cmd_line_state_expected = 4'd6;
            9: cmd_line_state_expected = 4'd0;
            10: cmd_line_state_expected = 4'd6;
            11: cmd_line_state_expected = 4'd0;
            12: cmd_line_state_expected = 4'd2;
            13: cmd_line_state_expected = 4'd0;
            14: cmd_line_state_expected = 4'd2;
            15: cmd_line_state_expected = 4'd0;
            16: cmd_line_state_expected = 4'd1;
            17: cmd_line_state_expected = 4'd0;
            18: cmd_line_state_expected = CMD_STATE_READFRAME;
            default: cmd_line_state_expected = 4'hf;
        endcase
    endfunction

    initial begin : assert_cmd_line_state_sequence
        integer idx;
        logic [3:0] expected;
        logic [3:0] prev_expected;
        integer unsigned step_cycles;
        cmd_line_state_seq_done = 1'b0;
        // Sentinel for "no previous state yet"; used to avoid readframe idle timing on first step.
        prev_expected = 4'hf;
        for (idx = 0; idx < CMD_LINE_STATE_SEQ_LEN; idx = idx + 1) begin
            expected = cmd_line_state_expected(idx);
            // Allow extra time for the full readframe payload to land before expecting idle.
            if ((expected == CMD_STATE_IDLE) && (prev_expected == CMD_STATE_READFRAME)) begin
                step_cycles = int'(READFRAME_WAIT_CYCLES);
            end else begin
                step_cycles = int'(CMD_LINE_STATE_STEP_CYCLES);
            end
            `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state === expected, int'(step_cycles))
            $display("cmd_line_state[%0d] expected %0d observed %0d at %0t", idx, expected,
                     tb_main.tbi_main.ctrl.cmd_line_state, $time);
            prev_expected = expected;
        end
        cmd_line_state_seq_done = 1'b1;
    end

    initial begin : assert_readframe_pipelining
        // Verify that a readpixel command following readframe is accepted without a host-side gap.
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == CMD_STATE_READFRAME, TB_MAIN_WAIT_CYCLES)
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == CMD_STATE_READPIXEL,
                     int'(READFRAME_WAIT_CYCLES))
        `WAIT_ASSERT(clk, tb_main.tbi_main.ctrl.cmd_line_state == CMD_STATE_IDLE,
                     int'(CMD_LINE_STATE_STEP_CYCLES))
    end
`ifdef SPI
    always begin
        @(posedge spi_master_txdone) begin
            if (tb_main.tbi_main.ctrl.ready_for_data) begin
                if ((i < ($bits(cmd_series) / 8))) begin
                    thebyte <= cmd_series[$bits(cmd_series)-1-(i*8)-:8];
                    i <= i + 1;
                end else if ((i == ($bits(cmd_series) / 8))) begin
                    spi_clk_en = 1'b0;
                end
            end
        end
    end
`endif
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end
    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        clk_pixel,
                        OE,
                        ROA0,
                        ROA1,
                        ROA2,
                        ROA3,
                        rgb1,
                        rgb2,
                        row_latch,
                        debugger_txout,
                        1'b0};
    // verilog_format: on
endmodule
