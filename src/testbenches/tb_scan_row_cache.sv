// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on

module tb_scan_row_cache;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);

    logic clk;
    logic reset;
    types::col_addr_t scan_col;
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

    scan_row_cache dut (
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

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    initial begin
        clk = 1'b0;
        reset = 1'b1;
        scan_col = '0;
        blank_active = 1'b1;
        fill_cache_select = 1'b0;
        fill_valid = 1'b0;
        fill_commit = 1'b0;
        fill_row = '0;
        fill_col = '0;
        activate_cache_select_valid = 1'b0;
        activate_cache_select = 1'b0;
        invalidate_all = 1'b0;
        invalidate_cache_select_valid = 1'b0;
        invalidate_cache_select = 1'b0;
        for (int subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx++) begin
            fill_pixels[subpanel_idx] = '0;
        end

        repeat (2) @(posedge clk);
        reset = 1'b0;

        // Fill cache 0 at column 1 with distinct top/bottom data and commit it.
        @(negedge clk);
        fill_cache_select = 1'b0;
        fill_row = types::row_subpanel_addr_t'(0);
        fill_col = types::col_addr_t'(1);
        fill_pixels[0] = make_field(8'h11, 8'h22, 8'h33);
        fill_pixels[1] = make_field(8'h44, 8'h55, 8'h66);
        fill_valid = 1'b1;
        fill_commit = 1'b1;
        @(posedge clk);
        @(negedge clk);
        fill_valid = 1'b0;
        fill_commit = 1'b0;

        // Activate cache 0 and verify deterministic readout.
        activate_cache_select_valid = 1'b1;
        activate_cache_select = 1'b0;
        blank_active = 1'b0;
        @(posedge clk);
        @(negedge clk);
        activate_cache_select_valid = 1'b0;
        scan_col = types::col_addr_t'(1);
        #1;
        assert (cache_valid[0] === 1'b1 && cache_row[0] == types::row_subpanel_addr_t'(0))
        else $fatal(1, "cache0 metadata mismatch");
        assert (pixeldata_subpanels[0].raw == make_field(8'h11, 8'h22, 8'h33).raw)
        else $fatal(1, "cache0 top pixel mismatch");
        assert (pixeldata_subpanels[1].raw == make_field(8'h44, 8'h55, 8'h66).raw)
        else $fatal(1, "cache0 bottom pixel mismatch");

        // Blank the active row without destroying cache contents.
        blank_active = 1'b1;
        #1;
        assert (pixeldata_subpanels[0].raw == '0 && pixeldata_subpanels[1].raw == '0)
        else $fatal(1, "blank_active should force zero output");
        assert (cache_valid[0] === 1'b1)
        else $fatal(1, "blank_active should not invalidate cache");

        // Invalidate just cache 0.
        @(negedge clk);
        invalidate_cache_select_valid = 1'b1;
        invalidate_cache_select = 1'b0;
        @(posedge clk);
        @(negedge clk);
        invalidate_cache_select_valid = 1'b0;
        assert (cache_valid[0] === 1'b0)
        else $fatal(1, "cache0 should be invalidated");

        $display("tb_scan_row_cache: PASS");
        $finish;
    end

    wire _unused_ok = &{1'b0, active_cache_select, 1'b0};
endmodule
