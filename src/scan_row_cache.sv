// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module scan_row_cache (
    input logic clk_in,
    input logic reset,

    input types::col_addr_t scan_col,
    input logic blank_active,

    input logic fill_cache_select,
    input logic fill_valid,
    input logic fill_commit,
    input types::row_subpanel_addr_t fill_row,
    input types::col_addr_t fill_col,
    input types::color_field_t fill_pixels[calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT)],

    input logic activate_cache_select_valid,
    input logic activate_cache_select,
    input logic invalidate_all,
    input logic invalidate_cache_select_valid,
    input logic invalidate_cache_select,

    output logic active_cache_select,
    output logic cache_valid[2],
    output types::row_subpanel_addr_t cache_row[2],
    output types::color_field_t pixeldata_subpanels[calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT)]
);
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);

    types::color_field_t cache_mem[2][params::PIXEL_WIDTH][NUM_SUBPANELS];
    integer reset_cache_idx;
    integer reset_col_idx;
    integer reset_subpanel_idx;
    integer fill_subpanel_idx;
    integer out_subpanel_idx;

    always_ff @(posedge clk_in) begin
        if (reset) begin
            active_cache_select <= 1'b0;
            for (reset_cache_idx = 0; reset_cache_idx < 2; reset_cache_idx = reset_cache_idx + 1) begin
                cache_valid[reset_cache_idx] <= 1'b0;
                cache_row[reset_cache_idx] <= '0;
                /* verilator lint_off UNUSEDLOOP */
                for (reset_col_idx = 0; reset_col_idx < params::PIXEL_WIDTH; reset_col_idx = reset_col_idx + 1) begin
                    for (reset_subpanel_idx = 0; reset_subpanel_idx < NUM_SUBPANELS;
                         reset_subpanel_idx = reset_subpanel_idx + 1) begin
                        cache_mem[reset_cache_idx][reset_col_idx][reset_subpanel_idx] <= '0;
                    end
                end
                /* verilator lint_on UNUSEDLOOP */
            end
        end else begin
            if (invalidate_all) begin
                for (reset_cache_idx = 0; reset_cache_idx < 2; reset_cache_idx = reset_cache_idx + 1) begin
                    cache_valid[reset_cache_idx] <= 1'b0;
                end
            end

            if (invalidate_cache_select_valid) begin
                cache_valid[invalidate_cache_select] <= 1'b0;
            end

            if (fill_valid) begin
                for (fill_subpanel_idx = 0; fill_subpanel_idx < NUM_SUBPANELS; fill_subpanel_idx = fill_subpanel_idx + 1) begin
                    cache_mem[fill_cache_select][fill_col][fill_subpanel_idx] <= fill_pixels[fill_subpanel_idx];
                end
            end

            if (fill_commit) begin
                cache_row[fill_cache_select] <= fill_row;
                cache_valid[fill_cache_select] <= 1'b1;
            end

            if (activate_cache_select_valid) begin
                active_cache_select <= activate_cache_select;
            end
        end
    end

    always_comb begin
        for (out_subpanel_idx = 0; out_subpanel_idx < NUM_SUBPANELS; out_subpanel_idx = out_subpanel_idx + 1) begin
            pixeldata_subpanels[out_subpanel_idx] = '0;
            if (!blank_active && cache_valid[active_cache_select]) begin
                pixeldata_subpanels[out_subpanel_idx] = cache_mem[active_cache_select][scan_col][out_subpanel_idx];
            end
        end
    end
endmodule
