// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_framebuffer_fetch;
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned FIELD_BYTES = calc::num_bytes_to_contain($bits(types::color_t));
    localparam int unsigned FETCH_WAIT_CYCLES = params::FB_FETCH_TIMEOUT_TICKS + 3;

    logic                            clk;
    logic                            reset;
    logic                            pixel_load_start;
    types::col_addr_t                column_address;
    types::row_subpanel_addr_t       row_address;
    types::mem_read_data_t           ram_data_in;
    wire types::mem_read_addr_t      ram_address;
    wire                             ram_clk_enable;
    wire types::color_field_t        pixeldata_subpanels[NUM_SUBPANELS];

    types::color_field_t             expected_fields[NUM_SUBPANELS];
    types::color_field_t             next_fields[NUM_SUBPANELS];

    framebuffer_fetch #(
        ._UNUSED('d0)
    ) dut (
        .reset(reset),
        .clk_in(clk),
        .column_address(column_address),
        .row_address(row_address),
        .pixel_load_start(pixel_load_start),
        .ram_data_in(ram_data_in),
        .ram_address(ram_address),
        .ram_clk_enable(ram_clk_enable),
        .pixeldata_subpanels(pixeldata_subpanels)
    );

    function automatic types::color_field_t make_field(input logic [7:0] base);
        types::color_field_t field;
        field = '0;
        for (int byte_idx = 0; byte_idx < FIELD_BYTES; byte_idx++) begin
            field.bytes[byte_idx] = byte'(int'(base) + byte_idx);
        end
        return field;
    endfunction

    task automatic load_ram_patterns(output types::color_field_t fields[NUM_SUBPANELS], input logic [7:0] base);
        begin
            ram_data_in = '0;
            for (int subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx++) begin
                fields[subpanel_idx] = make_field(byte'(int'(base) + (subpanel_idx * 8)));
                ram_data_in.subpanel[subpanel_idx].field = fields[subpanel_idx];
            end
        end
    endtask

    task automatic assert_sample_matches(input types::color_field_t fields[NUM_SUBPANELS], input string label);
        begin
            for (int subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx++) begin
                assert (pixeldata_subpanels[subpanel_idx].raw == fields[subpanel_idx].raw)
                else
                    $fatal(
                        1,
                        "%s subpanel=%0d expected=0x%0h got=0x%0h",
                        label,
                        subpanel_idx,
                        fields[subpanel_idx].raw,
                        pixeldata_subpanels[subpanel_idx].raw
                    );
            end
        end
    endtask

    task automatic start_fetch(input types::row_subpanel_addr_t row_value, input types::col_addr_t col_value);
        begin
            row_address = row_value;
            column_address = col_value;
            @(negedge clk);
            pixel_load_start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            pixel_load_start = 1'b0;
        end
    endtask

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= !clk;
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_framebuffer_fetch);
        clk = 1'b0;
        reset = 1'b1;
        pixel_load_start = 1'b0;
        column_address = '0;
        row_address = '0;
        ram_data_in = '0;
        for (int subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx++) begin
            expected_fields[subpanel_idx] = '0;
            next_fields[subpanel_idx] = '0;
        end

        repeat (2) @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        // Reset should clear the sampled outputs.
        assert_sample_matches(expected_fields, "reset");

        // First fetch: verify mirrored addressing, read enable, and sampled subpanel ordering.
        load_ram_patterns(expected_fields, 8'h10);
        start_fetch(types::row_subpanel_addr_t'(3), types::col_addr_t'(5));
        `WAIT_ASSERT(clk, ram_clk_enable === 1'b1, 2)
        assert (ram_address.row == types::row_subpanel_addr_t'(3))
        else $fatal(1, "row_address mismatch expected=%0d got=%0d", 3, ram_address.row);
        assert (ram_address.col
                == types::col_addr_t'(types::col_addr_t'(params::PIXEL_WIDTH - 1) - types::col_addr_t'(5)))
        else
            $fatal(
                1,
                "mirrored column mismatch expected=%0d got=%0d",
                types::col_addr_t'(params::PIXEL_WIDTH - 1) - types::col_addr_t'(5),
                ram_address.col
            );
        `WAIT_ASSERT(clk, pixeldata_subpanels[NUM_SUBPANELS-1].raw == expected_fields[NUM_SUBPANELS-1].raw,
                     FETCH_WAIT_CYCLES)
        assert_sample_matches(expected_fields, "first fetch");
        `WAIT_ASSERT(clk, ram_clk_enable === 1'b0, FETCH_WAIT_CYCLES)

        // Second fetch: verify outputs update cleanly on a later request.
        load_ram_patterns(next_fields, 8'h40);
        start_fetch(types::row_subpanel_addr_t'(1), types::col_addr_t'(params::PIXEL_WIDTH - 2));
        `WAIT_ASSERT(clk, ram_clk_enable === 1'b1, 2)
        assert (ram_address.row == types::row_subpanel_addr_t'(1))
        else $fatal(1, "second row_address mismatch expected=%0d got=%0d", 1, ram_address.row);
        assert (ram_address.col == types::col_addr_t'(1))
        else $fatal(1, "second mirrored column mismatch expected=%0d got=%0d", 1, ram_address.col);
        `WAIT_ASSERT(clk, pixeldata_subpanels[NUM_SUBPANELS-1].raw == next_fields[NUM_SUBPANELS-1].raw,
                     FETCH_WAIT_CYCLES)
        assert_sample_matches(next_fields, "second fetch");

        repeat (3) @(posedge clk);
        $finish;
    end

    // verilog_format: off
    wire _unused_ok = &{1'b0,
                        1'b0};
    // verilog_format: on
endmodule
