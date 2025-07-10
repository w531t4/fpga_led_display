`default_nettype none
    /* apply the brightness mask to the calculated sub-pixel value */
    /*
    wire masked_value = (value & mask) != 0;

    assign out = masked_value && enable;
*/

/*
#include <Arduino.h>
#include <ESP32-RGB64x32MatrixPanel-I2S-DMA.h>

RGB64x32MatrixPanel_I2S_DMA matrix;

////////////////////////////////////////////////////////////////////
// Reset Panel
// This needs to be near the top of the code
//
// Change these to whatever suits
// recommended settings and patches are by
//
// pinout for ESP38 38pin module
// http://arduinoinfo.mywikis.net/wiki/Esp32#KS0413_keyestudio_ESP32_Core_Board
//

// R1 | G1
// B1 | GND
// R2 | G2
// B2 | E
// A | B
// C | D
// CLK| LAT
// OE | GND

#define R1 25
#define G1 26
#define BL1 27
#define R2 5 // 21 SDA
#define G2 19 // 22 SDL
#define BL2 23
#define CH_A 12
#define CH_B 16
#define CH_C 17
#define CH_D 18
#define CH_E 14 // assign to pin if using two panels
#define CLK 2
#define LAT 32
#define OE 33

/////////////////////////////////////////////////////////////////
// how many pixels wide if you chain panels
// 4 panels of 64x32 is 256 wide.
int MaxLed = 128;

int C12[16] = {0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};
int C13[16] = {0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0};

void resetPanel()	{
    pinMode(CLK, OUTPUT);
    pinMode(LAT, OUTPUT);
    pinMode(OE, OUTPUT);
    pinMode(R1, OUTPUT);
    pinMode(G1, OUTPUT);
    pinMode(BL1, OUTPUT);
    pinMode(R2, OUTPUT);
    pinMode(G2, OUTPUT);
    pinMode(BL2, OUTPUT);
    pinMode(CH_A, OUTPUT);
    pinMode(CH_B, OUTPUT);
    pinMode(CH_C, OUTPUT);
    pinMode(CH_D, OUTPUT);
    pinMode(CH_E, OUTPUT);

    // Send Data to control register 11
    digitalWrite(OE, HIGH); // Display reset
    digitalWrite(LAT, LOW);
    digitalWrite(CLK, LOW);
    for (int l = 0; l < MaxLed; l++) {
        int y = l % 16; // y will be {0, 1, 2, 3}
        digitalWrite(R1, LOW);
        digitalWrite(G1, LOW);
        digitalWrite(BL1, LOW);
        digitalWrite(R2, LOW);
        digitalWrite(G2, LOW);
        digitalWrite(BL2, LOW);
        if (C12[y] == 1) {
            digitalWrite(R1, HIGH);
            digitalWrite(G1, HIGH);
            digitalWrite(BL1, HIGH);
            digitalWrite(R2, HIGH);
            digitalWrite(G2, HIGH);
            digitalWrite(BL2, HIGH);
        }
        if (l > MaxLed - 12) {
            digitalWrite(LAT, HIGH);
        } else {
            digitalWrite(LAT, LOW);
        }
        digitalWrite(CLK, HIGH);
        digitalWrite(CLK, LOW);
    }
    digitalWrite(LAT, LOW);
    digitalWrite(CLK, LOW);
    // Send Data to control register 12
    for (int l = 0; l < MaxLed; l++) {
        int y = l % 16;
        digitalWrite(R1, LOW);
        digitalWrite(G1, LOW);
        digitalWrite(BL1, LOW);
        digitalWrite(R2, LOW);
        digitalWrite(G2, LOW);
        digitalWrite(BL2, LOW);
        if (C13[y] == 1) {
            digitalWrite(R1, HIGH);
            digitalWrite(G1, HIGH);
            digitalWrite(BL1, HIGH);
            digitalWrite(R2, HIGH);
            digitalWrite(G2, HIGH);
            digitalWrite(BL2, HIGH);
        }
        if (l > MaxLed - 13) {
            digitalWrite(LAT, HIGH);
        } else {
            digitalWrite(LAT, LOW);
        }
        digitalWrite(CLK, HIGH);
        digitalWrite(CLK, LOW);
    }
    digitalWrite(LAT, LOW);
    digitalWrite(CLK, LOW);
}
*/

module fm6126init
// (
//	clk_in, reset, output_enable, rgb1, rgb2, latch, done
//	//adopted from https://github.com/mrfaptastic/ESP32-HUB75-MatrixPanel-DMA/issues/23
//)
(
    input clk_in,
    input reset,
    output reg [2:0] rgb1_out,
    output reg [2:0] rgb2_out,
    output reg latch_out,
    output reg mask_en,
    output reg pixclock_out,
    output reg reset_notify
    );

    reg [15:0] C12;
    reg [15:0] C13;
    reg [7:0] currentState;
    reg [5:0] widthCounter; // 16 bits

    //TODO: how do i not manually specify 64 here?
    localparam LED_WIDTH = 'd64; // 64 pixel width led display
    reg [LED_WIDTH - 1:0] widthState;

    localparam STAGE1_OFFSET = 'd12,
               STAGE2_OFFSET = 'd13;


    localparam		STATE_INIT		 = 8'b00000001,
                    STATE1_BEGIN     = 8'b00000010,
                    STATE1_END       = 8'b00000100,
                    STATE2_PREBEGIN  = 8'b00001000,
                    STATE2_BEGIN     = 8'b00010000,
                    STATE2_END       = 8'b00100000,
                    STATE_FINISH     = 8'b01000000,
                    STATE_FINISH2    = 8'b10000000;
// End of default setup for RGB Matrix 64x32 panel
    always @(posedge clk_in, posedge reset) begin
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
        end
        else begin
            if (currentState == STATE1_BEGIN) begin
                currentState <= STATE1_END;
                // ({LED_WIDTH{1'b1}}) <-- create LED_WIDTH bit register prefilled with 1's
                // (see_above >> (LED_WIDTH - STAGE1_OFFSET)) <-- shift right STAGE1_OFFSET bits
                //												  thereby leaving 0's at the left side
                // (| see_above) <-- boolean OR each bit of the register and return the result
                //					 This portion is critical, because eventually we'll shift enough
                //					 such that we hit the "remaining n bits". In that case,
                //					 it'll yield a 0, which we'll then invert and use as an indicator
                //					 to set the latch
                // (! see_above) <-- invert the result
                latch_out <= (~ (| widthState));
                pixclock_out <= 1'b0;
                // shift right one, regardless
                rgb1_out[2:0] <= {C12[widthCounter % 'd16], C12[widthCounter % 'd16], C12[widthCounter % 'd16]};
                rgb2_out[2:0] <= {C12[widthCounter % 'd16], C12[widthCounter % 'd16], C12[widthCounter % 'd16]};
            end
            // reached STATE1_END and we've counted all the pixels, move to stage 2
            else if (currentState == STATE1_END && (~ (| (widthCounter + 1'b1)))) begin
                currentState <= STATE2_BEGIN;
                latch_out <= 1'b0;
                pixclock_out <= 1'b1;
                widthState <= ({LED_WIDTH{1'b1}}) >> (STAGE2_OFFSET + 1'b1);
                widthCounter <= 'd0;
            end
            else if (currentState == STATE1_END) begin
                currentState <= STATE1_BEGIN;
                pixclock_out <= 1'b1;
                widthState <= (widthState) >> 1;
                widthCounter <= widthCounter + 1'b1;
            end
            else if (currentState == STATE2_BEGIN) begin
                currentState <= STATE2_END;
                // ({LED_WIDTH{1'b1}}) <-- create LED_WIDTH bit register prefilled with 1's
                // (see_above >> (LED_WIDTH - STAGE1_OFFSET)) <-- shift right STAGE1_OFFSET bits
                //												  thereby leaving 0's at the left side
                // (| see_above) <-- boolean OR each bit of the register and return the result
                //					 This portion is critical, because eventually we'll shift enough
                //					 such that we hit the "remaining n bits". In that case,
                //					 it'll yield a 0, which we'll then invert and use as an indicator
                //					 to set the latch
                // (! see_above) <-- invert the result
                latch_out <= (~ (| widthState));
                // shift right one, regardless
                pixclock_out <= 1'b0;
                rgb1_out <= {C13[widthCounter % 'd16], C13[widthCounter % 'd16], C13[widthCounter % 'd16]};
                rgb2_out <= {C13[widthCounter % 'd16], C13[widthCounter % 'd16], C13[widthCounter % 'd16]};
            end
            else if (currentState == STATE2_END && (~ (| (widthCounter + 1'b1)))) begin
                currentState <= STATE_FINISH;
                latch_out <= 1'b0;
                reset_notify <= 1'b1;
                widthCounter <= 'd0;
            end
            else if (currentState == STATE2_END) begin
                currentState <= STATE2_BEGIN;
                pixclock_out <= 1'b1;
                widthState <= (widthState) >> 1;
                widthCounter <= widthCounter + 1'b1;
            end
            else if (currentState == STATE_FINISH) begin
                currentState <= STATE_FINISH2;
                pixclock_out <= 1'b0;
            end
            else if (currentState == STATE_FINISH2) begin
                mask_en <= 1'b1;
                reset_notify <= 1'b0;
            end
            else if (currentState == STATE_INIT) begin
                currentState <= STATE1_BEGIN;
                // not setting clock low, because that happens automatically.
                widthCounter <= 4'd0;
                // when widthState becomes all zero, set latch
                // grow 1'b1 to LED_WIDTH bits in length. See description below
                widthState <= ({LED_WIDTH{1'b1}}) >> (STAGE1_OFFSET + 1'b1);
                mask_en <= 1'b0;
                pixclock_out <= 1'b1;
            end
        end
    end
endmodule
