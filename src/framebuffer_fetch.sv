// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module framebuffer_fetch #(
    parameter integer unsigned BYTES_PER_PIXEL = params::BYTES_PER_PIXEL,
    parameter integer unsigned PIXEL_HEIGHT = params::PIXEL_HEIGHT,
    parameter integer unsigned PIXEL_WIDTH = params::PIXEL_WIDTH,
    parameter integer unsigned PIXEL_HALFHEIGHT = params::PIXEL_HALFHEIGHT,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,


    // appears that framebuffer fetch broke things, may have an issue here 20250710
    // [5:0] 64 width
    input types::col_addr_t column_address,
    // [3:0] 16 height (top/bottom half)
    input types::row_subpanel_addr_t row_address,

    input pixel_load_start,

    // [15:0] each fetch is one pixel worth of data -- no longer true
    input [calc::num_data_b_bits(PIXEL_HEIGHT, BYTES_PER_PIXEL, PIXEL_HALFHEIGHT)-1:0] ram_data_in,
    // [10:0]
    output [calc::num_address_b_bits(PIXEL_WIDTH, PIXEL_HALFHEIGHT)-1:0] ram_address,
    output ram_clk_enable,
`ifdef DEBUGGER
    output [3:0] pixel_load_counter2,
`endif
    // [15:0]
    output logic [calc::num_pixeldata_bits(BYTES_PER_PIXEL)-1:0] pixeldata_top,
    output logic [calc::num_pixeldata_bits(BYTES_PER_PIXEL)-1:0] pixeldata_bottom

);
    wire ram_clk_enable_real;
    assign ram_clk_enable = ram_clk_enable_real;
    /* grab data on falling edge of pixel clock */
    //wire pixel_load_running;
    wire [1:0] pixel_load_counter;
`ifdef DEBUGGER
    assign pixel_load_counter2[3:0] = {2'b0, pixel_load_counter[1:0]};
`endif

    // [10:0]
    assign ram_address = {
        //    half_address,
        row_address,
        // log2(128)==7-1=6
        column_address
    };

    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_pixel_load (
        .reset  (reset),
        .clk_in (clk_in),
        .start  (pixel_load_start),
`ifdef USE_FM6126A
        .value  (2'd2),
`else
        .value  (2'd3),
`endif
        .counter(pixel_load_counter),
        .running(ram_clk_enable_real)
    );

    always @(posedge clk_in) begin
        if (reset) begin
            pixeldata_top <= {calc::num_pixeldata_bits(BYTES_PER_PIXEL) {1'b0}};
            pixeldata_bottom <= {calc::num_pixeldata_bits(BYTES_PER_PIXEL) {1'b0}};
        end else begin
            if (pixel_load_counter == 'd2) begin
                {pixeldata_bottom, pixeldata_top} <= ram_data_in;
            end
        end
    end
endmodule
