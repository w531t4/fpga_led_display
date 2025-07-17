`default_nettype none
module control_module #(
    /* UART configuration */
    // we want 22MHz / 2,430,000 = 9.0534
    // 22MHz / 9 = 2,444,444 baud 2444444
    parameter UART_CLK_TICKS_PER_BIT = 6'd9,
    parameter PIXEL_WIDTH = 'd64,
    parameter PIXEL_HEIGHT = 'd32,
    parameter BYTES_PER_PIXEL = 'd2,
    // verilator lint_off UNUSEDPARAM
    parameter _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input reset,
    input clk_in, /* clk_root =  133MHZ */

    input uart_rx,
    output rx_running,

    output logic [2:0] rgb_enable,
    output logic [5:0] brightness_enable,

    output logic [7:0] ram_data_out,
    //      with 64x32 matrix at 2bytes per pixel, this is 12 bits [11:0]
    output logic [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] ram_address,
    output logic ram_write_enable,
    output ram_clk_enable,
    output ram_reset
    `ifdef DEBUGGER
        ,
        output [1:0] cmd_line_state2,
        output [7:0] rx_data,
        output ram_access_start2,
        output ram_access_start_latch2,
        output [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] cmd_line_addr2,
        output logic [7:0] num_commands_processed
    `endif
);

    wire [7:0] uart_rx_data;
    wire uart_rx_running;
    wire ram_clk_enable_real;
    logic ram_access_start;
    logic ram_access_start_latch;
    `ifdef DEBUGGER
        assign ram_access_start2 = ram_access_start;
        assign ram_access_start_latch2 = ram_access_start_latch;
    `endif
    assign ram_reset = reset;
    wire [1:0] timer_counter_unused;
    logic  [1:0]  cmd_line_state;
    // For 32 bit high displays, [4:0]
    logic  [$clog2(PIXEL_HEIGHT)-1:0]  cmd_line_addr_row;
    // For 64 bit wide displays @ 2 bytes per pixel == 128, -> 127 -> [6:0]
    logic  [$clog2(PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0]  cmd_line_addr_col;
    wire [$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL)-1:0] cmd_line_addr =
        {  cmd_line_addr_row[$clog2(PIXEL_HEIGHT)-1:0],
          ~cmd_line_addr_col[$clog2(PIXEL_WIDTH * BYTES_PER_PIXEL)-1:1],
           ~cmd_line_addr_col[0] }; // <-- use this bit to toggle endainness. ~ == little endain
                                    //                                          == bit endian
                                    // NOTE: uart/alphabet.uart is BIG ENDIAN.

    `ifdef DEBUGGER
        assign cmd_line_state2[1:0] = cmd_line_state[1:0];
        assign cmd_line_addr2 = cmd_line_addr;
    `endif

    wire uart_rx_dataready;
    uart_rx #(
        // we want 22MHz / 2,430,000 = 9.0534
        // 22MHz / 9 = 2,444,444 baud 2444444
        .TICKS_PER_BIT(UART_CLK_TICKS_PER_BIT)
    ) mycontrol_rxuart (
    .reset(reset),
    .i_clk(clk_in),
    .i_enable(1'b1),
    .i_din_priortobuffer(uart_rx),
    .o_rxdata(uart_rx_data),
    .o_recvdata(uart_rx_dataready),
    .o_busy(uart_rx_running)
    );

    // ^ is exclusive or
    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_cmd_line_write (
        .reset(reset),
        .clk_in(~clk_in),
        .start(ram_access_start ^ ram_access_start_latch),
        .value(2'b10),
        .counter(timer_counter_unused),
        .running(ram_clk_enable_real)
    );
    assign ram_clk_enable = ram_clk_enable_real;
    assign rx_running = uart_rx_running;
    `ifdef DEBUGGER
        assign rx_data[7:0] = uart_rx_data[7:0];
    `endif

    always @(posedge clk_in) begin
        if (reset) begin
            ram_access_start_latch <= 1'b0;
        end
        else begin
            if (ram_clk_enable_real) begin
                ram_access_start_latch <= ram_access_start;
            end
            else begin
            end
        end
    end

    logic uart_rx_sync1, uart_rx_running_sync;
    // Double flip-flop synchronizer
    always_ff @(posedge clk_in or posedge reset) begin
        if (reset) begin
            uart_rx_sync1 <= 1'b1;  // UART idle is logic high
            uart_rx_running_sync <= 1'b1;
        end else begin
            uart_rx_sync1 <= uart_rx_running;
            uart_rx_running_sync <= uart_rx_sync1;
        end
    end

    always @(negedge uart_rx_running_sync, posedge reset) begin
        if (reset) begin
            rgb_enable <= 3'b111;
            brightness_enable <= 6'b111111;

            ram_data_out <= 8'd0;
            ram_address <= {$clog2(PIXEL_HEIGHT * PIXEL_WIDTH * BYTES_PER_PIXEL){1'b0}};
            ram_write_enable <= 1'b0;
            ram_access_start <= 1'b0;

            cmd_line_state <= 2'd0;
            cmd_line_addr_row <= {$clog2(PIXEL_HEIGHT){1'b0}};
            cmd_line_addr_col <= {$clog2(PIXEL_WIDTH * BYTES_PER_PIXEL){1'b0}};
            `ifdef DEBUGGER
                num_commands_processed <= 8'b0;
            `endif
        end


        /* CMD: Line */
        else if (cmd_line_state == 2'd2 && uart_rx_data != "L" ) begin
            /* first, get the row to write to */
            cmd_line_addr_row[$clog2(PIXEL_HEIGHT)-1:0] <= uart_rx_data[4:0];

            /* and start clocking in the column data
               64 pixels x 2 bytes each = 128 bytes */
            // parameter PIXEL_WIDTH = 'd64,
            // parameter BYTES_PER_PIXEL = 'd2
            // cmd_line_addr_col[6:0] <= 7'd127;
            cmd_line_addr_col[$clog2((PIXEL_WIDTH * BYTES_PER_PIXEL) - 1)-1:0] <= (PIXEL_WIDTH * BYTES_PER_PIXEL) - 1;
            cmd_line_state <= 2'd1;
        end
        else if (cmd_line_state == 2'd1) begin
            /* decrement the column address (or finish the load) */
            if (cmd_line_addr_col != 'd0) begin
                cmd_line_addr_col <= cmd_line_addr_col - 'd1;
            end
            else begin
                cmd_line_state <= 2'd0;
                `ifdef DEBUGGER
                    num_commands_processed <= num_commands_processed + 1'b1;
                `endif
            end

            /* store this byte */
            ram_data_out <= uart_rx_data[7:0];
            ram_address <= cmd_line_addr;
            ram_write_enable <= 1'b1;
            ram_access_start <= !ram_access_start;
        end

        /* CMD: Main */
        else if (cmd_line_state != 2'd2 && !uart_rx_running_sync) begin
            //2650000
            case (uart_rx_data)
                "R": begin
                    rgb_enable[0] <= 1'b1;
                end
                "r": begin
                    rgb_enable[0] <= 1'b0;
                end
                "G": begin
                    rgb_enable[1] <= 1'b1;
                end
                "g": begin
                    rgb_enable[1] <= 1'b0;
                end
                "B": begin
                    rgb_enable[2] <= 1'b1;
                end
                "b": begin
                    rgb_enable[2] <= 1'b0;
                end
                "1": begin
                    brightness_enable[5] <= ~brightness_enable[5];
                end
                "2": begin
                    brightness_enable[4] <= ~brightness_enable[4];
                end
                "3": begin
                    brightness_enable[3] <= ~brightness_enable[3];
                end
                "4":begin
                    brightness_enable[2] <= ~brightness_enable[2];
                end
                "5": begin
                    brightness_enable[1] <= ~brightness_enable[1];
                end
                "6": begin
                    brightness_enable[0] <= ~brightness_enable[0];
                end
                "0": begin
                    brightness_enable <= 6'b000000;
                end
                "9": begin
                    brightness_enable <= 6'b111111;
                end
                "L": begin
                    cmd_line_state <= 2'd2;
                end
                default: begin
                    cmd_line_state <= 2'd0;
                    ram_write_enable <= 1'b0;
                end
            endcase
        end
    end
    wire _unused_ok = &{1'b0,
                        uart_rx_dataready,
                        timer_counter_unused,
                        1'b0};
endmodule
