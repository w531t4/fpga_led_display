// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

`ifdef DOUBLE_BUFFER
// Integration timing check: readframe -> toggle frame -> copyframe.
// Focuses on command duration (busy cycles) rather than data correctness.
module tb_control_module_copyframe_readframe;
    // === Timing model ===
    // Total bytes in a full frame (readframe payload size).
    localparam int unsigned TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Model the ESP32 SPI byte cadence relative to clk_root.
    localparam int unsigned SPI_BITS_PER_BYTE = $bits(byte);
    localparam int unsigned SPI_BIT_RATE_HZ = 80_000_000;
    localparam longint unsigned SPI_BYTE_CYCLES =
        (longint'(params::ROOT_CLOCK) * longint'(SPI_BITS_PER_BYTE)
         + longint'(SPI_BIT_RATE_HZ) - 1) / longint'(SPI_BIT_RATE_HZ);
    // Reserve one cycle to preload data_rx before the ready pulse.
    localparam longint unsigned SPI_BYTE_GAP_CYCLES = (SPI_BYTE_CYCLES > 1) ? (SPI_BYTE_CYCLES - 2) : 0;

    // Allow an extra row worth of bytes as margin for command completion.
    localparam int unsigned READFRAME_WAIT_EXTRA_BYTES = params::PIXEL_WIDTH;
    localparam longint unsigned READFRAME_WAIT_CYCLES =
        (longint'(TOTAL_BYTES) + longint'(READFRAME_WAIT_EXTRA_BYTES)) * SPI_BYTE_CYCLES;

`ifdef USE_SDRAM_FB
    // The copy engine moves one SDRAM word at a time; this standalone testbench
    // has no real arbiter/LiteDRAM, so a behavioral mock answers each word's
    // req/done round trip after a fixed latency. That latency is an invented
    // unit-test constant (see params::SDRAM_MOCK_READ_LATENCY), not real SDRAM
    // timing, so copyframe_cycles measured here can't be compared against
    // readframe_cycles the way the old engine's real 1-byte/clk throughput
    // could -- see the PLAN.md 3.4 note on this. Size the timeout generously
    // in words instead of bytes.
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned BUFFER_WORDS =
        calc::num_sdram_buffer_words(params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS, PIXEL_BYTES,
                                      params::SDRAM_WORD_BYTES);
    localparam int unsigned CYCLES_PER_WORD_PHASE = params::SDRAM_MOCK_READ_LATENCY + 3;
    localparam longint unsigned COPYFRAME_WAIT_CYCLES =
        longint'(BUFFER_WORDS) * 2 * longint'(CYCLES_PER_WORD_PHASE) + 32;
`else
    // Keep in sync with control_cmd_copyframe READ_LATENCY.
    localparam int unsigned COPY_READ_LATENCY = 5;
    localparam int unsigned COPY_PIPE_FLUSH_CYCLES = COPY_READ_LATENCY + 4;
    localparam longint unsigned COPYFRAME_WAIT_CYCLES = longint'(TOTAL_BYTES) + longint'(COPY_PIPE_FLUSH_CYCLES);

    // Require copyframe to complete within 20% of readframe cycles.
    localparam int unsigned COPYFRAME_RATIO_DENOM = 5;
`endif

    // === Testbench scaffolding ===
    logic                                clk;
    logic                                reset;
    logic                          [7:0] data_rx;
    logic                                data_ready_n;

    wire types::rgb_signals_t            rgb_enable;
    wire types::brightness_level_t       brightness_enable;
    wire types::mem_write_data_t         ram_data_out;
    wire types::mem_write_addr_t         ram_address;
    wire                                 ram_write_enable;
    wire                                 busy;
    wire                                 ready_for_data;
    wire                                 ram_clk_enable;
    wire                                 frame_select;
`ifdef DEBUGGER
    debugger_if debug_if (clk);
`endif
`ifdef USE_WATCHDOG
    wire watchdog_reset;
`endif

    // === Copy engine wiring ===
