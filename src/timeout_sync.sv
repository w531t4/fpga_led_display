`default_nettype none
/* a timeout module... output is de-asserted after the counter expires
    clk_in        - input clock, keep it running
    start         - counter resets/begins when becomes high
                    sampled on clk_in rising edge
    value         - count-down reset value
                    captured on the rising edge of clk_in, when start is first high
    running       - is the counter still running?
*/
module timeout_sync #(
    parameter COUNTER_WIDTH = 8,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in,
    input start,

    input [COUNTER_WIDTH - 1:0] value,
    output logic [COUNTER_WIDTH - 1:0] counter,

    output running
);
    logic start_latch;

    assign running = counter != 0;

    always @(posedge clk_in) begin
        if (reset) begin
            counter <= 'b0;
            start_latch <= 1'b0;
        end
        else begin
            if (start && !start_latch) begin
                counter <= value;
            end
            else if (counter != 0) begin
                counter <= counter - 'd1;
            end
            else begin
            end
            start_latch <= start;
        end
    end
endmodule
