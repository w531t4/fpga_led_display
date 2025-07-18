`default_nettype none
module ff_sync #(
    /* Delays signal by a clock cycle */
    // verilator lint_off UNUSEDPARAM
    parameter INIT_STATE = 1,
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input clk,
    input signal,
    input reset,

    output sync_signal
);

    logic temp;
    logic sync;
    assign sync_signal = sync;
    // Double flip-flop synchronizer
    always_ff @(posedge clk or posedge reset) begin
        if (reset) begin
            temp <= INIT_STATE;
        end else begin
            temp <= signal;
            sync <= temp;
        end
    end
endmodule
