// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module framebuffer_fetch #(
    `include "params.vh"
    `include "memory_calcs.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,


    // appears that framebuffer fetch broke things, may have an issue here 20250710
    // [5:0] 64 width
    input [_NUM_COLUMN_ADDRESS_BITS-1:0] column_address,
    // [3:0] 16 height (top/bottom half)
    input [$clog2(PIXEL_HALFHEIGHT)-1:0] row_address,

    input pixel_load_start,

    // [15:0] each fetch is one pixel worth of data -- no longer true
    input [_NUM_DATA_B_BITS-1:0] ram_data_in,
    // [10:0]
    output [_NUM_ADDRESS_B_BITS-1:0] ram_address,
    output ram_clk_enable,

    // [15:0]
    output logic [_NUM_BITS_PER_SUBPANEL-1:0] pixeldata_top,
    output logic [_NUM_BITS_PER_SUBPANEL-1:0] pixeldata_bottom
    `ifdef DEBUGGER
        ,
        output [3:0] pixel_load_counter2
    `endif

);
    wire ram_clk_enable_real;
    assign ram_clk_enable = ram_clk_enable_real;
    /* grab data on falling edge of pixel clock */
    //wire pixel_load_running;
    wire [1:0] pixel_load_counter;
    `ifdef DEBUGGER
        assign pixel_load_counter2[3:0] = { 2'b0, pixel_load_counter[1:0] };
    `endif

    // [10:0]
    assign ram_address = {
                        //    half_address,
                           row_address[$clog2(PIXEL_HALFHEIGHT)-1:0],
                           // log2(128)==7-1=6
                           column_address[_NUM_COLUMN_ADDRESS_BITS-1:0] };

    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_pixel_load (
        .reset(reset),
        .clk_in(clk_in),
        .start(pixel_load_start),
        `ifdef USE_FM6126A
            .value(2'd2),
        `else
            .value(2'd3),
        `endif
        .counter(pixel_load_counter),
        .running(ram_clk_enable_real)
    );

    always @(posedge clk_in, posedge reset) begin
        if (reset) begin
            pixeldata_top    <= {_NUM_BITS_PER_SUBPANEL{1'b0}};
            pixeldata_bottom <= {_NUM_BITS_PER_SUBPANEL{1'b0}};
        end
        else begin
            if (pixel_load_counter == 'd1) begin
                {pixeldata_bottom, pixeldata_top} <= ram_data_in;
            end
        end
    end
endmodule
