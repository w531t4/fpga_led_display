module reset_on_start (clock_in, reset);
    input wire clock_in;
    output wire reset;
    reg count;
    reg objective;

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
        .counter(),
        .running(reset)
    );

endmodule