`ifdef USE_SDRAM_FB
    // Single-client behavioral SDRAM mock (no real arbiter in this standalone
    // testbench): answers each req with sdram_done after a fixed latency, same
    // shape as tb_control_cmd_copyframe's mock. Data values don't matter here
    // (timing is the focus of this test), so reads return a fixed pattern.
    wire copyframe_sdram_req;
    wire copyframe_sdram_we;
    wire types::sdram_word_addr_t copyframe_sdram_addr;
    wire types::sdram_byte_en_t copyframe_sdram_wdata_we;
    wire types::sdram_word_data_t copyframe_sdram_wdata;
    logic copyframe_sdram_done;
    types::sdram_word_data_t copyframe_sdram_rdata;

    enums::sdram_mock_state_e mock_state_q;
    types::sdram_mock_wait_count_t mock_wait_q;
    logic mock_we_q;
    logic mock_write_done_pulse;

    always_ff @(posedge clk) begin
        if (reset) begin
            mock_state_q <= enums::SDRAM_MOCK_IDLE;
            mock_wait_q <= '0;
            copyframe_sdram_done <= 1'b0;
            mock_write_done_pulse <= 1'b0;
        end else begin
            copyframe_sdram_done <= 1'b0;
            mock_write_done_pulse <= 1'b0;
            case (mock_state_q)
                enums::SDRAM_MOCK_IDLE: begin
                    if (copyframe_sdram_req) begin
                        mock_we_q <= copyframe_sdram_we;
                        mock_wait_q <= types::sdram_mock_wait_count_t'(params::SDRAM_MOCK_READ_LATENCY);
                        mock_state_q <= enums::SDRAM_MOCK_WAIT;
                    end
                end
                enums::SDRAM_MOCK_WAIT: begin
                    if (mock_wait_q == 0) begin
                        copyframe_sdram_done <= 1'b1;
                        if (mock_we_q) begin
                            mock_write_done_pulse <= 1'b1;
                        end else begin
                            copyframe_sdram_rdata <= types::sdram_word_data_t'('0);
                        end
                        mock_state_q <= enums::SDRAM_MOCK_SETTLE;
                    end else begin
                        mock_wait_q <= mock_wait_q - 1'b1;
                    end
                end
                enums::SDRAM_MOCK_SETTLE: mock_state_q <= enums::SDRAM_MOCK_IDLE;
                default: mock_state_q <= enums::SDRAM_MOCK_IDLE;
            endcase
        end
    end
`else
    mem_copy_if copy_int();
    // Stub the front-buffer data; timing is the focus of this test.
    localparam types::mem_write_data_t COPY_DATA_STUB = '0;
`endif

    // WAIT_ASSERT uses 32-bit loop counters; keep timeouts within int range.
    localparam int unsigned READFRAME_WAIT_CYCLES_INT = int'(READFRAME_WAIT_CYCLES);
    localparam int unsigned COPYFRAME_WAIT_CYCLES_INT = int'(COPYFRAME_WAIT_CYCLES);
    localparam int unsigned READY_WAIT_CYCLES_INT = int'(SPI_BYTE_CYCLES);

    // === Measurement state ===
    longint unsigned cycle_count;
    longint unsigned readframe_cycles;
    longint unsigned copyframe_cycles;
    longint unsigned readframe_start_cycle;
    longint unsigned readframe_end_cycle;
    longint unsigned copyframe_start_cycle;
    longint unsigned copyframe_end_cycle;
    typedef logic [$clog2(TOTAL_BYTES + 1)-1:0] byte_count_t;
    byte_count_t readframe_write_count;
    byte_count_t copyframe_write_count;
    logic        measure_readframe;
    logic        measure_copyframe;
    logic        readframe_done;
    logic        copyframe_done;

    // === DUT: control module ===
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
        .sdram_copyframe_done(copyframe_sdram_done),
        .sdram_copyframe_rdata(copyframe_sdram_rdata),
`else
        .cmd_copyframe_if(copy_int),
