// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module scan_prefetch (
    input logic clk_in,
    input logic reset,

    input types::row_subpanel_addr_t row_address_active,
    input logic invalidate_caches,

    fb_store_if.scan store_if,

    input logic active_cache_select,
    input logic cache_valid[2],
    input types::row_subpanel_addr_t cache_row[2],

    output logic blank_active,
    output logic fill_cache_select,
    output logic fill_valid,
    output logic fill_commit,
    output types::row_subpanel_addr_t fill_row,
    output types::col_addr_t fill_col,
    output types::color_field_t fill_pixels[calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT)],
    output logic activate_cache_select_valid,
    output logic activate_cache_select,
    output logic invalidate_all,
    output logic invalidate_cache_select_valid,
    output logic invalidate_cache_select,
    output logic prefetch_in_progress,
    output logic underflow_sticky
);
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam types::row_subpanel_addr_t RESTART_ROW = '0;

    logic request_valid_q;
    types::row_subpanel_addr_t request_row_q;
    logic request_cache_select_q;

    logic stream_inflight_q;
    types::row_subpanel_addr_t stream_row_q;
    logic stream_cache_select_q;
    logic restart_from_row0_q;

    function automatic types::row_subpanel_addr_t next_row(input types::row_subpanel_addr_t row_value);
        if (row_value == types::row_subpanel_addr_t'(params::PIXEL_HALFHEIGHT - 1)) begin
            next_row = '0;
        end else begin
            next_row = row_value + 'd1;
        end
    endfunction

    function automatic logic cache_matches(input logic valid,
                                           input types::row_subpanel_addr_t cached_row,
                                           input types::row_subpanel_addr_t wanted_row);
        cache_matches = valid && (cached_row == wanted_row);
    endfunction

    types::row_subpanel_addr_t wanted_next_row;
    logic inactive_cache_select;
    logic current_in_active;
    logic current_in_inactive;
    logic next_in_active;
    logic next_in_inactive;
    logic stream_targets_current;

    // After a frame toggle invalidates both row caches, restart by fetching
    // logical row pair 0 from the new front frame before resuming normal
    // row-ahead prefetching.
    assign wanted_next_row = next_row(restart_from_row0_q ? RESTART_ROW : row_address_active);
    assign inactive_cache_select = ~active_cache_select;
    assign current_in_active = cache_matches(cache_valid[active_cache_select],
                                             cache_row[active_cache_select],
                                             restart_from_row0_q ? RESTART_ROW : row_address_active);
    assign current_in_inactive = cache_matches(cache_valid[inactive_cache_select],
                                               cache_row[inactive_cache_select],
                                               restart_from_row0_q ? RESTART_ROW : row_address_active);
    assign next_in_active = cache_matches(cache_valid[active_cache_select], cache_row[active_cache_select], wanted_next_row);
    assign next_in_inactive = cache_matches(cache_valid[inactive_cache_select], cache_row[inactive_cache_select], wanted_next_row);
    assign stream_targets_current = stream_inflight_q && (stream_row_q == (restart_from_row0_q ? RESTART_ROW : row_address_active));

    always_ff @(posedge clk_in) begin
        if (reset) begin
            request_valid_q <= 1'b0;
            request_row_q <= '0;
            request_cache_select_q <= 1'b0;
            stream_inflight_q <= 1'b0;
            stream_row_q <= '0;
            stream_cache_select_q <= 1'b0;
            restart_from_row0_q <= 1'b0;
            blank_active <= 1'b1;
            underflow_sticky <= 1'b0;
            activate_cache_select_valid <= 1'b0;
            activate_cache_select <= 1'b0;
            invalidate_all <= 1'b1;
            invalidate_cache_select_valid <= 1'b0;
            invalidate_cache_select <= 1'b0;
        end else begin
            activate_cache_select_valid <= 1'b0;
            invalidate_all <= 1'b0;
            invalidate_cache_select_valid <= 1'b0;

            if (invalidate_caches) begin
                request_valid_q <= 1'b0;
                stream_inflight_q <= 1'b0;
                restart_from_row0_q <= 1'b1;
                blank_active <= 1'b1;
                invalidate_all <= 1'b1;
            end else begin
                if (current_in_inactive && (!current_in_active || blank_active)) begin
                    activate_cache_select_valid <= 1'b1;
                    activate_cache_select <= inactive_cache_select;
                    restart_from_row0_q <= 1'b0;
                    blank_active <= 1'b0;
                end else if (!current_in_active && !stream_targets_current) begin
                    blank_active <= 1'b1;
                    underflow_sticky <= 1'b1;
                end

                if (request_valid_q && store_if.prefetch_req_ready) begin
                    request_valid_q <= 1'b0;
                    stream_inflight_q <= 1'b1;
                    stream_row_q <= request_row_q;
                    stream_cache_select_q <= request_cache_select_q;
                end

                if (store_if.prefetch_data_valid && store_if.prefetch_data_ready && store_if.prefetch_data_last) begin
                    stream_inflight_q <= 1'b0;
                    if (stream_row_q == (restart_from_row0_q ? RESTART_ROW : row_address_active)) begin
                        activate_cache_select_valid <= 1'b1;
                        activate_cache_select <= stream_cache_select_q;
                        restart_from_row0_q <= 1'b0;
                        blank_active <= 1'b0;
                    end
                end

                if (!request_valid_q && !stream_inflight_q) begin
                    if (!current_in_active && !current_in_inactive) begin
                        request_valid_q <= 1'b1;
                        request_row_q <= restart_from_row0_q ? RESTART_ROW : row_address_active;
                        request_cache_select_q <= inactive_cache_select;
                        invalidate_cache_select_valid <= 1'b1;
                        invalidate_cache_select <= inactive_cache_select;
                    end else if (!next_in_active && !next_in_inactive) begin
                        request_valid_q <= 1'b1;
                        request_row_q <= wanted_next_row;
                        request_cache_select_q <= current_in_active ? inactive_cache_select : active_cache_select;
                        invalidate_cache_select_valid <= 1'b1;
                        invalidate_cache_select <= current_in_active ? inactive_cache_select : active_cache_select;
                    end
                end
            end
        end
    end

    assign store_if.prefetch_req_valid = request_valid_q;
    assign store_if.prefetch_row = request_row_q;
    assign store_if.prefetch_data_ready = stream_inflight_q;

    assign fill_cache_select = stream_cache_select_q;
    assign fill_valid = store_if.prefetch_data_valid && store_if.prefetch_data_ready;
    assign fill_commit = store_if.prefetch_data_valid && store_if.prefetch_data_ready && store_if.prefetch_data_last;
    assign fill_row = stream_row_q;
    assign fill_col = store_if.prefetch_col;
    assign prefetch_in_progress = request_valid_q || stream_inflight_q;

    generate
        genvar out_subpanel_idx;
        for (out_subpanel_idx = 0; out_subpanel_idx < NUM_SUBPANELS; out_subpanel_idx = out_subpanel_idx + 1) begin
            assign fill_pixels[out_subpanel_idx] = store_if.prefetch_pixels[out_subpanel_idx];
        end
    endgenerate

    wire _unused_ok = &{1'b0, store_if.prefetch_data_first, store_if.backend_ready, store_if.backend_error, 1'b0};
endmodule
