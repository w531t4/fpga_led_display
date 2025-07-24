`default_nettype none
module control_cmd_readbrightness #(
    `include "params.vh"
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input [7:0] data_in,
    input clk_n,
    input enable,

    output logic [BRIGHTNESS_LEVELS-1:0] data_out,
    output logic brightness_change_en,
    output logic done
);
    typedef enum {STATE_READY,
                  STATE_READ_BRIGHTNESS
                  } ctrl_fsm;
    ctrl_fsm state;
    always @(negedge clk_n, posedge reset) begin
        if (reset) begin
            data_out <= {BRIGHTNESS_LEVELS{1'b0}};
            done <= 1'b0;
            state <= STATE_READY;
            brightness_change_en <= 1'b0;
        end
        else if (enable) begin
            case (state)
                STATE_READY: begin
                    done <= 1'b1;
                    brightness_change_en <= 1'b1;
                    data_out <= data_in[BRIGHTNESS_LEVELS-1:0];
                    state <= STATE_READ_BRIGHTNESS;
                end
                STATE_READ_BRIGHTNESS: begin
                    done <= 1'b0;
                    brightness_change_en <= 1'b0;
                    data_out <= 8'b0;
                    state <= STATE_READY;
                end
            endcase
        end
    end
endmodule
