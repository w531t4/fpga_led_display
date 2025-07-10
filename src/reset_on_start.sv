`default_nettype none
module reset_on_start (
    input wire clock_in,
    output wire reset
);
    logic count;
    logic objective;

    wire [3:0] unused_timer_counter;
    initial begin
        count = 1'b0;
        objective = 1'b0;
    end

    always @(posedge clock_in) begin
        if (objective == 1'b0 && count == 1'b0) begin
            count <= ~count;
        end else if (objective == 1'b0 && count == 1'b1) begin
            objective <= 1'b1;
            count <= ~count;
        end
    end
    timeout_sync #(
        .COUNTER_WIDTH(4)
    ) reset_on_start_timeout (
        .reset(count),
        .clk_in(clock_in),
        .start(objective),
        .value(4'd15),
        .counter(unused_timer_counter),
        .running(reset)
    );
    wire _unused_ok = &{1'b0,
                        unused_timer_counter,
                        1'b0};
endmodule
