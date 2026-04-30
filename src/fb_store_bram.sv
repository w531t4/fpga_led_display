// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// fb_store_bram:
//   Compatibility BRAM backend for the new framebuffer-store abstraction.
//
// This module intentionally keeps the current BRAM-backed storage behavior
// alive while the broader SDRAM migration is still in flight:
//   - command-side writes enter through fb_store_if using logical coordinates
//   - the existing copyframe engine still uses mem_copy_if temporarily
//   - the existing scan path still uses the direct Port-B style read path
//
// Keeping those legacy seams here localizes the current multimem-specific
// details to one module so main.sv can choose a framebuffer backend from one
// place without knowing how BRAM happens to be wired internally.
module fb_store_bram (
    input logic clk_root,
    input logic reset,

    fb_store_if.backend store_if,

`ifdef DOUBLE_BUFFER
    mem_copy_if.fabric copy_if,
`endif

    // Legacy scan-side read path kept until scan_row_cache/scan_prefetch exist.
    input  types::mem_read_addr_t scan_ram_address,
    input  logic                  scan_ram_clk_enable,
    output types::mem_read_data_t scan_ram_data
);
    localparam int unsigned ROW_BITS = $bits(types::row_subpanel_addr_t);
`ifdef DOUBLE_BUFFER
    localparam int unsigned FULL_ROW_BITS = $bits(types::row_addr_t);
`endif

    types::mem_write_addr_t ctrl_ram_address;
    types::mem_write_data_t ctrl_ram_data_out;
    logic                   ctrl_ram_write_enable;
    logic                   ctrl_ram_clk_enable;

    // Rebuild the BRAM-specific split row address from the logical interface.
    // row_addr_t is currently packed as {subpanel, row_within_subpanel}.
    always_comb begin
        ctrl_ram_address = '0;
        ctrl_ram_address.row = store_if.cmd_write_addr.row[ROW_BITS-1:0];
        ctrl_ram_address.col = store_if.cmd_write_addr.col;
        ctrl_ram_address.pixel = store_if.cmd_write_addr.pixel;
`ifdef DOUBLE_BUFFER
        ctrl_ram_address.subpanel = store_if.cmd_write_addr.row[FULL_ROW_BITS-1:ROW_BITS];
`endif
        ctrl_ram_data_out = store_if.cmd_write_data;
        ctrl_ram_write_enable = store_if.cmd_write_valid;
        ctrl_ram_clk_enable = store_if.cmd_write_valid;
    end

    framebuffer_fabric fb_fabric (
        .clk_root(clk_root),
        .reset(reset),
        .ctrl_ram_address(ctrl_ram_address),
        .ctrl_ram_data_out(ctrl_ram_data_out),
        .ctrl_ram_write_enable(ctrl_ram_write_enable),
        .ctrl_ram_clk_enable(ctrl_ram_clk_enable),
        .ram_b_address(scan_ram_address),
        .ram_b_clk_enable(scan_ram_clk_enable),
        .ram_b_data_out(scan_ram_data)
`ifdef DOUBLE_BUFFER,
        .frame_select(store_if.frame_select),
        .copy_if(copy_if)
`endif
    );

    // BRAM comes up immediately and does not currently report backend faults.
    assign store_if.backend_ready = 1'b1;
    assign store_if.backend_error = 1'b0;
    assign store_if.cmd_write_ready = 1'b1;

    // The logical scan-prefetch API is introduced ahead of the scan-cache
    // refactor. Until that work lands, keep it quiescent instead of pretending
    // the current direct-read scan path already satisfies the future contract.
    genvar subpanel_idx;
    generate
        for (subpanel_idx = 0; subpanel_idx < calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
             subpanel_idx = subpanel_idx + 1) begin : gen_prefetch_zero
            assign store_if.prefetch_pixels[subpanel_idx] = '0;
        end
    endgenerate
    assign store_if.prefetch_req_ready = 1'b0;
    assign store_if.prefetch_data_valid = 1'b0;
    assign store_if.prefetch_data_first = 1'b0;
    assign store_if.prefetch_data_last = 1'b0;
    assign store_if.prefetch_col = '0;

    // Native backend-managed copyframe is future work. The current BRAM path
    // still uses mem_copy_if, so reflect only coarse compatibility status here.
    assign store_if.copy_busy = 1'b0;
    assign store_if.copy_done = 1'b0;

    wire _unused_ok = &{1'b0,
                        store_if.prefetch_req_valid,
                        store_if.prefetch_row,
                        store_if.prefetch_data_ready,
                        store_if.copy_start,
                        1'b0};
endmodule
