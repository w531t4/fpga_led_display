// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// fb_store_if:
//   Storage-facing contract for framebuffer backends.
//
// The intent is to express what the rest of the design needs from storage,
// without leaking the current BRAM banking details (`multimem`, lane packing,
// Port-A/Port-B naming, etc).
//
// Current design needs represented here:
//   - command-side byte writes using logical framebuffer coordinates
//   - scan-side row-pair prefetch requests
//   - streamed row-pair data returned in logical display order
//   - internal copyframe start/busy/done signaling
//   - front/back role selection
//
// This interface is introduced in advance of the backend refactor so the
// storage seam can be defined before the BRAM implementation is wrapped.
interface fb_store_if;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);

    // === Command-side byte write path ===
    //
    // A single logical byte write into the framebuffer.
    // The address is expressed in full framebuffer coordinates rather than the
    // current BRAM-specific mem_write_addr_t lane split.
    logic            cmd_write_valid;
    logic            cmd_write_ready;
    types::fb_addr_t cmd_write_addr;
    logic      [7:0] cmd_write_data;

    // === Scan-side row-pair prefetch request ===
    //
    // Request one logical row pair identified by the row index within a
    // subpanel. A future backend may satisfy this from BRAM, SDRAM, or a cache.
    logic                        prefetch_req_valid;
    logic                        prefetch_req_ready;
    types::row_subpanel_addr_t   prefetch_row;

    // === Scan-side row-pair streamed response ===
    //
    // One streamed column of the requested row pair in logical display order.
    // Each beat carries the color fields for all subpanels at a single column.
    logic                        prefetch_data_valid;
    logic                        prefetch_data_ready;
    logic                        prefetch_data_first;
    logic                        prefetch_data_last;
    types::col_addr_t            prefetch_col;
    types::color_field_t         prefetch_pixels[NUM_SUBPANELS];

    // === Copyframe control ===
    //
    // Backend-native request/status for copying front -> back.
    logic                        copy_start;
    logic                        copy_busy;
    logic                        copy_done;

    // === Front/back role selection ===
    //
    // Current designs use frame_select to choose which physical storage region
    // is front vs back. Single-buffer builds may tie this low and ignore it.
    logic                        frame_select;

    // === Backend-level health / availability ===
    //
    // ready: backend is initialized and can accept requests
    // error: backend has encountered an unrecoverable fault
    logic                        backend_ready;
    logic                        backend_error;

    // Control/path producer view.
    modport control(
        output cmd_write_valid,
        output cmd_write_addr,
        output cmd_write_data,
        output copy_start,
        output frame_select,
        input  cmd_write_ready,
        input  copy_busy,
        input  copy_done,
        input  backend_ready,
        input  backend_error
    );

    // Scan-prefetch producer / streamed-consumer view.
    modport scan(
        output prefetch_req_valid,
        output prefetch_row,
        output prefetch_data_ready,
        input  prefetch_req_ready,
        input  prefetch_data_valid,
        input  prefetch_data_first,
        input  prefetch_data_last,
        input  prefetch_col,
        input  prefetch_pixels,
        input  backend_ready,
        input  backend_error
    );

    // Backend implementation view.
    modport backend(
        input  cmd_write_valid,
        input  cmd_write_addr,
        input  cmd_write_data,
        input  prefetch_req_valid,
        input  prefetch_row,
        input  prefetch_data_ready,
        input  copy_start,
        input  frame_select,
        output cmd_write_ready,
        output prefetch_req_ready,
        output prefetch_data_valid,
        output prefetch_data_first,
        output prefetch_data_last,
        output prefetch_col,
        output prefetch_pixels,
        output copy_busy,
        output copy_done,
        output backend_ready,
        output backend_error
    );
endinterface
