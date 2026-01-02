// SPDX-License-Identifier: MIT
// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// This code is a verilog implemenation of mrcodetastic's c/c++ implemenation
// found here: https://github.com/mrfaptastic/ESP32-HUB75-MatrixPanel-DMA/issues/23
`default_nettype none
module fm6126init #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input clk_in,
    input reset,
    output logic [2:0] rgb1_out,
    output logic [2:0] rgb2_out,
    output logic latch_out,
    output logic mask_en,
    output logic pixclock_out,
    output logic reset_notify
);
    typedef enum logic [2:0] {
        STATE_INIT,
        STATE1_BEGIN,
        STATE1_END,
        STATE2_BEGIN,
        STATE2_END,
        STATE_FINISH,
        STATE_FINISH2
    } state_e;
    logic [15:0] C12;
    logic [15:0] C13;
    state_e currentState;
    logic [ 5:0] widthCounter;  // 16 bits

    //TODO: how do i not manually specify 64 here?
    localparam integer unsigned LED_WIDTH = 'd64;  // 64 pixel width led display
    logic [LED_WIDTH - 1:0] widthState;

    localparam integer unsigned STAGE1_OFFSET = 'd12, STAGE2_OFFSET = 'd13;

    // End of default setup for RGB Matrix 64x32 panel
    always @(posedge clk_in) begin
        if (reset) begin
            C12 <= 16'b0111111111111111;
            C13 <= 16'b0000000001000000;
            currentState <= STATE_INIT;
            widthState <= {LED_WIDTH{1'b0}};
            widthCounter <= 6'd0;
            rgb1_out <= 3'b0;
            rgb2_out <= 3'b0;
            latch_out <= 1'b0;
            pixclock_out <= 1'b0;
            reset_notify <= 1'b0;
            mask_en <= 1'b1;
        end else begin
            if (currentState == STATE1_BEGIN) begin
                currentState <= STATE1_END;
                // ({LED_WIDTH{1'b1}}) <-- create LED_WIDTH bit register prefilled with 1's
                // (see_above >> (LED_WIDTH - STAGE1_OFFSET)) <-- shift right STAGE1_OFFSET bits
                //                                                thereby leaving 0's at the left side
                // (| see_above) <-- boolean OR each bit of the register and return the result
                //                   This portion is critical, because eventually we'll shift enough
                //                   such that we hit the "remaining n bits". In that case,
                //                   it'll yield a 0, which we'll then invert and use as an indicator
                //                   to set the latch
                // (! see_above) <-- invert the result
                latch_out <= (~(|widthState));
                pixclock_out <= 1'b0;
                // shift right one, regardless
                rgb1_out[2:0] <= {C12[widthCounter%'d16], C12[widthCounter%'d16], C12[widthCounter%'d16]};
                rgb2_out[2:0] <= {C12[widthCounter%'d16], C12[widthCounter%'d16], C12[widthCounter%'d16]};
            end  // reached STATE1_END and we've counted all the pixels, move to stage 2
            else if (currentState == STATE1_END && (~(|(widthCounter + 1'b1)))) begin
                currentState <= STATE2_BEGIN;
                latch_out <= 1'b0;
                pixclock_out <= 1'b1;
                widthState <= ({LED_WIDTH{1'b1}}) >> (STAGE2_OFFSET + 1'b1);
                widthCounter <= 'd0;
            end else if (currentState == STATE1_END) begin
                currentState <= STATE1_BEGIN;
                pixclock_out <= 1'b1;
                widthState   <= (widthState) >> 1;
                widthCounter <= widthCounter + 1'b1;
            end else if (currentState == STATE2_BEGIN) begin
                currentState <= STATE2_END;
                // ({LED_WIDTH{1'b1}}) <-- create LED_WIDTH bit register prefilled with 1's
                // (see_above >> (LED_WIDTH - STAGE1_OFFSET)) <-- shift right STAGE1_OFFSET bits
                //                                                thereby leaving 0's at the left side
                // (| see_above) <-- boolean OR each bit of the register and return the result
                //                   This portion is critical, because eventually we'll shift enough
                //                   such that we hit the "remaining n bits". In that case,
                //                   it'll yield a 0, which we'll then invert and use as an indicator
                //                   to set the latch
                // (! see_above) <-- invert the result
                latch_out <= (~(|widthState));
                // shift right one, regardless
                pixclock_out <= 1'b0;
                rgb1_out <= {C13[widthCounter%'d16], C13[widthCounter%'d16], C13[widthCounter%'d16]};
                rgb2_out <= {C13[widthCounter%'d16], C13[widthCounter%'d16], C13[widthCounter%'d16]};
            end else if (currentState == STATE2_END && (~(|(widthCounter + 1'b1)))) begin
                currentState <= STATE_FINISH;
                latch_out <= 1'b0;
                reset_notify <= 1'b1;
                widthCounter <= 'd0;
            end else if (currentState == STATE2_END) begin
                currentState <= STATE2_BEGIN;
                pixclock_out <= 1'b1;
                widthState   <= (widthState) >> 1;
                widthCounter <= widthCounter + 1'b1;
            end else if (currentState == STATE_FINISH) begin
                currentState <= STATE_FINISH2;
                pixclock_out <= 1'b0;
            end else if (currentState == STATE_FINISH2) begin
                mask_en <= 1'b1;
                reset_notify <= 1'b0;
            end else if (currentState == STATE_INIT) begin
                currentState <= STATE1_BEGIN;
                // not setting clock low, because that happens automatically.
                widthCounter <= 'd0;
                // when widthState becomes all zero, set latch
                // grow 1'b1 to LED_WIDTH bits in length. See description below
                widthState <= ({LED_WIDTH{1'b1}}) >> (STAGE1_OFFSET + 1'b1);
                mask_en <= 1'b0;
                pixclock_out <= 1'b1;
            end
        end
    end
endmodule
