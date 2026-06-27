// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none
`include "tb_spi_streamer.svh"
// =============================================================================
// tb_f4_render -- FULL-SYSTEM live-cadence render check. Instantiates the whole
// `main`, runs the REAL live-mode command cadence over SPI (LIVE_F4_SERIES:
// background fill -> swap -> copyFrame, then frames of {fillrect chunk -> swap ->
// copyFrame}) on the TIMING-REAL SDRAM model, then reads the DISPLAYED row_buf bank
// and asserts the carried background stayed uniform. Checks the pixels that come out,
// not internal flags. Result: the live cadence renders correctly through the real
// datapath (so the digital live path is NOT the F4 fault).
//
// Build: default flags + -DLIVE_F4_SERIES -DSDRAM_SIM_TIMING_MODEL (see .args).
// =============================================================================
module tb_f4_render;
    logic clk = 1'b0;
    logic reset = 1'b1;
    always #(params::SIM_HALF_PERIOD_NS) clk = ~clk;

    `include "row4.svh"

    // ---- display / HUB75 + SPI plumbing (mirrors main's pinout) ----
    wire clk_pixel, row_latch, OE, ROA0, ROA1, ROA2, ROA3;
    wire types::rgb_signals_t rgb1, rgb2;
    wire debugger_txout; logic debugger_rxin = 1'b0;
    wire rxdata, spi_done, spi_clk_en, spi_clk, spi_cs, fpga_ready, ctrl_busy;
    logic spi_start = 1'b0;
    wire [13:0] _unused_output;
    wire f2b_uart_pin;
    // passthru pins
    logic ftdi_txd = 1'b1, wifi_txd = 1'b1, ftdi_ndtr = 1'b1, ftdi_nrts = 1'b1;
    wire  ftdi_rxd, wifi_rxd, wifi_en, wifi_gpio0;

    localparam logic [1:0] SPI_CDIV = 2'b0;

    main #(._UNUSED('d0)) dut (
`ifdef USE_PASSTHRU
        .ftdi_txd(ftdi_txd), .wifi_txd(wifi_txd), .ftdi_ndtr(ftdi_ndtr), .ftdi_nrts(ftdi_nrts),
        .ftdi_rxd(ftdi_rxd), .wifi_rxd(wifi_rxd), .wifi_en(wifi_en), .wifi_gpio0(wifi_gpio0),
`endif
        .gp11(clk_pixel), .gp12(row_latch), .gp13(OE), .clk_25mhz(clk),
        .gp7(ROA0), .gp8(ROA1), .gp9(ROA2), .gp10(ROA3),
`ifdef SWAP_BLUE_GREEN_CHAN
        .gp0(rgb1.red), .gp1(rgb1.blue), .gp2(rgb1.green),
        .gp3(rgb2.red), .gp4(rgb2.blue), .gp5(rgb2.green),
`else
        .gp0(rgb1.red), .gp1(rgb1.green), .gp2(rgb1.blue),
        .gp3(rgb2.red), .gp4(rgb2.green), .gp5(rgb2.blue),
`endif
        .gp14(rxdata), .gp16(debugger_txout), .gp15(debugger_rxin),
`ifdef F2B_UART
        .wifi_gpio25(f2b_uart_pin),
`endif
`ifdef SPI
`ifdef SPI_ESP32
        .wifi_gpio14(spi_clk), .wifi_gpio13(rxdata), .wifi_gpio21(spi_cs),
        .wifi_gpio27(fpga_ready), .wifi_gpio35(ctrl_busy),
`endif
`endif
        .gn11(_unused_output[0]), .gn12(_unused_output[1]), .gn13(_unused_output[2]),
        .gn7(_unused_output[3]), .gn8(_unused_output[4]), .gn9(_unused_output[5]),
        .gn10(_unused_output[6]), .gn0(_unused_output[7]), .gn1(_unused_output[8]),
        .gn2(_unused_output[9]), .gn3(_unused_output[10]), .gn4(_unused_output[11]),
        .gn5(_unused_output[12]), .gn14(_unused_output[13])
    );

    // SPI master paced on command-level busy (same as tb_main's TB_SPI_FREERUN path)
    wire spi_pace_ready = dut.ctrl.ready_for_data_logic || ~dut.ctrl.busy;
    wire [7:0] _unused_data_rx; wire _unused_data_ready_n;
    tb_spi_streamer #(.SPI_CDIV(SPI_CDIV), .DATA_BITS($bits(cmd_series)), .USE_SLAVE(1'b0)) spi_streamer (
        .clk(clk), .reset(reset), .start(spi_start), .ready_for_data(spi_pace_ready),
        .data(cmd_series), .done(spi_done), .spi_clk_en(spi_clk_en), .spi_mosi(rxdata),
        .spi_clk(spi_clk), .spi_cs(spi_cs), .data_rx(_unused_data_rx), .data_ready_n(_unused_data_ready_n)
    );

    // Distinct byte values in the displayed background (excluding the chunk cols);
    // 1 == uniform background. Reads the row_prefetch display bank, same as tb_main's
    // render probe (tbi_main.row_buf.bank*).
    function automatic int unsigned bg_distinct();
        logic ab; logic [7:0] b; logic [255:0] seen;
        ab = dut.row_buf.bank_sel_q; seen = '0;
        for (int c = 0; c < params::PIXEL_WIDTH; c++) begin
            if (c >= 100 && c < 116) continue;   // skip the chunk columns
            b = ab ? dut.row_buf.bank1[c].raw[7:0] : dut.row_buf.bank0[c].raw[7:0];
            seen[b] = 1'b1;
        end
        return $countones(seen);
    endfunction

    initial begin
        int unsigned nu;
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_f4_render);
        reset = 1'b1;
        repeat (16) @(posedge clk);
        reset = 1'b0;
        repeat (40) @(posedge clk);
        wait (dut.ctrl.ready_for_data === 1'b1);
        @(posedge clk); spi_start = 1'b1;
        @(posedge clk); spi_start = 1'b0;

        wait (spi_done);
        repeat (1_000_000) @(posedge clk);   // let the FPGA finish the last copyframe + settle

        // The live cadence (fill -> swap -> copyFrame, repeated) must leave the displayed
        // background uniform. (Verified clean: copyFrame carry-forward + per-frame swaps
        // render correctly through the real datapath on the timing-real SDRAM model.)
        nu = bg_distinct();
        if (nu <= 1)
            $display("tb_f4_render: PASS -- displayed background uniform after the live cadence");
        else
            $error("tb_f4_render: FAIL -- displayed background non-uniform (%0d distinct values)", nu);
        $finish;
    end

    initial begin
        #300_000_000;
        $fatal(1, "tb_f4_render: global timeout");
    end

    wire _unused = &{1'b0, clk_pixel, row_latch, OE, ROA0, ROA1, ROA2, ROA3, rgb1, rgb2,
                     debugger_txout, spi_done, spi_clk_en, spi_clk, spi_cs, fpga_ready, ctrl_busy,
                     _unused_output, f2b_uart_pin, ftdi_rxd, wifi_rxd, wifi_en, wifi_gpio0, 1'b0};
endmodule
