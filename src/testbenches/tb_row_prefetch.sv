// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// tb_row_prefetch:
// - Drives row_prefetch's backing-store fill port with a behavioral memory model
//   (2-cycle latency, matching mem_lane's real AddressB -> QB pipeline).
// - Pulses row_latch/brightness_mask the way matrix_scan would at the end of a
//   row's bitplane sequence, and checks the display-side read port returns the
//   correct row's data after each ping-pong swap.
// - Confirms the read port ignores the .row field of its address (only .col matters).
module tb_row_prefetch;
    localparam time CLK_PERIOD = 10ns;
    localparam int unsigned RESET_CYCLES = 4;
    localparam int unsigned FILL_MARGIN_CYCLES = 8;
    localparam int unsigned FILL_WAIT_CYCLES = params::PIXEL_WIDTH + FILL_MARGIN_CYCLES;

    logic clk_in;
    logic reset;

    types::mem_read_addr_t read_address;
    logic                  read_clk_enable;
    types::mem_read_data_t read_data_out;

    types::row_subpanel_addr_t row_address;
    types::brightness_level_t  brightness_mask;
    logic                       row_latch;

    types::mem_read_addr_t fill_address;
    logic                  fill_clk_enable;
    types::mem_read_data_t fill_data_in;

    row_prefetch #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk_in),
        .read_address(read_address),
        .read_clk_enable(read_clk_enable),
        .read_data_out(read_data_out),
        .row_address(row_address),
        .brightness_mask(brightness_mask),
        .row_latch(row_latch),
        .fill_address(fill_address),
        .fill_clk_enable(fill_clk_enable),
        .fill_data_in(fill_data_in)
    );

    always #(CLK_PERIOD / 2) clk_in = ~clk_in;

    // ----- Behavioral backing-store model: 2-cycle read latency, like mem_lane. -----
    types::mem_read_data_t model_mem[params::PIXEL_HALFHEIGHT][params::PIXEL_WIDTH];
    types::mem_read_data_t mock_pipe0, mock_pipe1;

    always @(posedge clk_in) begin
        mock_pipe0 <= model_mem[fill_address.row][fill_address.col];
        mock_pipe1 <= mock_pipe0;
    end
    assign fill_data_in = mock_pipe1;

    function automatic types::mem_read_data_t make_pattern(input int unsigned row, input types::col_addr_t col);
        types::mem_read_data_t v;
        v = '0;
        // +1 so row0/col0 isn't all-zero; explicit width matches v.raw exactly so the
        // assignment never truncates/expands regardless of the build's pixel format.
        v.raw = ($bits(v.raw))'(longint'(row) * 1000 + longint'(col) + 1);
        make_pattern = v;
    endfunction

    // ----- Helpers -----
    task automatic pulse_trigger(input types::row_subpanel_addr_t current_row);
        @(negedge clk_in);
        row_address = current_row;
        brightness_mask = types::brightness_level_t'(1);
        row_latch = 1'b1;
        @(posedge clk_in);
        @(negedge clk_in);
        row_latch = 1'b0;
    endtask

    task automatic check_read(input types::col_addr_t col, input types::row_subpanel_addr_t junk_row,
                              input types::mem_read_data_t expected);
        @(negedge clk_in);
        read_address = {junk_row, col};
        read_clk_enable = 1'b1;
        @(posedge clk_in);
        #1;
        if (read_data_out !== expected) begin
            $fatal(1, "read mismatch col=%0d expected=%0h got=%0h", col, expected, read_data_out);
        end
        @(negedge clk_in);
        read_clk_enable = 1'b0;
    endtask

    localparam types::col_addr_t LAST_COL = types::col_addr_t'(params::PIXEL_WIDTH - 1);
    localparam types::col_addr_t MID_COL = types::col_addr_t'(params::PIXEL_WIDTH / 2);
    localparam types::row_subpanel_addr_t JUNK_ROW = '1;

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_row_prefetch);

        clk_in = 1'b0;
        reset = 1'b1;
        read_address = '0;
        read_clk_enable = 1'b0;
        row_address = '0;
        brightness_mask = '0;
        row_latch = 1'b0;

        for (int r = 0; r < params::PIXEL_HALFHEIGHT; r++) begin
            for (int c = 0; c < params::PIXEL_WIDTH; c++) begin
                model_mem[r][c] = make_pattern(r, types::col_addr_t'(c));
            end
        end

        repeat (RESET_CYCLES) @(posedge clk_in);
        reset = 1'b0;

        // Bank0 (initially active) should read back its default-zero contents:
        // no fill has targeted it yet, matching multimem's blank-at-boot state.
        check_read(0, JUNK_ROW, '0);
        check_read(LAST_COL, JUNK_ROW, '0);

        // Reset primes a fill of row 1 into bank1; give it time to land.
        repeat (FILL_WAIT_CYCLES) @(posedge clk_in);

        // Transition row0 -> row1: bank1 (row1 data) becomes active.
        // Also kicks off the fill of row2 into bank0.
        pulse_trigger(types::row_subpanel_addr_t'(0));
        check_read(0, JUNK_ROW, make_pattern(1, 0));
        check_read(MID_COL, '0, make_pattern(1, MID_COL));
        check_read(LAST_COL, JUNK_ROW, make_pattern(1, LAST_COL));

        repeat (FILL_WAIT_CYCLES) @(posedge clk_in);

        // Transition row1 -> row2: bank0 (row2 data) becomes active.
        // Also kicks off the fill of row3 into bank1.
        pulse_trigger(types::row_subpanel_addr_t'(1));
        check_read(0, JUNK_ROW, make_pattern(2, 0));
        check_read(MID_COL, JUNK_ROW, make_pattern(2, MID_COL));
        check_read(LAST_COL, '1, make_pattern(2, LAST_COL));

        repeat (FILL_WAIT_CYCLES) @(posedge clk_in);

        // Transition row2 -> row3: bank1 (row3 data) becomes active.
        pulse_trigger(types::row_subpanel_addr_t'(2));
        check_read(0, JUNK_ROW, make_pattern(3, 0));
        check_read(LAST_COL, JUNK_ROW, make_pattern(3, LAST_COL));

        $display("tb_row_prefetch: PASS");
        $finish;
    end

    wire _unused_ok = &{1'b0, fill_clk_enable, 1'b0};
endmodule