`endif
        .busy(busy),
        .ready_for_data(ready_for_data),
        .ram_clk_enable(ram_clk_enable),
`ifdef DEBUGGER
        .debug_if(debug_if),
`endif
`ifdef USE_WATCHDOG
        .watchdog_reset(watchdog_reset),
`endif
`ifdef USE_SDRAM_FB
        .sdram_write_ready(1'b1),
        .sdram_write_drained(1'b1),
        .sdram_write_pressure(1'b0),
`endif
        .frame_select(frame_select)
    );
`ifndef USE_SDRAM_FB
    assign copy_int.read_data_in = COPY_DATA_STUB;
`endif

    // === Byte-stream helpers (SPI cadence model) ===
    task automatic wait_ready_for_data;
        // Prevent overrun if ready_for_data is ever deasserted.
        while (!ready_for_data) @(posedge clk);
    endtask

    task automatic send_spi_byte(input logic [7:0] byte_value);
        // Model a single SPI byte becoming available to the controller.
        begin
            wait_ready_for_data();
            data_rx = byte_value;
            // Preload the byte so the controller latch is valid before the ready pulse.
            @(posedge clk);
            data_ready_n = 1'b0;
            @(posedge clk);
            data_ready_n = 1'b1;
            for (longint unsigned gap = 0; gap < SPI_BYTE_GAP_CYCLES; gap++) begin
                @(posedge clk);
            end
        end
    endtask

    task automatic send_readframe_payload;
        // Stream the entire frame payload at the modeled SPI rate.
        byte payload_byte;
        for (int unsigned idx = 0; idx < TOTAL_BYTES; idx++) begin
            payload_byte = byte'(idx);
            send_spi_byte(payload_byte);
        end
    endtask

    // === Command runners ===
    task automatic run_readframe(output longint unsigned cycles_out);
        begin
            readframe_cycles = 0;
            readframe_done = 1'b0;
            measure_readframe = 1'b0;
            readframe_write_count = '0;
            send_spi_byte(cmd::READFRAME);
            `WAIT_ASSERT(clk, busy == 1'b1, READY_WAIT_CYCLES_INT)
            measure_readframe = 1'b1;
            send_readframe_payload();
            `WAIT_ASSERT(clk, readframe_done == 1'b1, READFRAME_WAIT_CYCLES_INT)
            readframe_cycles = readframe_end_cycle - readframe_start_cycle;
            cycles_out = readframe_cycles;
        end
    endtask

    task automatic run_copyframe(output longint unsigned cycles_out);
        begin
            copyframe_cycles = 0;
            copyframe_done = 1'b0;
            measure_copyframe = 1'b1;
            copyframe_write_count = '0;
            send_spi_byte(cmd::COPY_FRAME);
            `WAIT_ASSERT(clk, copyframe_done == 1'b1, COPYFRAME_WAIT_CYCLES_INT)
            copyframe_cycles = copyframe_end_cycle - copyframe_start_cycle;
            cycles_out = copyframe_cycles;
        end
    endtask

    // === Timing measurement ===
    always @(posedge clk) begin
        if (reset) begin
            cycle_count <= 0;
            readframe_cycles <= 0;
            copyframe_cycles <= 0;
            readframe_start_cycle <= 0;
            readframe_end_cycle <= 0;
            copyframe_start_cycle <= 0;
            copyframe_end_cycle <= 0;
            readframe_write_count <= '0;
            copyframe_write_count <= '0;
            measure_readframe <= 1'b0;
            measure_copyframe <= 1'b0;
            readframe_done <= 1'b0;
            copyframe_done <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 1;
            if (measure_readframe && ~data_ready_n) begin
                if (readframe_write_count == '0) begin
                    readframe_start_cycle <= cycle_count;
                end
                if (readframe_write_count == byte_count_t'(TOTAL_BYTES - 1)) begin
                    readframe_end_cycle <= cycle_count;
                    readframe_done <= 1'b1;
                    measure_readframe <= 1'b0;
                end
                readframe_write_count <= readframe_write_count + 1'b1;
            end
`ifdef USE_SDRAM_FB
            if (measure_copyframe && mock_write_done_pulse) begin
                if (copyframe_write_count == '0) begin
                    copyframe_start_cycle <= cycle_count;
                end
                if (copyframe_write_count == byte_count_t'(BUFFER_WORDS - 1)) begin
                    copyframe_end_cycle <= cycle_count;
                    copyframe_done <= 1'b1;
                    measure_copyframe <= 1'b0;
                end
                copyframe_write_count <= copyframe_write_count + 1'b1;
            end
`else
            if (measure_copyframe && copy_int.write_enable) begin
                if (copyframe_write_count == '0) begin
                    copyframe_start_cycle <= cycle_count;
                end
                if (copyframe_write_count == byte_count_t'(TOTAL_BYTES - 1)) begin
                    copyframe_end_cycle <= cycle_count;
                    copyframe_done <= 1'b1;
                    measure_copyframe <= 1'b0;
                end
                copyframe_write_count <= copyframe_write_count + 1'b1;
            end
`endif
        end
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // === Test sequence ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_module_copyframe_readframe);
        clk = 0;
        reset = 1;
        data_rx = 8'h00;
        data_ready_n = 1'b1;
        measure_readframe = 1'b0;
        measure_copyframe = 1'b0;
        readframe_done = 1'b0;
        copyframe_done = 1'b0;
        @(posedge clk);
        @(posedge clk) reset = 0;

        // Ensure the controller is idle before starting the command sequence.
        `WAIT_ASSERT(clk, ready_for_data == 1'b1, READY_WAIT_CYCLES_INT)

        // 1) readframe at modeled SPI pace.
        run_readframe(readframe_cycles);

        // 2) swap (toggle frame_select) and confirm it takes effect.
        begin
            logic frame_select_before;
            frame_select_before = frame_select;
            send_spi_byte(cmd::TOGGLE_FRAME);
            `WAIT_ASSERT(clk, frame_select != frame_select_before, READY_WAIT_CYCLES_INT)
        end

        // 3) copyframe (internal copy engine).
        run_copyframe(copyframe_cycles);

        // Report cycle counts either way.
        $display("readframe_cycles=%0d copyframe_cycles=%0d", readframe_cycles, copyframe_cycles);
        assert (copyframe_cycles > 0 && readframe_cycles > 0)
        else $fatal(1, "Measured cycle counts are invalid");
`ifndef USE_SDRAM_FB
        // Require copyframe to complete within 20% of readframe cycles. Only
        // meaningful for the real (non-mocked) byte-pipelined engine -- see
        // the USE_SDRAM_FB localparam block above for why this doesn't carry
        // over to the SDRAM-arbiter engine, whose measured speed here is an
        // artifact of a mock timing constant, not real SDRAM/arbiter timing.
        assert ((copyframe_cycles * COPYFRAME_RATIO_DENOM) <= readframe_cycles)
        else
            $fatal(
                1,
                "copyframe cycles %0d exceed %0d%% of readframe cycles %0d",
                copyframe_cycles,
                100 / COPYFRAME_RATIO_DENOM,
                readframe_cycles
            );
`endif

        repeat (5) @(posedge clk);
        $finish;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        rgb_enable,
                        brightness_enable,
                        ram_data_out,
                        ram_address,
                        ram_write_enable,
                        busy,
                        ram_clk_enable,
                        1'b0};
`ifdef USE_WATCHDOG
    wire _unused_ok_watchdog = &{1'b0,
                                 watchdog_reset,
                                 1'b0};
`endif
`ifdef USE_SDRAM_FB
    wire _unused_ok_sdram_copyframe = &{1'b0,
                                        copyframe_sdram_addr,
                                        copyframe_sdram_wdata_we,
                                        copyframe_sdram_wdata,
                                        1'b0};
`endif
    // verilog_format: on
endmodule
`else
module tb_control_module_copyframe_readframe;
    initial begin
        $fatal(1, "tb_control_module_copyframe_readframe requires DOUBLE_BUFFER");
    end
endmodule
`endif
