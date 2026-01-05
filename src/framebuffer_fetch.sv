// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module framebuffer_fetch #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    input types::col_addr_t column_address,
    input types::row_subpanel_addr_t row_address,

    input pixel_load_start,
    input types::mem_read_data_t ram_data_in,
    output types::mem_read_addr_t ram_address,
    output ram_clk_enable,
`ifdef DEBUGGER
    output [3:0] pixel_load_counter2,
`endif
    output types::color_field_t pixeldata_top,
    output types::color_field_t pixeldata_bottom

);
    /* grab data on falling edge of pixel clock */
    wire [1:0] pixel_load_counter;
`ifdef DEBUGGER
    assign pixel_load_counter2[3:0] = {2'b0, pixel_load_counter[1:0]};
`endif

    assign ram_address = {row_address, column_address};

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
        .running(ram_clk_enable)
    );

    always @(posedge clk_in) begin
        if (reset) begin
            pixeldata_top <= 'b0;
            pixeldata_bottom <= 'b0;
        end else begin
            if (pixel_load_counter == 'd2) begin
                pixeldata_bottom <= ram_data_in.subpanel[1].field;
                pixeldata_top <= ram_data_in.subpanel[0].field;
            end
        end
    end
endmodule
