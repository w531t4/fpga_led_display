`default_nettype none
module brightness_timeout #(
    parameter integer N = 8,
    parameter integer BASE_TIMEOUT = 10,
    parameter integer TIMEOUT_WIDTH = $clog2(BASE_TIMEOUT) + N,
    parameter integer STATE_TIMEOUT_OVERLAP = 'd67
) (
    input  wire [N-1:0] brightness_mask_active,
    input wire clk_in,
    input wire reset,
    input wire row_latch,
    output wire output_enable,
    output wire exceeded_overlap_time
);
    wire [TIMEOUT_WIDTH-1:0] brightness_timeout; /* used to time the output enable period */
    wire [$clog2(N+1)-1:0] active_bits = $countones(brightness_mask_active);
    wire one_hot = (active_bits == 1);
    wire [TIMEOUT_WIDTH-1:0] brightness_counter;

    // Priority encoder
    integer i;
    reg [$clog2(N)-1:0] bit_index;
    always @* begin
        bit_index = 0;
        for (i = N-1; i >= 0; i = i - 1) begin
            if (brightness_mask_active[i])
                bit_index = ($clog2(N))'(i);
        end
    end

    wire [TIMEOUT_WIDTH-1:0] shifted = (TIMEOUT_WIDTH)'(BASE_TIMEOUT << bit_index);

    assign brightness_timeout = one_hot ? shifted : {{(TIMEOUT_WIDTH-1){1'b0}}, 1'b1};

    /* produces the variable-width output enable signal
       this signal is controlled by the rolling brightness_mask_active signal (brightness_mask has advanced already)
       the wider the output_enable pulse, the brighter the LEDs */
    /* this shoud never be < 1us though, apparently TODO: need to prove*/

    timeout #(
        .COUNTER_WIDTH(TIMEOUT_WIDTH)
    ) timeout_output_enable (
        .reset(reset),
        .clk_in(clk_in),
        .start(~row_latch),
        .value(brightness_timeout),
        .counter(brightness_counter),
        .running(output_enable)
    );

    assign exceeded_overlap_time = (STATE_TIMEOUT_OVERLAP < brightness_counter);

endmodule
