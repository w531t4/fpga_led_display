// SPDX-FileCopyrightText: 2025 Attie Grande <attie@attie.co.uk>
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none
module brightness_timeout #(
    parameter integer unsigned BRIGHTNESS_LEVELS = params::BRIGHTNESS_LEVELS,
    parameter integer BRIGHTNESS_BASE_TIMEOUT = params::BRIGHTNESS_BASE_TIMEOUT,
    parameter integer BRIGHTNESS_STATE_TIMEOUT_OVERLAP = params::BRIGHTNESS_STATE_TIMEOUT_OVERLAP,
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input types::brightness_level_t brightness_mask_active,
    input wire clk_in,
    input wire reset,
    input wire row_latch,
    output wire output_enable,
    output wire exceeded_overlap_time
);

    wire types::brightness_timeout_t brightness_timeout;  /* used to time the output enable period */
    typedef logic [$clog2(BRIGHTNESS_LEVELS)-1:0] brightness_index_t;
    typedef logic [$clog2(BRIGHTNESS_LEVELS + 1)-1:0] brightness_count_t;
    wire brightness_count_t active_bits = $countones(brightness_mask_active);
    wire one_hot = (active_bits == 1);
    wire types::brightness_timeout_t brightness_counter;

    // Priority encoder
    integer i;
    brightness_index_t bit_index;
    always_comb begin
        bit_index = 0;
        for (i = BRIGHTNESS_LEVELS - 1; i >= 0; i = i - 1) begin
            if (brightness_mask_active[i]) bit_index = brightness_index_t'(i);
        end
    end

    wire types::brightness_timeout_t shifted = types::brightness_timeout_t'(BRIGHTNESS_BASE_TIMEOUT << bit_index);

    assign brightness_timeout = one_hot ? shifted : types::brightness_timeout_t'(1);

    /* produces the variable-width output enable signal
       this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
       the wider the output_enable pulse, the brighter the LEDs */
    /* this shoud never be < 1us though, apparently TODO: need to prove*/

    timeout #(
        .COUNTER_WIDTH($bits(types::brightness_timeout_t))
    ) timeout_output_enable (
        .reset  (reset),
        .clk_in (clk_in),
        .start  (~row_latch),
        .value  (brightness_timeout),
        .counter(brightness_counter),
        .running(output_enable)
    );

    assign exceeded_overlap_time = (BRIGHTNESS_STATE_TIMEOUT_OVERLAP < brightness_counter);

endmodule
