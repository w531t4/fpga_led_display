// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Validate that two back-to-back READRECT commands write the expected bytes into memory.
module tb_control_module_readrect;
    // === Derived sizing ===
    localparam int unsigned NUM_COL_BYTES = calc::num_bytes_to_contain($bits(types::col_addr_t));
    localparam int unsigned NUM_ROW_BYTES = calc::num_bytes_to_contain($bits(types::row_addr_t));
    localparam int unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL;
    localparam int unsigned MEM_TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * BYTES_PER_PIXEL;
    // Size scoreboard indices to the framebuffer byte count to avoid unused-bit lint noise.
    localparam int unsigned MEM_ADDR_BITS = calc::safe_clog2(MEM_TOTAL_BYTES);
    typedef logic [MEM_ADDR_BITS-1:0] mem_addr_idx_t;

    // === Rectangle A (small, early in the frame) ===
    localparam int unsigned RECT_A_X1 = 2;
    localparam int unsigned RECT_A_Y1 = 1;
    localparam int unsigned RECT_A_W = 3;
    localparam int unsigned RECT_A_H = 2;
    localparam logic [7:0] RECT_A_PAYLOAD_BASE = 8'h10;

    // === Rectangle B (disjoint from A to simplify expected memory checks) ===
    localparam int unsigned RECT_B_X1 = RECT_A_X1 + RECT_A_W + 4;
    localparam int unsigned RECT_B_Y1 = RECT_A_Y1 + 1;
    localparam int unsigned RECT_B_W = 4;
    localparam int unsigned RECT_B_H = 3;
    localparam logic [7:0] RECT_B_PAYLOAD_BASE = 8'h80;

    // === Expected write counts ===
    localparam int unsigned RECT_A_BYTES = RECT_A_W * RECT_A_H * BYTES_PER_PIXEL;
    localparam int unsigned RECT_B_BYTES = RECT_B_W * RECT_B_H * BYTES_PER_PIXEL;
    localparam int unsigned EXPECTED_WRITES = RECT_A_BYTES + RECT_B_BYTES;

    // WAIT_ASSERT uses int loop counters; keep timeouts comfortably in range.
    localparam int unsigned WAIT_CYCLES = (EXPECTED_WRITES * 4) + 128;

    // === DUT IO ===
    logic                                clk;
    logic                                reset;
    logic                          [7:0] data_rx;
    logic                                data_ready_n;
    wire types::rgb_signals_t            rgb_enable;
    wire types::brightness_level_t       brightness_enable;
    wire types::mem_write_data_t         ram_data_out;
    wire types::mem_write_addr_t         ram_address;
    wire                                 ram_write_enable;
`ifdef DOUBLE_BUFFER
    localparam types::mem_write_data_t   RAM_DATA_STUB = '0;
    mem_copy_if                         copy_int();
`endif
    wire                                 busy;
    wire                                 ready_for_data;
    wire                                 ram_clk_enable;
    wire                                 watchdog_reset;
    wire                                 frame_select;

    // === Scoreboard memory ===
    // byte unsigned mem_actual[0:MEM_TOTAL_BYTES-1];
    // byte unsigned mem_expected[0:MEM_TOTAL_BYTES-1];
    byte unsigned                        mem_actual        [MEM_TOTAL_BYTES];
    byte unsigned                        mem_expected      [MEM_TOTAL_BYTES];
    int unsigned                         writes_seen;

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
`ifdef DOUBLE_BUFFER
        .cmd_copyframe_if(copy_int),
`endif
        .busy(busy),
        .ready_for_data(ready_for_data),
        .ram_clk_enable(ram_clk_enable),
`ifdef DOUBLE_BUFFER
        .frame_select(frame_select),
`endif
        .watchdog_reset(watchdog_reset)
    );
