// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_scan_prefetch;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);

    logic clk;
    logic reset;
    types::row_subpanel_addr_t row_address_active;
    logic invalidate_caches;
    fb_store_if store_if ();
    logic blank_active;
    logic fill_cache_select;
    logic fill_valid;
    logic fill_commit;
    types::row_subpanel_addr_t fill_row;
    types::col_addr_t fill_col;
    types::color_field_t fill_pixels[NUM_SUBPANELS];
    logic activate_cache_select_valid;
    logic activate_cache_select;
    logic invalidate_all;
    logic invalidate_cache_select_valid;
    logic invalidate_cache_select;
    logic active_cache_select;
    logic cache_valid[2];
    types::row_subpanel_addr_t cache_row[2];
    types::color_field_t pixeldata_subpanels[NUM_SUBPANELS];
    logic prefetch_in_progress;
    logic underflow_sticky;
    types::col_addr_t scan_col;

    function automatic types::color_field_t make_field(input logic [7:0] b0,
                                                       input logic [7:0] b1,
                                                       input logic [7:0] b2);
        types::color_field_t field;
        begin
            field = '0;
            field.bytes[0] = b0;
            field.bytes[1] = b1;
            field.bytes[2] = b2;
            make_field = field;
        end
    endfunction

    scan_prefetch prefetch (
        .clk_in(clk),
        .reset(reset),
        .row_address_active(row_address_active),
        .invalidate_caches(invalidate_caches),
        .store_if(store_if),
        .active_cache_select(active_cache_select),
        .cache_valid(cache_valid),
        .cache_row(cache_row),
        .blank_active(blank_active),
        .fill_cache_select(fill_cache_select),
        .fill_valid(fill_valid),
        .fill_commit(fill_commit),
        .fill_row(fill_row),
        .fill_col(fill_col),
        .fill_pixels(fill_pixels),
        .activate_cache_select_valid(activate_cache_select_valid),
        .activate_cache_select(activate_cache_select),
        .invalidate_all(invalidate_all),
        .invalidate_cache_select_valid(invalidate_cache_select_valid),
        .invalidate_cache_select(invalidate_cache_select),
        .prefetch_in_progress(prefetch_in_progress),
        .underflow_sticky(underflow_sticky)
    );

    scan_row_cache cache (
        .clk_in(clk),
        .reset(reset),
        .scan_col(scan_col),
        .blank_active(blank_active),
        .fill_cache_select(fill_cache_select),
        .fill_valid(fill_valid),
        .fill_commit(fill_commit),
        .fill_row(fill_row),
        .fill_col(fill_col),
        .fill_pixels(fill_pixels),
        .activate_cache_select_valid(activate_cache_select_valid),
        .activate_cache_select(activate_cache_select),
        .invalidate_all(invalidate_all),
        .invalidate_cache_select_valid(invalidate_cache_select_valid),
        .invalidate_cache_select(invalidate_cache_select),
        .active_cache_select(active_cache_select),
        .cache_valid(cache_valid),
        .cache_row(cache_row),
        .pixeldata_subpanels(pixeldata_subpanels)
    );

    task automatic drive_stream_row(input types::row_subpanel_addr_t row_value, input logic [7:0] base);
        begin
            store_if.prefetch_req_ready = 1'b1;
            `WAIT_ASSERT(clk, store_if.prefetch_req_valid === 1'b1, 512)
            assert (store_if.prefetch_row == row_value)
            else $fatal(1, "expected request row %0d got %0d", row_value, store_if.prefetch_row);
            @(posedge clk);
            @(negedge clk);
            store_if.prefetch_req_ready = 1'b0;

            for (int col = 0; col < params::PIXEL_WIDTH; col++) begin
                while (!store_if.prefetch_data_ready) begin
                    @(posedge clk);
                end
                store_if.prefetch_col = types::col_addr_t'(col);
                store_if.prefetch_data_valid = 1'b1;
                store_if.prefetch_data_first = (col == 0);
                store_if.prefetch_data_last = (col == (params::PIXEL_WIDTH - 1));
                for (int subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx++) begin
                    store_if.prefetch_pixels[subpanel_idx] = make_field(
                        byte'(int'(base) + (subpanel_idx * 16) + col),
                        byte'(int'(base) + (subpanel_idx * 16) + col + 1),
                        byte'(int'(base) + (subpanel_idx * 16) + col + 2)
                    );
                end
                @(posedge clk);
            end
            @(negedge clk);
            store_if.prefetch_data_valid = 1'b0;
            store_if.prefetch_data_first = 1'b0;
            store_if.prefetch_data_last = 1'b0;
        end
    endtask

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        row_address_active = '0;
        invalidate_caches = 1'b0;
        scan_col = types::col_addr_t'(1);
        store_if.cmd_write_valid = 1'b0;
        store_if.cmd_write_ready = 1'b0;
        store_if.cmd_write_addr = '0;
        store_if.cmd_write_data = '0;
        store_if.copy_start = 1'b0;
        store_if.copy_busy = 1'b0;
        store_if.copy_done = 1'b0;
        store_if.frame_select = 1'b0;
        store_if.prefetch_req_ready = 1'b0;
        store_if.prefetch_data_valid = 1'b0;
        store_if.prefetch_data_first = 1'b0;
        store_if.prefetch_data_last = 1'b0;
        store_if.prefetch_col = '0;
        store_if.backend_ready = 1'b1;
        store_if.backend_error = 1'b0;
        store_if.prefetch_pixels[0] = '0;
        store_if.prefetch_pixels[1] = '0;

        repeat (2) @(posedge clk);
        reset = 1'b0;

        // Startup: request and load row 0, then automatically request row 1.
        drive_stream_row(types::row_subpanel_addr_t'(0), 8'h10);
        #1;
        assert (blank_active === 1'b0)
        else $fatal(1, "row0 should become active after first fill");
        assert (pixeldata_subpanels[0].raw == make_field(8'h11, 8'h12, 8'h13).raw)
        else $fatal(1, "row0 top pixel mismatch");
        assert (pixeldata_subpanels[1].raw == make_field(8'h21, 8'h22, 8'h23).raw)
        else $fatal(1, "row0 bottom pixel mismatch");

        drive_stream_row(types::row_subpanel_addr_t'(1), 8'h40);
        row_address_active = types::row_subpanel_addr_t'(1);
        repeat (2) @(posedge clk);
        #1;
        assert (blank_active === 1'b0)
        else $fatal(1, "row1 should swap in without blanking");
        assert (pixeldata_subpanels[0].raw == make_field(8'h41, 8'h42, 8'h43).raw)
        else $fatal(1, "row1 top pixel mismatch");

        // Underflow: jump to row 2 before it has been prefetched.
        row_address_active = types::row_subpanel_addr_t'(2);
        @(posedge clk);
        #1;
        assert (blank_active === 1'b1)
        else $fatal(1, "underflow should blank the active row");
        assert (underflow_sticky === 1'b1)
        else $fatal(1, "underflow flag should latch high");

        drive_stream_row(types::row_subpanel_addr_t'(2), 8'h70);
        @(posedge clk);
        #1;
        assert (blank_active === 1'b0)
        else $fatal(1, "loaded underflow row should become active");
        assert (pixeldata_subpanels[0].raw == make_field(8'h71, 8'h72, 8'h73).raw)
        else $fatal(1, "row2 top pixel mismatch");

        $display("tb_scan_prefetch: PASS");
        $finish;
    end

    wire _unused_ok = &{1'b0,
                        prefetch_in_progress,
                        store_if.cmd_write_valid,
                        store_if.cmd_write_ready,
                        ^store_if.cmd_write_addr,
                        ^store_if.cmd_write_data,
                        store_if.copy_start,
                        store_if.copy_busy,
                        store_if.copy_done,
                        store_if.frame_select,
                        store_if.backend_error,
                        1'b0};
endmodule
