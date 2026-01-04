// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module matrix_scan #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,

    // [5:0]  64 width
    output types::col_addr_t column_address,  /* the current column (clocking out now) */
    // [3:0] 16 height rows (two of them)
    output types::row_subpanel_addr_t row_address,  /* the current row (clocking out now) */
    // [3:0] 16 height rows (two of them)
    output types::row_subpanel_addr_t row_address_active,  /* the active row (LEDs enabled) */

    output clk_pixel_load,
    output clk_pixel,
    output row_latch,
    output output_enable,   /* the minimum output enable pulse should not be shorter than 1us... */

`ifdef DEBUGGER
    output [1:0] row_latch_state2,
    output row_latch2,
    output state_advance2,
    output clk_pixel_load_en2,
`endif
    output types::brightness_level_t brightness_mask  /* used to pick a bit from the sub-pixel's brightness */
);

    function automatic types::brightness_level_t reset_brightness();
        reset_brightness = 1 << ($bits(types::brightness_level_t) - 1);
    endfunction

    typedef struct packed {
        types::brightness_level_t  brightness_mask;
        types::row_subpanel_addr_t row_address;
        types::col_addr_t          column_address;
    } state_t;

    state_t active;  /* the active X (What is shown on the LED's) -- from before the state advance */
    state_t current;  /* the current X (clocking out now) */

    assign column_address = current.column_address;
    assign row_address = current.row_address;
    assign brightness_mask = current.brightness_mask;
    assign row_address_active = active.row_address;
    assign active.column_address = '0;  // unused

    typedef logic [1:0] scan_state_t;
    scan_state_t state;
    wire clk_state;
    wire state_advance;

    wire clk_pixel_load_en;  /* enables the pixel load clock */
    logic clk_pixel_en;  /* enables the pixel clock, delayed by one cycle from the load clock */
    typedef logic [1:0] row_latch_state_t;
    row_latch_state_t row_latch_state;

    //wire clk_row_address; /* on the falling edge, feed the row address to the active signals */

    wire brightness_exceeded_overlap_time;

    assign clk_pixel_load = clk_in && clk_pixel_load_en;
    assign clk_pixel = clk_in && clk_pixel_en;

    wire types::col_addr_count_t pixel_load_en_counter_output;
    assign row_latch = row_latch_state == 2'b10;

    assign clk_state = state == 2'b10;
`ifdef DEBUGGER
    assign row_latch_state2 = row_latch_state[1:0];
    assign row_latch2 = row_latch;
    assign clk_pixel_load_en2 = clk_pixel_load_en;
    assign state_advance2 = state_advance;
`endif
    wire unused_timer_runpin;
    /* produce 64 load clocks per line...
       external logic should present the pixel value on the rising edge */
    timeout #(
        // 7
        .COUNTER_WIDTH($bits(types::col_addr_count_t))
    ) timeout_clk_pixel_load_en (
        .reset  (reset),
        .clk_in (clk_in),
        .start  (clk_state),
        // 7'd64
        .value  (types::col_addr_count_t'(params::PIXEL_WIDTH)),
        .counter(pixel_load_en_counter_output),
        .running(clk_pixel_load_en)
    );

    /* produce the column address
       counts from 63 -> 0 and then stops
       advances out-of-phase with the pixel clock */
    timeout #(
        // 6
        .COUNTER_WIDTH($bits(types::col_addr_t))
    ) timeout_column_address (
        .reset  (reset),
        .clk_in (clk_in),
        .start  (clk_state),
        // 6'd63
        .value  (types::col_addr_t'(params::PIXEL_WIDTH - 1)),
        .counter(current.column_address),
        .running(unused_timer_runpin)
    );

    /* produces the pixel clock enable signal and row_latch_state
       there are 64 pixels per row, this starts immediately after a state advance */
    always @(negedge clk_in) begin
        if (reset) begin
            clk_pixel_en <= 1'b1;
            row_latch_state <= 2'b01;
            current.brightness_mask <= reset_brightness();
            active.brightness_mask <= 'b0;
            // 4'd0
            current.row_address <= 'b0;
            active.row_address <= 'b0;
        end else begin
            clk_pixel_en <= clk_pixel_load_en;
            row_latch_state <= {row_latch_state[0], clk_pixel_load_en};
            /* on completion of the row_latch, we advanced the brightness mask to generate the next row of pixels */
            if (row_latch) begin
                active.brightness_mask <= current.brightness_mask;
                active.row_address <= current.row_address;

                if ((current.brightness_mask == 'd0) || (current.brightness_mask == 'd1)) begin
                    // catch the initial value / oopsy //
                    current.brightness_mask <= reset_brightness();
                    // 4'd1
                    current.row_address <= current.row_address + 1;
                end else begin
                    current.brightness_mask <= current.brightness_mask >> 1;
                end
            end else begin
            end

        end
    end

    brightness_timeout #(
        ._UNUSED('d0)
    ) btd (
        .clk_in(clk_in),
        .reset(reset),
        .row_latch(row_latch),
        .brightness_mask_active(active.brightness_mask),
        .output_enable(output_enable),
        .exceeded_overlap_time(brightness_exceeded_overlap_time)
    );

    /* we want to overlap the pixel clock out with the previous output
       enable... but we do not want to start too early... */
    assign state_advance = !output_enable || brightness_exceeded_overlap_time;
    /* shift the state advance signal into the bitfield */
    always @(posedge clk_in) begin
        if (reset) begin
            state <= 2'b01;
        end else begin
            state <= {state[0], state_advance};
        end
    end

    wire _unused_ok = &{1'b0, pixel_load_en_counter_output, unused_timer_runpin, active.column_address, 1'b0};
endmodule
