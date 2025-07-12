`default_nettype none
module matrix_scan #(
    parameter PIXEL_WIDTH = 'd64,
    parameter PIXEL_HEIGHT = 'd32,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,

    // [5:0]  64 width
    output [$clog2(PIXEL_WIDTH)-1:0] column_address,         /* the current column (clocking out now) */
    // [3:0] 16 height rows (two of them)
    output logic [$clog2(PIXEL_HEIGHT)-1:0] row_address,        /* the current row (clocking out now) */
    // [3:0] 16 height rows (two of them)
    output logic [$clog2(PIXEL_HEIGHT)-1:0] row_address_active, /* the active row (LEDs enabled) */

    output clk_pixel_load,
    output clk_pixel,
    output row_latch,
    output output_enable, /* the minimum output enable pulse should not be shorter than 1us... */

    output logic [5:0] brightness_mask, /* used to pick a bit from the sub-pixel's brightness */
    output row_latch2,
    output state_advance2,
`ifndef USE_FM6126A
    output [1:0] row_latch_state2,
`else
    output [3:0] row_latch_state2,
`endif
    output clk_pixel_load_en2 );

    localparam state_timeout_overlap = 'd67;

    logic [1:0] state;
    wire clk_state;
    wire state_advance;

    wire clk_pixel_load_en;/* enables the pixel load clock */
    logic  clk_pixel_en;    /* enables the pixel clock, delayed by one cycle from the load clock */
`ifndef USE_FM6126A
    logic  [1:0] row_latch_state;
`else
    logic  [3:0] row_latch_state;
    wire [6:0] clk_pixel_load_en_counter;
    localparam LATCH_WIDTH = 'd3;
`endif

    //wire clk_row_address; /* on the falling edge, feed the row address to the active signals */

    logic  [5:0] brightness_mask_active; /* the active mask value (LEDs enabled)... from before the state advanced */
    wire [9:0] brightness_timeout;     /* used to time the output enable period */
    wire [9:0] brightness_counter;     /* used to control the state advance overlap */

    assign clk_pixel_load = clk_in && clk_pixel_load_en;
    assign clk_pixel = clk_in && clk_pixel_en;
`ifndef USE_FM6126A
    wire [6:0] unused_7bit_counter;
    assign row_latch = row_latch_state[1:0] == 2'b10;
`else
    assign row_latch = (row_latch_state[3:0] == 4'b0010) || (row_latch_state[3:0] == 4'b0100) || (row_latch_state[3:0] == 4'b1000);
`endif
    assign clk_state = state == 2'b10;

    assign clk_pixel_load_en2 = clk_pixel_load_en;
    assign row_latch_state2 = row_latch_state[1:0];
    assign row_latch2 = row_latch;
    assign state_advance2 = state_advance;
    wire unused_timer_runpin;
    /* produce 64 load clocks per line...
       external logic should present the pixel value on the rising edge */
    timeout #(
        // 7
        .COUNTER_WIDTH($clog2(PIXEL_WIDTH)+1)
    ) timeout_clk_pixel_load_en (
        .reset(reset),
        .clk_in(clk_in),
        .start(clk_state),
        // 7'd64
        .value(PIXEL_WIDTH),
`ifndef USE_FM6126A
        .counter(unused_7bit_counter),
`else
        .counter(clk_pixel_load_en_counter),
`endif
        .running(clk_pixel_load_en)
    );

    /* produce the column address
       counts from 63 -> 0 and then stops
       advances out-of-phase with the pixel clock */
    timeout #(
        // 6
        .COUNTER_WIDTH($clog2(PIXEL_WIDTH-1))
    ) timeout_column_address (
        .reset(reset),
        .clk_in(clk_in),
        .start(clk_state),
        // 6'd63
        .value(PIXEL_WIDTH-1),
        .counter(column_address),
        .running(unused_timer_runpin)
    );

    /* produces the pixel clock enable signal and row_latch_state
       there are 64 pixels per row, this starts immediately after a state advance */
    always @(negedge clk_in) begin
        if (reset) begin
            clk_pixel_en <= 1'b1;
`ifndef USE_FM6126A
            row_latch_state <= 2'b1;
`else
            row_latch_state <= 4'b0001;
`endif
            brightness_mask <= 6'b100000;
            brightness_mask_active <= 6'd0;
            // 4'd0
            row_address <= {PIXEL_HEIGHT{1'b0}};
            row_address_active <= {PIXEL_HEIGHT{1'b0}};
        end
        else begin
            clk_pixel_en <= clk_pixel_load_en;
`ifndef USE_FM6126A
            row_latch_state <= { row_latch_state[0], clk_pixel_load_en };
`else
            row_latch_state <= { row_latch_state[2], row_latch_state[1], row_latch_state[0], clk_pixel_load_en_counter == ('d1 + LATCH_WIDTH) };
`endif
            /* on completion of the row_latch, we advanced the brightness mask to generate the next row of pixels */
            if (row_latch) begin
                brightness_mask_active <= brightness_mask;
                row_address_active <= row_address;

                if ((brightness_mask == 6'd0) || (brightness_mask == 6'b000001)) begin
                    // catch the initial value / oopsy //
                    brightness_mask <= 6'b100000;
                    // 4'd1
                    row_address <= row_address + 1;
                end
                else begin
                    brightness_mask <= brightness_mask >> 1;
                end
            end
            else begin
            end

        end
    end

    /* decide how long to enable the LEDs for... we probably need some gamma correction here */
    assign brightness_timeout =
        (brightness_mask_active == 6'b000001) ? 10'd23 :
        (brightness_mask_active == 6'b000010) ? 10'd46 :
        (brightness_mask_active == 6'b000100) ? 10'd92 :
        (brightness_mask_active == 6'b001000) ? 10'd184 :
        (brightness_mask_active == 6'b010000) ? 10'd368 :
        (brightness_mask_active == 6'b100000) ? 10'd736 :
        10'd1;

    /* produces the variable-width output enable signal
       this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
       the wider the output_enable pulse, the brighter the LEDs */
    /* this shoud never be < 1us though, apparently TODO: need to prove*/

    timeout #(
        .COUNTER_WIDTH(10)
    ) timeout_output_enable (
        .reset(reset),
        .clk_in(clk_in),
        .start(~row_latch),
        .value(brightness_timeout),
        .counter(brightness_counter),
        .running(output_enable)
    );

    /* we want to overlap the pixel clock out with the previous output
       enable... but we do not want to start too early... */
`ifndef USE_FM6126A
    assign state_advance = !output_enable || (state_timeout_overlap < brightness_counter);
`else
    assign state_advance = !output_enable || (state_timeout_overlap < (brightness_counter + LATCH_WIDTH));
`endif
    /* shift the state advance signal into the bitfield */
    always @(posedge clk_in) begin
        if (reset) begin
            state <= 2'b1;
        end
        else begin
            state <= { state[0], state_advance };
        end
    end

    wire _unused_ok = &{1'b0,
`ifndef USE_FM6126A
                        unused_7bit_counter,
`endif
                        unused_timer_runpin,
                        1'b0};
endmodule
