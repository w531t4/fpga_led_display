// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none

// tb_sdram_write_client:
// - Confirms ready/sdram_req follow a single in-flight write correctly.
// - Confirms sdram_addr/sdram_wdata_we/sdram_wdata match calc::sdram_word_addr and
//   the pixel-byte decomposition for every byte index in a pixel, and that writes
//   target the buffer opposite frame_select (back buffer).
module tb_sdram_write_client;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned PIXEL_BYTES = calc::num_pixeldata_bits(params::BYTES_PER_PIXEL) / 8;
    localparam int unsigned MAX_WAIT_CYCLES = 32;

    logic clk_in;
    logic reset;
    logic frame_select;
    types::mem_write_addr_t source_addr;
    types::mem_write_data_t source_data;
    logic source_write_valid;
    wire ready;
    wire sdram_req;
    logic sdram_done;
    wire types::sdram_word_addr_t sdram_addr;
    wire types::sdram_byte_en_t sdram_wdata_we;
    wire types::sdram_word_data_t sdram_wdata;

    sdram_write_client #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk_in),
        .frame_select(frame_select),
        .source_addr(source_addr),
        .source_data(source_data),
        .source_write_valid(source_write_valid),
        .ready(ready),
        .sdram_req(sdram_req),
        .sdram_done(sdram_done),
        .sdram_addr(sdram_addr),
        .sdram_wdata_we(sdram_wdata_we),
        .sdram_wdata(sdram_wdata)
    );

    always #(params::SIM_HALF_PERIOD_NS) clk_in = ~clk_in;

    function automatic types::sdram_word_addr_t expected_addr(input logic write_frame,
                                                               input types::mem_write_addr_t addr);
        logic word_select;
        word_select = calc::sdram_pixel_word_select(int'(addr.pixel), params::SDRAM_WORD_BYTES);
        expected_addr = calc::sdram_word_addr(write_frame, int'(addr.row), int'(addr.col), addr.subpanel, word_select,
                                               params::PIXEL_WIDTH, params::PIXEL_HALFHEIGHT, NUM_SUBPANELS,
                                               PIXEL_BYTES, params::SDRAM_WORD_BYTES);
    endfunction

    task automatic do_write(input types::mem_write_addr_t addr, input types::mem_write_data_t data);
        int unsigned byte_in_word;
        types::sdram_byte_en_t expected_we;
        types::sdram_word_data_t expected_data;
        int unsigned waited;

        if (!ready) $fatal(1, "client not ready before write");

        @(negedge clk_in);
        source_addr = addr;
        source_data = data;
        source_write_valid = 1'b1;
        @(posedge clk_in);
        @(negedge clk_in);
        source_write_valid = 1'b0;

        if (!sdram_req) $fatal(1, "sdram_req not asserted after write_valid");
        if (sdram_addr !== expected_addr(~frame_select, addr))
            $fatal(1, "addr mismatch: expected=%0h got=%0h", expected_addr(~frame_select, addr), sdram_addr);

        byte_in_word = calc::sdram_byte_in_word_select(int'(addr.pixel), params::SDRAM_WORD_BYTES);
        expected_we = types::sdram_byte_en_t'(1 << byte_in_word);
        expected_data = types::sdram_word_data_t'(int'(data) << (byte_in_word * 8));
        if (sdram_wdata_we !== expected_we || sdram_wdata !== expected_data)
            $fatal(1, "wdata mismatch: we expected=%0b got=%0b data expected=%0h got=%0h", expected_we,
                   sdram_wdata_we, expected_data, sdram_wdata);

        waited = 0;
        while (waited < MAX_WAIT_CYCLES) begin
            @(posedge clk_in);
            waited++;
        end
        sdram_done = 1'b1;
        @(posedge clk_in);
        sdram_done = 1'b0;
        @(negedge clk_in);
        if (!ready) $fatal(1, "client not ready after sdram_done");
        if (sdram_req) $fatal(1, "sdram_req still asserted after sdram_done");
    endtask

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_sdram_write_client);
        clk_in = 1'b0;
        reset = 1'b1;
        frame_select = 1'b0;
        source_addr = '0;
        source_data = '0;
        source_write_valid = 1'b0;
        sdram_done = 1'b0;
        repeat (4) @(posedge clk_in);
        reset = 1'b0;

        if (!ready) $fatal(1, "client not ready out of reset");

        for (int unsigned p = 0; p < PIXEL_BYTES; p++) begin
            types::mem_write_addr_t addr;
            addr = '{
                subpanel: types::subpanel_addr_t'(p[0]),
                row: types::row_subpanel_addr_t'(4'h3),
                col: types::col_addr_t'(10'h02a),
                pixel: types::pixel_addr_t'(p)
            };
            do_write(addr, types::mem_write_data_t'(8'h10) + types::mem_write_data_t'(p));
        end

        // Flip frame_select; writes should now target the other (opposite) frame.
        frame_select = 1'b1;
        do_write('{
            subpanel: types::subpanel_addr_t'(1'b0),
            row: types::row_subpanel_addr_t'(4'h1),
            col: types::col_addr_t'(10'h005),
            pixel: types::pixel_addr_t'(0)
        }, types::mem_write_data_t'(8'haa));

        $display("tb_sdram_write_client: PASS");
        $finish;
    end
endmodule
