// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// verilog_format: off
`timescale 1ns / 1ns
`default_nettype none
// verilog_format: on
`include "tb_helper.svh"

module tb_fb_store_sdram;
    logic clk;
    logic reset;
    fb_store_if store_if ();
    wire sdram_clk;
    wire sdram_cke;
    wire sdram_csn;
    wire sdram_rasn;
    wire sdram_casn;
    wire sdram_wen;
    wire [params::SDRAM_ADDR_BITS-1:0] sdram_a;
    wire [params::SDRAM_BANK_BITS-1:0] sdram_ba;
    wire [params::SDRAM_DQM_BITS-1:0] sdram_dqm;
    wire [params::SDRAM_DATA_BITS-1:0] sdram_dq_out;
    wire sdram_dq_oe;
    wire [params::SDRAM_DATA_BITS-1:0] sdram_dq_in;

    fb_store_sdram dut (
        .clk_root(clk),
        .reset(reset),
        .store_if(store_if),
        .sdram_clk(sdram_clk),
        .sdram_cke(sdram_cke),
        .sdram_csn(sdram_csn),
        .sdram_rasn(sdram_rasn),
        .sdram_casn(sdram_casn),
        .sdram_wen(sdram_wen),
        .sdram_a(sdram_a),
        .sdram_ba(sdram_ba),
        .sdram_dqm(sdram_dqm),
        .sdram_dq_out(sdram_dq_out),
        .sdram_dq_oe(sdram_dq_oe),
        .sdram_dq_in(sdram_dq_in)
    );

    sdram_model_simple model (
        .clk(sdram_clk),
        .cke(sdram_cke),
        .csn(sdram_csn),
        .rasn(sdram_rasn),
        .casn(sdram_casn),
        .wen(sdram_wen),
        .addr(sdram_a),
        .bank(sdram_ba),
        .dq_in(sdram_dq_out),
        .dq_oe(sdram_dq_oe),
        .dq_out(sdram_dq_in)
    );

    task automatic write_byte(input types::row_addr_t row, input types::col_addr_t col,
                              input types::pixel_addr_t pixel, input logic [7:0] value);
        begin
            `WAIT_ASSERT(clk, store_if.cmd_write_ready === 1'b1, 512)
            @(negedge clk);
            store_if.cmd_write_addr.row = row;
            store_if.cmd_write_addr.col = col;
            store_if.cmd_write_addr.pixel = pixel;
            store_if.cmd_write_data = value;
            store_if.cmd_write_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            store_if.cmd_write_valid = 1'b0;
        end
    endtask

    task automatic request_prefetch(input types::row_subpanel_addr_t row_in_subpanel);
        begin
            `WAIT_ASSERT(clk, store_if.prefetch_req_ready === 1'b1, 512)
            @(negedge clk);
            store_if.prefetch_row = row_in_subpanel;
            store_if.prefetch_req_valid = 1'b1;
            @(posedge clk);
            @(negedge clk);
            store_if.prefetch_req_valid = 1'b0;
        end
    endtask

    task automatic expect_column(input types::col_addr_t expected_col,
                                 input types::color_field_t top_expected,
                                 input types::color_field_t bottom_expected,
                                 input string label);
        begin
            while (!(store_if.prefetch_data_valid && store_if.prefetch_data_ready
                     && store_if.prefetch_col == expected_col)) begin
                @(posedge clk);
            end
            assert (store_if.prefetch_pixels[0].raw == top_expected.raw)
            else
                $fatal(1, "%s top expected=0x%0h got=0x%0h", label, top_expected.raw, store_if.prefetch_pixels[0].raw);
            assert (store_if.prefetch_pixels[1].raw == bottom_expected.raw)
            else
                $fatal(1,
                       "%s bottom expected=0x%0h got=0x%0h",
                       label,
                       bottom_expected.raw,
                       store_if.prefetch_pixels[1].raw);
        end
    endtask

    task automatic copy_frame;
        begin
            `WAIT_ASSERT(clk, store_if.backend_ready === 1'b1, 512)
            `WAIT_ASSERT(clk, store_if.prefetch_req_ready === 1'b1, 512)
            @(negedge clk);
            store_if.copy_start = 1'b1;
            @(posedge clk);
            @(negedge clk);
            store_if.copy_start = 1'b0;
            `WAIT_ASSERT(clk, store_if.copy_done === 1'b1, 4096)
        end
    endtask

    always begin
        #(params::SIM_HALF_PERIOD_NS) clk <= ~clk;
    end

    initial begin
`ifdef DUMP_FILE_NAME
        $dumpfile(`DUMP_FILE_NAME);
`endif
        $dumpvars(0, tb_fb_store_sdram);
        clk = 1'b0;
        reset = 1'b1;
        store_if.cmd_write_valid = 1'b0;
        store_if.cmd_write_addr = '0;
        store_if.cmd_write_data = '0;
        store_if.prefetch_req_valid = 1'b0;
        store_if.prefetch_row = '0;
        store_if.prefetch_data_ready = 1'b1;
        store_if.copy_start = 1'b0;
        store_if.frame_select = 1'b0;
        repeat (4) @(posedge clk);
        reset = 1'b0;

        `WAIT_ASSERT(clk, store_if.backend_ready === 1'b1, 512)

        // Write one top-row pixel and one bottom-row pixel into the back frame.
        // With frame_select=0, back=frame1 and front=frame0.
        write_byte(types::row_addr_t'(0), types::col_addr_t'(1), types::pixel_addr_t'(0), 8'h11);
        write_byte(types::row_addr_t'(0), types::col_addr_t'(1), types::pixel_addr_t'(1), 8'h22);
        write_byte(types::row_addr_t'(0), types::col_addr_t'(1), types::pixel_addr_t'(2), 8'h33);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(1), types::pixel_addr_t'(0), 8'h44);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(1), types::pixel_addr_t'(1), 8'h55);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(1), types::pixel_addr_t'(2), 8'h66);

        // Scan reads the current front frame only, so the new back-frame data
        // must stay invisible until a frame-role swap makes it front-visible.
        request_prefetch(types::row_subpanel_addr_t'(0));
        expect_column(types::col_addr_t'(1),
                      types::color_field_t'('0),
                      types::color_field_t'('0),
                      "front frame should ignore back-frame writes");

        // Toggle so frame1 becomes the front frame, then prefetch logical row pair 0.
        store_if.frame_select = 1'b1;
        request_prefetch(types::row_subpanel_addr_t'(0));
        expect_column(types::col_addr_t'(1),
                      types::color_field_t'({8'h00, 8'h33, 8'h22, 8'h11}),
                      types::color_field_t'({8'h00, 8'h66, 8'h55, 8'h44}),
                      "prefetch after toggle");

        // With frame_select=1, writes must go to back=frame0 and must not leak
        // into the current front=frame1 scan stream until the next toggle.
        write_byte(types::row_addr_t'(0), types::col_addr_t'(2), types::pixel_addr_t'(0), 8'h77);
        write_byte(types::row_addr_t'(0), types::col_addr_t'(2), types::pixel_addr_t'(1), 8'h88);
        write_byte(types::row_addr_t'(0), types::col_addr_t'(2), types::pixel_addr_t'(2), 8'h99);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(2), types::pixel_addr_t'(0), 8'haa);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(2), types::pixel_addr_t'(1), 8'hbb);
        write_byte(types::row_addr_t'(2), types::col_addr_t'(2), types::pixel_addr_t'(2), 8'hcc);
        request_prefetch(types::row_subpanel_addr_t'(0));
        expect_column(types::col_addr_t'(2),
                      types::color_field_t'('0),
                      types::color_field_t'('0),
                      "new back-frame writes must stay hidden before toggle");

        store_if.frame_select = 1'b0;
        request_prefetch(types::row_subpanel_addr_t'(0));
        expect_column(types::col_addr_t'(2),
                      types::color_field_t'({8'h00, 8'h99, 8'h88, 8'h77}),
                      types::color_field_t'({8'h00, 8'hcc, 8'hbb, 8'haa}),
                      "toggled frame should expose former back-frame writes");

        // Restore frame1 as the front frame so copyframe still exercises the
        // original front->back direction (frame1 -> frame0).
        store_if.frame_select = 1'b1;
        copy_frame();
        store_if.frame_select = 1'b0;
        request_prefetch(types::row_subpanel_addr_t'(0));
        expect_column(types::col_addr_t'(1),
                      types::color_field_t'({8'h00, 8'h33, 8'h22, 8'h11}),
                      types::color_field_t'({8'h00, 8'h66, 8'h55, 8'h44}),
                      "prefetch after copyframe");

        $display("tb_fb_store_sdram: PASS");
        $finish;
    end

    wire _unused_ok = &{1'b0,
                        sdram_dqm,
                        store_if.backend_error,
                        store_if.prefetch_data_first,
                        store_if.prefetch_data_last,
                        store_if.copy_busy,
                        1'b0};
endmodule
