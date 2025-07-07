`default_nettype none
module framebuffer_fetch (
    input reset,
    input clk_in,

    input [5:0] column_address,
    input [3:0] row_address,

    input pixel_load_start,

    input [15:0] ram_data_in,
    output [10:0] ram_address,
    output ram_clk_enable,
    output ram_reset,

    output reg [15:0] rgb565_top,
    output reg [15:0] rgb565_bottom,
    output [3:0] pixel_load_counter2
);
    wire ram_clk_enable_real;
    assign ram_clk_enable = ram_clk_enable_real;
    /* grab data on falling edge of pixel clock */
    //wire pixel_load_running;
    wire [1:0] pixel_load_counter;
    assign pixel_load_counter2[3:0] = { 1'b0, pixel_load_counter[1:0] };

    reg half_address;
    assign ram_address = { half_address, row_address[3:0], ~column_address[5:0] };

    assign ram_reset = reset;

    timeout #(
        .COUNTER_WIDTH(2)
    ) timeout_pixel_load (
        .reset(reset),
        .clk_in(clk_in),
        .start(pixel_load_start),
`ifdef USE_FM6126A
        .value(2'd2),
`else
        .value(2'd3),
`endif
        .counter(pixel_load_counter),
        .running(ram_clk_enable_real)
    );

    always @(negedge clk_in, posedge reset) begin
        if (reset) begin
            half_address <= 1'b0;

            rgb565_top    <= 16'd0;
            rgb565_bottom <= 16'd0;
        end
        else begin
`ifdef USE_FM6126A
            // the frequency of pixel_load_start must contain enough clk_root
            // cycles such that the top/bottom data can be loaded prior to next posedge
            // of pixel_load_start
            // for TinyFPGA BX - We can do this in 3 cycles (ram reads are one cycle long)
            // cycle 1 - change address to half 0
            // cycle 2 - read half 0, change half to 1
            // cycle 3 - read half 1
            if (pixel_load_counter == 'd2) begin
                half_address <= 1'b0;
            end
            else if (pixel_load_counter == 'd1) begin
                rgb565_top <= ram_data_in;
                half_address <= 1'b1;
            end
            else if (pixel_load_counter == 'd0) begin
                rgb565_bottom <= ram_data_in;
            end
`else
            if (pixel_load_counter == 'd3) begin
                half_address <= 1'b0;
            end
            else if (pixel_load_counter == 'd2) begin
                half_address <= 1'b1;
            end
            else if (pixel_load_counter == 'd1) begin
                rgb565_top <= ram_data_in;
            end
            else if (pixel_load_counter == 'd0) begin
                rgb565_bottom <= ram_data_in;
            end
`endif
        end
    end
endmodule
