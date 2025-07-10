`default_nettype none
module debugger	#(
    parameter DIVIDER_TICKS = 28'd67000000,
    parameter DATA_WIDTH = 8,
    // 22MHz / 191 = 115183 baud
    parameter UART_TICKS_PER_BIT = 191
) (
    input clk_in,
    input reset,
    input [DATA_WIDTH-1:0] data_in,
    input debug_uart_rx_in,
    output tx_out,
    output logic debug_start,
    output logic [4:0] currentState,
    output logic do_close,
    output logic tx_start,
    output logic [$clog2(DATA_WIDTH):0] current_position,
    output [7:0] debug_command,
    output debug_command_pulse,
    output debug_command_busy
);

    logic [7:0] debug_bits;
    logic [$clog2(DIVIDER_TICKS)-1:0] count;

    // This essentially shows to debug messages sent via TX per second
    always @(posedge clk_in) begin
        if (reset) begin
            debug_start <= 0;
            count <= 0;
        end
        else begin
            if (count == DIVIDER_TICKS) begin
                debug_start <= 1;
                count <= 0;
            end
            else begin
                debug_start <= 0;
                count <= count + 1;
            end
        end
    end

    wire tx_busy;
    wire tx_done;
    logic [DATA_WIDTH-1:0] data_copy;

    initial begin

    end

    // i'm guessing we're doing this in an attempt to not spam negotiate on the
    // serial channel. we're looking roughly 22times a second?. It's been awhie since
    // i last looked at this.
    localparam	    STATE_IDLE 			= 5'b00001,
                    STATE_START       	= 5'b00010,
                    STATE_SEND  		= 5'b00100,
                    STATE_WAIT      	= 5'b01000;
    always @(posedge clk_in, posedge reset) begin
        if (reset) begin
            do_close <= 0;
            data_copy <= 0;
            currentState <= STATE_IDLE;
            current_position <= DATA_WIDTH;
            tx_start <= 0;
            debug_bits <= 0;
        end
        else begin
            //            if (debug_start && currentState == STATE_IDLE) begin
            if (debug_start && currentState == STATE_IDLE) begin
                current_position <= DATA_WIDTH;
                data_copy <= data_in[DATA_WIDTH-1:0];
                currentState <= STATE_START;
            end
            else if (currentState != STATE_IDLE) begin
                if (currentState == STATE_START) begin
                    if (current_position == 0) begin
                        do_close <= 1;
                    end
                    else begin
                    end
                    currentState <= STATE_SEND;
                end
                else if (currentState == STATE_SEND) begin
                    if (~tx_busy) begin
                        if (do_close) begin
                            debug_bits <= 8'b00001010; // newline
                        end
                        else begin
                            debug_bits <= data_copy[current_position-1 -: 8];
                            // latch 8 bits here from input
                        end
                        tx_start <= 1;
                        // latch bits onto tx here
                        currentState <= STATE_WAIT;
                    end
                    else begin
                    end
                end
                else if (currentState == STATE_WAIT) begin
                    tx_start <= 0;
                    if (~tx_busy) begin
                        if (do_close) begin
                            do_close <= 0;
                            currentState <= STATE_IDLE;
                        end
                        else begin
                            current_position <= current_position - 8;
                            currentState <= STATE_START;
                        end
                    end
                    else begin
                    end
                end
                else begin
                end
            end
        end
    end

    uart_rx #(
        .TICKS_PER_BIT(UART_TICKS_PER_BIT)
    ) mydebugrxuart (
        .reset(reset),
        .i_clk(clk_in),
        .i_enable(1'b1),
        .i_din_priortobuffer(debug_uart_rx_in),
        .o_rxdata(debug_command),
        .o_recvdata(debug_command_pulse),
        .o_busy(debug_command_busy)
    );

    uart_tx  #(
        .TICKS_PER_BIT(UART_TICKS_PER_BIT)
    ) txuart (
        .i_clk(clk_in),
        .i_start(tx_start),
        .i_data(debug_bits),
        .o_done(tx_done),
        .o_busy(tx_busy),
        .o_dout(tx_out)
    );

endmodule
