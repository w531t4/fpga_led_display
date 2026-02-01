// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module framebuffer_fabric (
    input logic clk_root,
    input logic reset,

    // Controller write path.
    input types::mem_write_addr_t ctrl_ram_address,
    input types::mem_write_data_t ctrl_ram_data_out,
    input logic                   ctrl_ram_write_enable,
    input logic                   ctrl_ram_clk_enable,

`ifdef DOUBLE_BUFFER
    // Copy engine control (front/back buffers).
    input logic frame_select,
    mem_copy_if.fabric copy_if,
`endif

    // RAM B (read) path from fetcher.
    input  types::mem_read_addr_t ram_b_address,
    input  logic                  ram_b_clk_enable,
    output types::mem_read_data_t ram_b_data_out
);
    // Explicit frame indices (avoid magic numbers in logic).
    localparam int unsigned FRAME0_IDX = 0;
    localparam int unsigned FRAME1_IDX = 1;

    // Per-frame RAM-A wiring.
    types::mem_write_addr_t ram_a_address_frames     [params::NUM_FRAMEBUFFERS];
    types::mem_write_data_t ram_a_data_in_frames     [params::NUM_FRAMEBUFFERS];
    logic                   ram_a_write_enable_frames[params::NUM_FRAMEBUFFERS];
    types::mem_write_data_t ram_a_data_out_frames    [params::NUM_FRAMEBUFFERS];
    types::mem_read_data_t  ram_b_data_out_frames    [params::NUM_FRAMEBUFFERS];
    logic                   ram_copy_mode;
    logic                   ram_a_clk_enable;

`ifdef DOUBLE_BUFFER
    // Create a one-cycle enable pulse on copy_access_start edges.
    logic copy_ram_access_start_latch;
    logic copy_ram_clk_enable;
    assign copy_ram_clk_enable = copy_if.access_start ^ copy_ram_access_start_latch;
    always @(posedge clk_root) begin
        if (reset) begin
            copy_ram_access_start_latch <= 1'b0;
        end else if (copy_ram_clk_enable) begin
            copy_ram_access_start_latch <= copy_if.access_start;
        end else begin
        end
    end

    // Scratch front/back values before mapping into frame indices.
    types::mem_write_addr_t front_addr, back_addr;
    types::mem_write_data_t front_data, back_data;
    logic front_we;
    logic back_we;

    always_comb begin
        // Defaults: controller owns both frames, no writes yet.
        front_addr = ctrl_ram_address;
        back_addr  = ctrl_ram_address;
        front_data = ctrl_ram_data_out;
        back_data  = ctrl_ram_data_out;
        front_we   = 1'b0;
        back_we    = 1'b0;
        ram_copy_mode = copy_if.active;
        ram_a_clk_enable = ctrl_ram_clk_enable;

        if (copy_if.active) begin
            // Copy engine reads front, writes back.
            front_addr = types::mem_write_addr_t'(copy_if.read_addr);
            back_addr  = types::mem_write_addr_t'(copy_if.write_addr);
            front_data = types::mem_write_data_t'(8'h00);
            back_data  = copy_if.write_data_out;
            back_we    = copy_if.write_enable;
            ram_a_clk_enable = copy_ram_clk_enable;
        end else begin
            // Controller writes target the back buffer.
            back_we = ctrl_ram_write_enable;
        end

        // Map front/back into concrete frames.
        if (frame_select) begin  // 0=back, 1=front
            ram_a_address_frames[FRAME0_IDX] = back_addr;
            ram_a_address_frames[FRAME1_IDX] = front_addr;
            ram_a_data_in_frames[FRAME0_IDX] = back_data;
            ram_a_data_in_frames[FRAME1_IDX] = front_data;
            ram_a_write_enable_frames[FRAME0_IDX] = back_we;
            ram_a_write_enable_frames[FRAME1_IDX] = front_we;
            ram_b_data_out = ram_b_data_out_frames[FRAME1_IDX];
            copy_if.read_data_in = ram_a_data_out_frames[FRAME1_IDX];
        end else begin  // 0=front, 1=back
            ram_a_address_frames[FRAME0_IDX] = front_addr;
            ram_a_address_frames[FRAME1_IDX] = back_addr;
            ram_a_data_in_frames[FRAME0_IDX] = front_data;
            ram_a_data_in_frames[FRAME1_IDX] = back_data;
            ram_a_write_enable_frames[FRAME0_IDX] = front_we;
            ram_a_write_enable_frames[FRAME1_IDX] = back_we;
            ram_b_data_out = ram_b_data_out_frames[FRAME0_IDX];
            copy_if.read_data_in = ram_a_data_out_frames[FRAME0_IDX];
        end
    end
`else
    // Single-buffer build: controller directly drives frame 0.
    always_comb begin
        ram_copy_mode = 1'b0;
        ram_a_address_frames[FRAME0_IDX] = ctrl_ram_address;
        ram_a_data_in_frames[FRAME0_IDX] = ctrl_ram_data_out;
        ram_a_write_enable_frames[FRAME0_IDX] = ctrl_ram_write_enable;
        ram_a_clk_enable = ctrl_ram_clk_enable;
        ram_b_data_out = ram_b_data_out_frames[FRAME0_IDX];
    end
`endif

    genvar frame_idx;
    generate
        for (frame_idx = 0; frame_idx < params::NUM_FRAMEBUFFERS; frame_idx = frame_idx + 1) begin : gen_fb
            multimem #(
                ._UNUSED('d0)
            ) fb (
                .ClockA(clk_root),
                .AddressA(ram_a_address_frames[frame_idx]),
                .DataInA(ram_a_data_in_frames[frame_idx]),
                .WrA(ram_a_write_enable_frames[frame_idx]),
                .ResetA(reset),
                .ClockB(clk_root),
                .DataInB(16'b0),
                .AddressB(ram_b_address),
                .WrB(1'b0),
                .ResetB(reset),
                .CopyMode(ram_copy_mode),
                .QA(ram_a_data_out_frames[frame_idx]),
                .QB(ram_b_data_out_frames[frame_idx]),
                .ClockEnA(ram_a_clk_enable),
                .ClockEnB(ram_b_clk_enable)
            );
        end
    endgenerate
endmodule