`ifdef DOUBLE_BUFFER
    assign copy_int.read_data_in = RAM_DATA_STUB;
`endif

    // === Address helpers ===
    // Convert the split subpanel/row address into a full row index.
    function automatic types::row_addr_t row_from_mem_addr(input types::row_subpanel_addr_t row,
                                                           input types::subpanel_addr_t subpanel);
        row_from_mem_addr = types::row_addr_t'(
            types::uint_t'(row) + (types::uint_t'(subpanel) * params::PIXEL_HALFHEIGHT)
        );
    endfunction

    // Flatten row/col/pixel into a byte index for the scoreboard arrays.
    function automatic mem_addr_idx_t mem_index(input types::row_addr_t row, input types::col_addr_t col,
                                                input types::pixel_addr_t pixel);
        mem_index = mem_addr_idx_t'((int'(row) * params::PIXEL_WIDTH * BYTES_PER_PIXEL)
                                    + (int'(col) * BYTES_PER_PIXEL)
                                    + int'(pixel));
    endfunction

    // Check if a row/col is inside a given rectangle (pixel byte select is handled separately).
    function automatic logic addr_in_rect(input types::row_addr_t row, input types::col_addr_t col,
                                          input int unsigned x1, input int unsigned y1, input int unsigned width,
                                          input int unsigned height);
        addr_in_rect = (int'(row) >= int'(y1))
                       && (int'(row) < int'(y1 + height))
                       && (int'(col) >= int'(x1))
                       && (int'(col) < int'(x1 + width));
    endfunction

    // === Stream helpers ===
    // Model the controller byte handshake used by other control_module testbenches.
    task automatic stream_byte(input logic [7:0] byte_value);
        begin
            while (!ready_for_data) @(posedge clk);
            data_rx = byte_value;
            @(posedge clk);
            // Preload the byte so data_rx_latch is valid before the ready pulse.
            data_ready_n = 1'b0;
            @(posedge clk);
            data_ready_n = 1'b1;
            @(posedge clk);
        end
    endtask

    // Stream a READRECT header + payload with a simple incremental pattern.
    task automatic stream_readrect(input types::col_addr_t x1, input types::row_addr_t y1,
                                   input types::col_addr_t width, input types::row_addr_t height,
                                   input logic [7:0] payload_base);
        types::col_addr_field_t       x1_field;
        types::row_addr_field_t       y1_field;
        types::col_addr_field_t       width_field;
        types::row_addr_field_t       height_field;
        int unsigned                  payload_idx;
        logic                   [7:0] payload_byte;
        begin
            x1_field = types::col_addr_field_t'(x1);
            y1_field = types::row_addr_field_t'(y1);
            width_field = types::col_addr_field_t'(width);
            height_field = types::row_addr_field_t'(height);
            payload_idx = 0;

            // Opcode first, then x1/y1/width/height (big endian for multi-byte fields).
            stream_byte(cmd::READRECT);
            for (int i = 0; i < NUM_COL_BYTES; i++) begin
                stream_byte(x1_field.bytes[(NUM_COL_BYTES-1)-i]);
            end
            for (int i = 0; i < NUM_ROW_BYTES; i++) begin
                stream_byte(y1_field.bytes[(NUM_ROW_BYTES-1)-i]);
            end
            for (int i = 0; i < NUM_COL_BYTES; i++) begin
                stream_byte(width_field.bytes[(NUM_COL_BYTES-1)-i]);
            end
            for (int i = 0; i < NUM_ROW_BYTES; i++) begin
                stream_byte(height_field.bytes[(NUM_ROW_BYTES-1)-i]);
            end

            // Payload: row-major order, pixel bytes descending (matches readrect traversal).
            for (int r = 0; r < int'(height); r++) begin
                for (int c = 0; c < int'(width); c++) begin
                    for (int p = int'(BYTES_PER_PIXEL) - 1; p >= 0; p--) begin
                        payload_byte = byte'(int'(payload_base) + payload_idx);
                        stream_byte(payload_byte);
                        payload_idx = payload_idx + 1;
                    end
                end
            end
        end
    endtask

    // Populate the expected memory contents for a single rectangle.
    task automatic fill_expected_rect(input types::col_addr_t x1, input types::row_addr_t y1,
                                      input types::col_addr_t width, input types::row_addr_t height,
                                      input logic [7:0] payload_base);
        int unsigned   payload_idx;
        mem_addr_idx_t idx;
        begin
            payload_idx = 0;
            for (int r = 0; r < int'(height); r++) begin
                for (int c = 0; c < int'(width); c++) begin
                    for (int p = int'(BYTES_PER_PIXEL) - 1; p >= 0; p--) begin
                        // Cast to int before addition to avoid width-expansion lint.
                        idx = mem_index(types::row_addr_t'(int'(y1) + r), types::col_addr_t'(int'(x1) + c),
                                        types::pixel_addr_t'(p));
                        mem_expected[idx] = byte'(int'(payload_base) + payload_idx);
                        payload_idx = payload_idx + 1;
                    end
                end
            end
        end
    endtask

    // === Memory monitor ===
    // Capture every write pulse and verify it matches the expected model.
    always @(posedge clk) begin
        if (reset) begin
            writes_seen <= 0;
        end else if (ram_clk_enable && ram_write_enable) begin
            types::row_addr_t full_row;
            types::col_addr_t col;
            types::pixel_addr_t pix;
            mem_addr_idx_t idx;
            full_row = row_from_mem_addr(ram_address.row, ram_address.subpanel);
            col = ram_address.col;
            pix = ram_address.pixel;
            idx = mem_index(full_row, col, pix);

            // Bounds and region checks keep the test focused on READRECT behavior.
            assert (int'(full_row) < int'(params::PIXEL_HEIGHT))
            else $fatal(1, "Row out of range: %0d", full_row);
            assert (int'(col) < int'(params::PIXEL_WIDTH))
            else $fatal(1, "Column out of range: %0d", col);
            assert (int'(pix) < int'(BYTES_PER_PIXEL))
            else $fatal(1, "Pixel byte out of range: %0d", pix);
            assert (addr_in_rect(
                full_row, col, RECT_A_X1, RECT_A_Y1, RECT_A_W, RECT_A_H
            ) || addr_in_rect(
                full_row, col, RECT_B_X1, RECT_B_Y1, RECT_B_W, RECT_B_H
            ))
            else $fatal(1, "Write outside rectangles at row=%0d col=%0d", full_row, col);

            // Compare against the expected byte for this address.
            assert (ram_data_out === mem_expected[idx])
            else
                $fatal(
                    1,
                    "Data mismatch at idx %0d row=%0d col=%0d pix=%0d write=%0d: expected 0x%0h got 0x%0h",
                    idx,
                    full_row,
                    col,
                    pix,
                    writes_seen,
                    mem_expected[idx],
                    ram_data_out
                );

            mem_actual[idx] <= ram_data_out;
            writes_seen <= writes_seen + 1;
        end
    end

    // === Test sequence ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_module_readrect);
        clk = 0;
        reset = 1;
        data_rx = 8'b0;
        data_ready_n = 1'b1;

        // Initialize scoreboard memories to zero before building expected data.
        for (int i = 0; i < MEM_TOTAL_BYTES; i++) begin
            mem_actual[i]   = 8'h00;
            mem_expected[i] = 8'h00;
        end

        // Sanity checks for test dimensions and command field sizes.
        if (NUM_ROW_BYTES != 1) $fatal(1, "READRECT assumes 1-byte row fields; got %0d", NUM_ROW_BYTES);
        if ((RECT_A_X1 + RECT_A_W) > params::PIXEL_WIDTH) $fatal(1, "RECT_A exceeds width");
        if ((RECT_B_X1 + RECT_B_W) > params::PIXEL_WIDTH) $fatal(1, "RECT_B exceeds width");
        if ((RECT_A_Y1 + RECT_A_H) > params::PIXEL_HEIGHT) $fatal(1, "RECT_A exceeds height");
        if ((RECT_B_Y1 + RECT_B_H) > params::PIXEL_HEIGHT) $fatal(1, "RECT_B exceeds height");

        // Build the expected memory image in the same order as the commands will be sent.
        fill_expected_rect(types::col_addr_t'(RECT_A_X1), types::row_addr_t'(RECT_A_Y1), types::col_addr_t'(RECT_A_W),
                           types::row_addr_t'(RECT_A_H), RECT_A_PAYLOAD_BASE);
        fill_expected_rect(types::col_addr_t'(RECT_B_X1), types::row_addr_t'(RECT_B_Y1), types::col_addr_t'(RECT_B_W),
                           types::row_addr_t'(RECT_B_H), RECT_B_PAYLOAD_BASE);

        @(posedge clk);
        @(posedge clk) reset = 0;

        // Stream two READRECT commands back-to-back using the normal byte handshake.
        stream_readrect(types::col_addr_t'(RECT_A_X1), types::row_addr_t'(RECT_A_Y1), types::col_addr_t'(RECT_A_W),
                        types::row_addr_t'(RECT_A_H), RECT_A_PAYLOAD_BASE);
        stream_readrect(types::col_addr_t'(RECT_B_X1), types::row_addr_t'(RECT_B_Y1), types::col_addr_t'(RECT_B_W),
                        types::row_addr_t'(RECT_B_H), RECT_B_PAYLOAD_BASE);

        // Wait for all payload writes to be observed (custom loop to print counts on failure).
        begin
            int unsigned wait_cycles;
            for (
                wait_cycles = 0;
                (wait_cycles < WAIT_CYCLES) && (writes_seen != EXPECTED_WRITES);
                wait_cycles = wait_cycles + 1
            ) begin
                @(posedge clk);
            end
            if (writes_seen != EXPECTED_WRITES) begin
                $fatal(1, "Timeout after %0d cycles: writes_seen=%0d expected=%0d", wait_cycles, writes_seen,
                       EXPECTED_WRITES);
            end
        end

        // Final sweep: ensure every byte matches the expected image.
        for (int i = 0; i < MEM_TOTAL_BYTES; i++) begin
            if (mem_actual[i] !== mem_expected[i]) begin
                $fatal(1, "Memory mismatch at idx %0d: expected 0x%0h got 0x%0h", i, mem_expected[i], mem_actual[i]);
            end
        end
        $finish;
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
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
