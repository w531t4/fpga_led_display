// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

// Verifies the copy engine clones only the dirty rectangle (25% of the frame).
module tb_control_cmd_copyframe_dirty25;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned TOTAL_BYTES = params::PIXEL_WIDTH * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Copy engine is 1 byte/clk after the read pipeline fills.
    localparam int unsigned COPY_READ_LATENCY = 5;
    localparam int unsigned COPY_PIPE_FLUSH_CYCLES = COPY_READ_LATENCY + 4;
    // Dirty rectangle is 25% of the frame (half width x half height).
    localparam int unsigned DIRTY_WIDTH = params::PIXEL_WIDTH / 2;
    localparam int unsigned DIRTY_HEIGHT = params::PIXEL_HEIGHT / 2;
    localparam int unsigned DIRTY_TOTAL_BYTES = DIRTY_WIDTH * DIRTY_HEIGHT * params::BYTES_PER_PIXEL;
    localparam int unsigned COPY_CYCLES_MAX = DIRTY_TOTAL_BYTES + COPY_PIPE_FLUSH_CYCLES;
    // Port-B read latency is driven by the framebuffer fetch timing.
    localparam int unsigned READ_LATENCY_B = params::FB_FETCH_TIMEOUT_TICKS + 1;
    // Seed values to ensure the front/back patterns are different pre-copy.
    localparam types::mem_write_data_t FRONT_SEED = 'hA5;
    localparam types::mem_write_data_t BACK_SEED = 'h3C;
    // Last address in the copy sequence (row-major, pixel counts down to 0).
    localparam types::pixel_addr_t LAST_PIXEL_COUNTDOWN = types::pixel_addr_t'(0);
    // Dirty-rectangle bounds for the test (top-left quarter).
    localparam types::row_addr_t DIRTY_ROW_MIN = types::row_addr_t'(0);
    localparam types::col_addr_t DIRTY_COL_MIN = types::col_addr_t'(0);
    localparam types::row_addr_t DIRTY_ROW_MAX = types::row_addr_t'(DIRTY_HEIGHT - 1);
    localparam types::col_addr_t DIRTY_COL_MAX = types::col_addr_t'(DIRTY_WIDTH - 1);
    // Endpoint coordinates for the test pattern (row within subpanel, pixel counts up).
    localparam types::row_subpanel_addr_t FIRST_ROW_SUBPANEL = types::row_subpanel_addr_t'(0);
    localparam types::col_addr_t FIRST_COL = types::col_addr_t'(0);
    localparam types::subpanel_addr_t FIRST_SUBPANEL = types::subpanel_addr_t'(0);
    localparam types::pixel_addr_t FIRST_PIXEL_BYTE = types::pixel_addr_t'(0);
    localparam types::row_subpanel_addr_t LAST_ROW_SUBPANEL =
        types::row_subpanel_addr_t'(params::PIXEL_HALFHEIGHT - 1);
    localparam types::col_addr_t LAST_COL_SUBPANEL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    localparam types::subpanel_addr_t LAST_SUBPANEL = types::subpanel_addr_t'(NUM_SUBPANELS - 1);
    localparam types::pixel_addr_t LAST_PIXEL_BYTE = types::pixel_addr_t'(params::BYTES_PER_PIXEL - 1);

    // === Testbench scaffolding ===
    logic                       clk;
    logic                       reset;
    logic                       copy_enable;
    logic                       init_mode;
    logic                       init_we_frame1;
    logic                       init_we_frame2;
    types::mem_write_addr_t     init_addr;
    types::mem_write_data_t     init_data;
    logic                       frame_select;
    // Dirty-rect inputs (drive full-frame bounds for this test).
    logic                       dirty_valid;
    types::row_addr_t           dirty_row_min;
    types::row_addr_t           dirty_row_max;
    types::col_addr_t           dirty_col_min;
    types::col_addr_t           dirty_col_max;

    // === Copy engine wiring ===
    mem_copy_if                copy_int();
    wire                        cmd_copyframe_done;

    logic                       copy_ram_access_start_latch;
    wire                        copy_ram_clk_enable;

    wire types::mem_write_addr_t ram_a_address_frame1;
    wire types::mem_write_addr_t ram_a_address_frame2;
    wire types::mem_write_data_t ram_a_data_in_frame1;
    wire types::mem_write_data_t ram_a_data_in_frame2;
    wire                         ram_a_clk_enable;

    // === Port-B verification wiring ===
    types::mem_read_addr_t ram_b_address;
    logic                  ram_b_clk_enable;

    wire types::mem_write_data_t ram_a_data_out_frame1;
    wire types::mem_write_data_t ram_a_data_out_frame2;
    wire types::mem_write_data_t ram_a_data_out_front;
    wire types::mem_read_data_t  ram_b_data_out_frame1;
    wire types::mem_read_data_t  ram_b_data_out_frame2;

    // === Done semantics + cycle tracking ===
    logic                       done_prev;
    logic                       last_write_seen;
    logic                       pending_post_done_check;
    int                         done_pulses;
    longint unsigned            cycle_count;
    longint unsigned            copyframe_start_cycle;
    longint unsigned            copyframe_cycles;
    logic                       measure_copyframe;
    logic                       copy_enable_prev;

    // === Helper functions/tasks ===
    function automatic types::mem_write_data_t pattern_first_byte(input types::mem_write_data_t seed);
        // Force a deterministic non-linear value at the first byte.
        pattern_first_byte = ~seed;
    endfunction

    function automatic types::mem_write_data_t pattern_last_byte(input types::mem_write_data_t seed);
        // Force a deterministic non-linear value at the last byte.
        pattern_last_byte = seed + types::mem_write_data_t'(1);
    endfunction

    function automatic types::mem_write_data_t pattern_byte(input int unsigned sp,
                                                            input int unsigned row,
                                                            input int unsigned col,
                                                            input int unsigned pix,
                                                            input types::mem_write_data_t seed);
        int unsigned idx_full;
        types::mem_write_data_t idx_byte;
        // Flatten the address space into a byte index so each byte is unique.
        idx_full = (((sp * params::PIXEL_HALFHEIGHT) + row) * params::PIXEL_WIDTH + col)
            * params::BYTES_PER_PIXEL + pix;
        idx_byte = types::mem_write_data_t'(idx_full);
        // Override the endpoints so the first/last bytes are easy to validate.
        if (idx_full == 0) begin
            pattern_byte = pattern_first_byte(seed);
        end else if (idx_full == (TOTAL_BYTES - 1)) begin
            pattern_byte = pattern_last_byte(seed);
        end else begin
            pattern_byte = idx_byte + seed;
        end
    endfunction

    function automatic logic lane_is_dirty(input int unsigned sp,
                                           input types::row_subpanel_addr_t row,
                                           input types::col_addr_t col);
        int unsigned full_row;
        // Convert subpanel/row_subpanel into the full-row address used by copyframe.
        full_row = (sp * params::PIXEL_HALFHEIGHT) + int'(row);
        // DIRTY_ROW_MIN/DIRTY_COL_MIN are zero for this test, so only max checks matter.
        lane_is_dirty = (full_row <= int'(DIRTY_ROW_MAX))
            && (int'(col) <= int'(DIRTY_COL_MAX));
    endfunction

    task automatic init_write(input logic target_frame2,
                              input types::mem_write_addr_t addr,
                              input types::mem_write_data_t data);
        // Hold address/data for two cycles to align with multimem's registered write path.
        @(negedge clk);
        init_addr = addr;
        init_data = data;
        if (target_frame2) begin
            init_we_frame2 = 1'b1;
        end else begin
            init_we_frame1 = 1'b1;
        end
        @(posedge clk);
        @(posedge clk);
        @(negedge clk);
        init_we_frame1 = 1'b0;
        init_we_frame2 = 1'b0;
    endtask

    task automatic init_fill_frame(input logic target_frame2, input types::mem_write_data_t seed);
        // Sequentially write the entire buffer with a deterministic pattern.
        types::mem_write_addr_t addr;
        types::mem_write_data_t data;
        for (int sp = 0; sp < NUM_SUBPANELS; sp++) begin
            for (int row = 0; row < params::PIXEL_HALFHEIGHT; row++) begin
                for (int col = 0; col < params::PIXEL_WIDTH; col++) begin
                    for (int pix = 0; pix < params::BYTES_PER_PIXEL; pix++) begin
                        addr.subpanel = types::subpanel_addr_t'(sp);
                        addr.row = types::row_subpanel_addr_t'(row);
                        addr.col = types::col_addr_t'(col);
                        addr.pixel = types::pixel_addr_t'(pix);
                        data = pattern_byte(sp, row, col, pix, seed);
                        init_write(target_frame2, addr, data);
                    end
                end
            end
        end
    endtask

    task automatic read_rowcol(input types::row_subpanel_addr_t row,
                               input types::col_addr_t col,
                               output types::mem_read_data_t out_frame1,
                               output types::mem_read_data_t out_frame2);
        @(negedge clk);
        ram_b_address.row = row;
        ram_b_address.col = col;
        repeat (READ_LATENCY_B) @(posedge clk);
        #1;
        out_frame1 = ram_b_data_out_frame1;
        out_frame2 = ram_b_data_out_frame2;
    endtask

    task automatic assert_buffers_differ_sample;
        types::mem_read_data_t a;
        types::mem_read_data_t b;
        read_rowcol(types::row_subpanel_addr_t'(0), types::col_addr_t'(0), a, b);
        assert (a.raw != b.raw)
        else $fatal(1, "Pre-copy buffers match at row=0 col=0; expected different patterns.");
        read_rowcol(types::row_subpanel_addr_t'(params::PIXEL_HALFHEIGHT - 1),
                    types::col_addr_t'(params::PIXEL_WIDTH - 1),
                    a, b);
        assert (a.raw != b.raw)
        else $fatal(1, "Pre-copy buffers match at row=%0d col=%0d; expected different patterns.",
                    params::PIXEL_HALFHEIGHT - 1, params::PIXEL_WIDTH - 1);
    endtask

    task automatic assert_buffers_match_dirty;
        types::mem_read_data_t back_data;
        types::mem_read_data_t front_data;
        types::mem_structure_t lane_sel;
        int unsigned lane_idx;
        types::mem_write_data_t expected_front;
        types::mem_write_data_t expected_back;
        // Walk the entire buffer but validate per-lane dirty coverage.
        for (int row = 0; row < params::PIXEL_HALFHEIGHT; row++) begin
            for (int col = 0; col < params::PIXEL_WIDTH; col++) begin
                read_rowcol(types::row_subpanel_addr_t'(row), types::col_addr_t'(col),
                            back_data, front_data);
                for (int sp = 0; sp < NUM_SUBPANELS; sp++) begin
                    for (int pix = 0; pix < params::BYTES_PER_PIXEL; pix++) begin
                        expected_front = pattern_byte(sp, row, col, pix, FRONT_SEED);
                        if (lane_is_dirty(sp, types::row_subpanel_addr_t'(row),
                                          types::col_addr_t'(col))) begin
                            expected_back = expected_front;
                        end else begin
                            expected_back = pattern_byte(sp, row, col, pix, BACK_SEED);
                        end
                        lane_sel.subpanel = types::subpanel_addr_t'(sp);
                        lane_sel.pixel = types::pixel_addr_t'(pix);
                        lane_idx = int'(lane_sel);
                        assert (back_data.lane[lane_idx] == expected_back)
                        else $fatal(1, "Back mismatch row=%0d col=%0d sp=%0d pix=%0d exp=0x%0h got=0x%0h",
                                    row, col, sp, pix, expected_back, back_data.lane[lane_idx]);
                        assert (front_data.lane[lane_idx] == expected_front)
                        else $fatal(1, "Front mismatch row=%0d col=%0d sp=%0d pix=%0d exp=0x%0h got=0x%0h",
                                    row, col, sp, pix, expected_front, front_data.lane[lane_idx]);
                    end
                end
            end
        end
    endtask

    task automatic assert_lane_byte(input types::mem_read_data_t data,
                                    input types::subpanel_addr_t subpanel,
                                    input types::pixel_addr_t pixel,
                                    input types::mem_write_data_t expected,
                                    input string label);
        types::mem_structure_t lane_sel;
        int unsigned lane_idx;
        lane_sel.subpanel = subpanel;
        lane_sel.pixel = pixel;
        lane_idx = int'(lane_sel);
        assert (data.lane[lane_idx] == expected)
        else $fatal(1, "%s mismatch expected=0x%0h got=0x%0h", label, expected, data.lane[lane_idx]);
    endtask

    task automatic assert_pattern_endpoints_for_frame(input types::mem_read_data_t first_row_data,
                                                      input types::mem_read_data_t last_row_data,
                                                      input types::mem_write_data_t seed,
                                                      input string label_prefix);
        // Check the first byte at row=0/col=0/subpanel=0/pixel=0.
        assert_lane_byte(first_row_data,
                         FIRST_SUBPANEL,
                         FIRST_PIXEL_BYTE,
                         pattern_first_byte(seed),
                         {label_prefix, " first byte"});
        // Check the last byte at last row/col/subpanel and highest pixel index.
        assert_lane_byte(last_row_data,
                         LAST_SUBPANEL,
                         LAST_PIXEL_BYTE,
                         pattern_last_byte(seed),
                         {label_prefix, " last byte"});
    endtask

    task automatic assert_pattern_endpoints(input types::mem_write_data_t frame1_seed,
                                            input types::mem_write_data_t frame2_seed);
        types::mem_read_data_t first_row_frame1;
        types::mem_read_data_t first_row_frame2;
        types::mem_read_data_t last_row_frame1;
        types::mem_read_data_t last_row_frame2;
        read_rowcol(FIRST_ROW_SUBPANEL, FIRST_COL, first_row_frame1, first_row_frame2);
        read_rowcol(LAST_ROW_SUBPANEL, LAST_COL_SUBPANEL, last_row_frame1, last_row_frame2);
        assert_pattern_endpoints_for_frame(first_row_frame1, last_row_frame1, frame1_seed, "frame1");
        assert_pattern_endpoints_for_frame(first_row_frame2, last_row_frame2, frame2_seed, "frame2");
    endtask

    task automatic assert_dirty_endpoints;
        types::mem_read_data_t first_row_frame1;
        types::mem_read_data_t first_row_frame2;
        types::mem_read_data_t last_row_frame1;
        types::mem_read_data_t last_row_frame2;
        // First row/col lies inside the dirty rectangle; last row/col is outside.
        read_rowcol(FIRST_ROW_SUBPANEL, FIRST_COL, first_row_frame1, first_row_frame2);
        read_rowcol(LAST_ROW_SUBPANEL, LAST_COL_SUBPANEL, last_row_frame1, last_row_frame2);
        // Dirty area should match the front seed in both frames.
        assert_lane_byte(first_row_frame1,
                         FIRST_SUBPANEL,
                         FIRST_PIXEL_BYTE,
                         pattern_first_byte(FRONT_SEED),
                         "back first byte");
        assert_lane_byte(first_row_frame2,
                         FIRST_SUBPANEL,
                         FIRST_PIXEL_BYTE,
                         pattern_first_byte(FRONT_SEED),
                         "front first byte");
        // Clean area should remain on the back seed while the front stays on front seed.
        assert_lane_byte(last_row_frame1,
                         LAST_SUBPANEL,
                         LAST_PIXEL_BYTE,
                         pattern_last_byte(BACK_SEED),
                         "back last byte");
        assert_lane_byte(last_row_frame2,
                         LAST_SUBPANEL,
                         LAST_PIXEL_BYTE,
                         pattern_last_byte(FRONT_SEED),
                         "front last byte");
    endtask

    // === Clock enable for copy engine (mirrors main.sv) ===
    assign copy_ram_clk_enable = copy_int.access_start ^ copy_ram_access_start_latch;
    always @(posedge clk) begin
        if (reset) begin
            copy_ram_access_start_latch <= 1'b0;
        end else if (copy_ram_clk_enable) begin
            copy_ram_access_start_latch <= copy_int.access_start;
        end
    end

    // === RAM A muxing between init and copy engine ===
    assign ram_a_address_frame1 = init_mode
        ? init_addr
        : (frame_select
            ? types::mem_write_addr_t'(copy_int.write_addr)
            : types::mem_write_addr_t'(copy_int.read_addr));
    assign ram_a_address_frame2 = init_mode
        ? init_addr
        : (frame_select
            ? types::mem_write_addr_t'(copy_int.read_addr)
            : types::mem_write_addr_t'(copy_int.write_addr));

    assign ram_a_data_in_frame1 = init_mode
        ? init_data
        : (frame_select ? copy_int.write_data_out : types::mem_write_data_t'(8'h00));
    assign ram_a_data_in_frame2 = init_mode
        ? init_data
        : (frame_select ? types::mem_write_data_t'(8'h00) : copy_int.write_data_out);

    assign ram_a_clk_enable = init_mode ? 1'b1 : copy_ram_clk_enable;

    wire wrA_frame1 = init_mode ? init_we_frame1 : (frame_select ? copy_int.write_enable : 1'b0);
    wire wrA_frame2 = init_mode ? init_we_frame2 : (frame_select ? 1'b0 : copy_int.write_enable);

    assign ram_a_data_out_front = frame_select ? ram_a_data_out_frame2 : ram_a_data_out_frame1;
    // Drive the copy interface with the front-buffer read data and enable state.
    assign copy_int.read_data_in = ram_a_data_out_front;
    assign copy_int.active = copy_enable;

    // === DUT: copy engine ===
    control_cmd_copyframe #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .enable(copy_enable),
        .clk(clk),
        .data_in(copy_int.read_data_in),
        .dirty_valid(dirty_valid),
        .dirty_row_min(dirty_row_min),
        .dirty_row_max(dirty_row_max),
        .dirty_col_min(dirty_col_min),
        .dirty_col_max(dirty_col_max),
        .read_addr(copy_int.read_addr),
        .write_addr(copy_int.write_addr),
        .data_out(copy_int.write_data_out),
        .ram_write_enable(copy_int.write_enable),
        .ram_access_start(copy_int.access_start),
        .done(cmd_copyframe_done)
    );

    // === DUT: front/back framebuffer RAMs (wired like main.sv) ===
    multimem #(
        ._UNUSED('d0)
    ) fb_frame1 (
        .ClockA(clk),
        .AddressA(ram_a_address_frame1),
        .DataInA(ram_a_data_in_frame1),
        .WrA(wrA_frame1),
        .ResetA(reset),
        .ClockB(clk),
        .DataInB(16'b0),
        .AddressB(ram_b_address),
        .WrB(1'b0),
        .ResetB(reset),
        .CopyMode(1'b0),
        .QA(ram_a_data_out_frame1),
        .QB(ram_b_data_out_frame1),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable)
    );

    multimem #(
        ._UNUSED('d0)
    ) fb_frame2 (
        .ClockA(clk),
        .AddressA(ram_a_address_frame2),
        .DataInA(ram_a_data_in_frame2),
        .WrA(wrA_frame2),
        .ResetA(reset),
        .ClockB(clk),
        .DataInB(16'b0),
        .AddressB(ram_b_address),
        .WrB(1'b0),
        .ResetB(reset),
        .CopyMode(1'b0),
        .QA(ram_a_data_out_frame2),
        .QB(ram_b_data_out_frame2),
        .ClockEnA(ram_a_clk_enable),
        .ClockEnB(ram_b_clk_enable)
    );

    // === Init ===
    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_control_cmd_copyframe_dirty25);
        clk = 0;
        reset = 1;
        copy_enable = 0;
        init_mode = 1;
        init_we_frame1 = 0;
        init_we_frame2 = 0;
        init_addr = '0;
        init_data = 8'h00;
        ram_b_address = '0;
        ram_b_clk_enable = 1'b1;
        // Select frame2 as front, frame1 as back (matches main.sv wiring).
        frame_select = 1'b1;
        dirty_valid = 1'b1;
        dirty_row_min = DIRTY_ROW_MIN;
        dirty_row_max = DIRTY_ROW_MAX;
        dirty_col_min = DIRTY_COL_MIN;
        dirty_col_max = DIRTY_COL_MAX;
        @(posedge clk) @(posedge clk) reset = 0;
    end

    // === Stimulus ===
    initial begin
        @(negedge reset);

        // Build distinct patterns into front/back so copy can be proven.
        init_fill_frame(1'b1, FRONT_SEED);  // front buffer (frame2)
        init_fill_frame(1'b0, BACK_SEED);   // back buffer (frame1)
        assert_buffers_differ_sample();
        assert_pattern_endpoints(BACK_SEED, FRONT_SEED);

        // Start the copy engine and wait for completion.
        init_mode = 1'b0;
        @(posedge clk);
        copy_enable = 1'b1;
        `WAIT_ASSERT(clk, cmd_copyframe_done == 1'b1, COPY_CYCLES_MAX)
        @(posedge clk);
        // done should deassert on the very next cycle even if enable remains high.
        assert (cmd_copyframe_done == 1'b0)
        else $fatal(1, "done did not deassert on the cycle after asserting");
        copy_enable = 1'b0;
        // Ensure we only saw a single done pulse for this transaction.
        assert (done_pulses == 1)
        else $fatal(1, "Expected a single done pulse, saw %0d", done_pulses);

        // Verify the back buffer matches the front only inside the dirty rectangle.
        assert_buffers_match_dirty();
        // Re-check endpoints with dirty vs clean expectations.
        assert_dirty_endpoints();
        $display("copyframe_cycles=%0d dirty_bytes=%0d", copyframe_cycles, DIRTY_TOTAL_BYTES);
        assert (copyframe_cycles <= longint'(COPY_CYCLES_MAX))
        else $fatal(1, "copyframe_cycles=%0d exceeded max=%0d", copyframe_cycles, COPY_CYCLES_MAX);
        repeat (5) @(posedge clk);
        $finish;
    end

    // === Clock generation ===
    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    // === Done pulse checks ===
    // Mirrors the "other command" expectations:
    //  - done is a single-cycle pulse
    //  - done only asserts after the final write
    //  - outputs are idle immediately after done
    always @(posedge clk) begin
        if (reset) begin
            done_prev <= 1'b0;
            last_write_seen <= 1'b0;
            pending_post_done_check <= 1'b0;
            done_pulses <= 0;
            cycle_count <= 0;
            copyframe_start_cycle <= 0;
            copyframe_cycles <= 0;
            measure_copyframe <= 1'b0;
            copy_enable_prev <= 1'b0;
        end else begin
            cycle_count <= cycle_count + 1'b1;
            // Track the final write address so done can be validated.
            if (copy_int.write_enable
                && (copy_int.write_addr.row == DIRTY_ROW_MAX)
                && (copy_int.write_addr.col == DIRTY_COL_MAX)
                && (copy_int.write_addr.pixel == LAST_PIXEL_COUNTDOWN)) begin
                last_write_seen <= 1'b1;
            end

            // Validate outputs on the cycle after done.
            if (pending_post_done_check) begin
                pending_post_done_check <= 1'b0;
                assert (copy_int.write_enable == 1'b0)
                else $fatal(1, "ram_write_enable asserted after done");
                assert (copy_int.write_data_out == 8'h00)
                else $fatal(1, "data_out not cleared after done");
            end

            if (cmd_copyframe_done) begin
                done_pulses <= done_pulses + 1;
                if (measure_copyframe) begin
                    copyframe_cycles <= cycle_count - copyframe_start_cycle;
                    measure_copyframe <= 1'b0;
                end
                // done should be a single-cycle pulse.
                assert (!done_prev)
                else $fatal(1, "done asserted for multiple cycles");
                // done must not assert before the final write.
                assert (last_write_seen)
                else $fatal(1, "done asserted before the final write");
                pending_post_done_check <= 1'b1;
            end
            done_prev <= cmd_copyframe_done;
            if (copy_enable && !copy_enable_prev && !measure_copyframe) begin
                // Start timing on the rising edge of copy_enable.
                copyframe_start_cycle <= cycle_count;
                measure_copyframe <= 1'b1;
            end
            copy_enable_prev <= copy_enable;
        end
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        1'b0};
    // verilog_format: on
endmodule
