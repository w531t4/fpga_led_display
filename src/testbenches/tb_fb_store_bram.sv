// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// tb_fb_store_bram:
// - Verifies the BRAM store wrapper preserves the current front/back behavior.
// - Exercises command writes through fb_store_if and reads through the legacy
//   scan path that remains in place until scan_prefetch/scan_row_cache exist.
module tb_fb_store_bram;
    localparam time CLK_PERIOD = 10ns;
    localparam int unsigned RESET_CYCLES = 4;
    localparam int unsigned WRITE_SETTLE_CYCLES = 4;
    localparam int unsigned READ_LATENCY_CYCLES = 4;
    localparam int unsigned LANE0_IDX = 0;

    localparam types::mem_write_data_t DATA_A = types::mem_write_data_t'(8'hA5);
    localparam types::mem_write_data_t DATA_B = types::mem_write_data_t'(8'h3C);

    localparam types::fb_addr_t WRITE_ADDR = types::fb_addr_t'('0);
    localparam types::mem_read_addr_t READ_ADDR = types::mem_read_addr_t'('0);

    logic                   clk_root;
    logic                   reset;
    fb_store_if             store_if ();
    types::mem_read_addr_t  scan_ram_address;
    logic                   scan_ram_clk_enable;
    types::mem_read_data_t  scan_ram_data;
`ifdef DOUBLE_BUFFER
    mem_copy_if copy_if ();
`endif

    fb_store_bram dut (
        .clk_root(clk_root),
        .reset(reset),
        .store_if(store_if),
        .scan_ram_address(scan_ram_address),
        .scan_ram_clk_enable(scan_ram_clk_enable),
        .scan_ram_data(scan_ram_data)
`ifdef DOUBLE_BUFFER,
        .copy_if(copy_if)
`endif
    );
    wire _unused_ok_store_status = &{1'b0,
                                     store_if.cmd_write_ready,
                                     store_if.prefetch_req_ready,
                                     store_if.prefetch_data_valid,
                                     store_if.prefetch_data_first,
                                     store_if.prefetch_data_last,
                                     store_if.prefetch_col,
                                     store_if.prefetch_pixels[0].raw,
                                     store_if.copy_busy,
                                     store_if.copy_done,
                                     1'b0};

    always #(CLK_PERIOD / 2) clk_root = ~clk_root;

`ifdef DOUBLE_BUFFER
    logic                   copy_active;
    types::fb_addr_t        copy_read_addr;
    types::fb_addr_t        copy_write_addr;
    types::mem_write_data_t copy_write_data_out;
    logic                   copy_write_enable;
    logic                   copy_access_start;

    always_comb begin
        copy_if.active = copy_active;
        copy_if.read_addr = copy_read_addr;
        copy_if.write_addr = copy_write_addr;
        copy_if.write_data_out = copy_write_data_out;
        copy_if.write_enable = copy_write_enable;
        copy_if.access_start = copy_access_start;
    end
`endif

    task automatic store_write(input types::mem_write_data_t data);
        store_if.cmd_write_data = data;
        store_if.cmd_write_valid = 1'b1;
        @(posedge clk_root);
        store_if.cmd_write_valid = 1'b0;
    endtask

    initial begin
        clk_root = 1'b0;
        reset = 1'b1;
        scan_ram_address = READ_ADDR;
        scan_ram_clk_enable = 1'b1;
        store_if.cmd_write_valid = 1'b0;
        store_if.cmd_write_addr = WRITE_ADDR;
        store_if.cmd_write_data = '0;
        store_if.prefetch_req_valid = 1'b0;
        store_if.prefetch_row = '0;
        store_if.prefetch_data_ready = 1'b0;
        store_if.copy_start = 1'b0;
        store_if.frame_select = 1'b0;
`ifdef DOUBLE_BUFFER
        copy_active = 1'b0;
        copy_read_addr = '0;
        copy_write_addr = '0;
        copy_write_data_out = '0;
        copy_write_enable = 1'b0;
        copy_access_start = 1'b0;
`endif

        repeat (RESET_CYCLES) @(posedge clk_root);
        reset = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk_root);

`ifdef DOUBLE_BUFFER
        // frame_select=0 => front=frame0, back=frame1
        store_if.frame_select = 1'b0;
        store_write(DATA_A);
        repeat (WRITE_SETTLE_CYCLES) @(posedge clk_root);

        // frame_select=1 => front=frame1, back=frame0
        store_if.frame_select = 1'b1;
        store_write(DATA_B);
        repeat (WRITE_SETTLE_CYCLES) @(posedge clk_root);

        store_if.frame_select = 1'b0;
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (scan_ram_data.lane[LANE0_IDX] !== DATA_B) begin
            $fatal(1, "frame_select=0 expected DATA_B=%02x, got %02x", DATA_B, scan_ram_data.lane[LANE0_IDX]);
        end

        store_if.frame_select = 1'b1;
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (scan_ram_data.lane[LANE0_IDX] !== DATA_A) begin
            $fatal(1, "frame_select=1 expected DATA_A=%02x, got %02x", DATA_A, scan_ram_data.lane[LANE0_IDX]);
        end
`else
        store_write(DATA_A);
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (scan_ram_data.lane[LANE0_IDX] !== DATA_A) begin
            $fatal(1, "single-buffer expected DATA_A=%02x, got %02x", DATA_A, scan_ram_data.lane[LANE0_IDX]);
        end
`endif

        assert (store_if.backend_ready === 1'b1)
            else $fatal(1, "backend_ready should be high for BRAM backend");
        assert (store_if.backend_error === 1'b0)
            else $fatal(1, "backend_error should remain low for BRAM backend");

        $display("tb_fb_store_bram: PASS");
        $finish;
    end
endmodule
