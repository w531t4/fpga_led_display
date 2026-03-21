// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// tb_framebuffer_fabric:
// - Exercises the framebuffer_fabric wrapper in DOUBLE_BUFFER builds.
// - Verifies front/back selection by writing distinct values into each frame
//   via the controller path and checking which value appears on ram_b_data_out.
module tb_framebuffer_fabric;
    // ----- Test configuration -----
    localparam time CLK_PERIOD = 10ns;
    localparam int unsigned RESET_CYCLES = 4;
    localparam int unsigned WRITE_SETTLE_CYCLES = 4;
    localparam int unsigned READ_LATENCY_CYCLES = 4;
    localparam int unsigned LANE0_IDX = 0;

    // Use explicit data patterns so mismatches are easy to spot.
    localparam types::mem_write_data_t DATA_A = types::mem_write_data_t'(8'hA5);
    localparam types::mem_write_data_t DATA_B = types::mem_write_data_t'(8'h3C);

    // Address zero selects lane 0 (subpanel=0, pixel=0) at row/col 0.
    localparam types::mem_write_addr_t WRITE_ADDR = types::mem_write_addr_t'('0);
    localparam types::mem_read_addr_t READ_ADDR = types::mem_read_addr_t'('0);

    // ----- DUT wiring -----
    logic                   clk_root;
    logic                   reset;

    types::mem_write_addr_t ctrl_ram_address;
    types::mem_write_data_t ctrl_ram_data_out;
    logic                   ctrl_ram_write_enable;
    logic                   ctrl_ram_clk_enable;

    types::mem_read_addr_t  ram_b_address;
    logic                   ram_b_clk_enable;
    types::mem_read_data_t  ram_b_data_out;

`ifdef DOUBLE_BUFFER
    logic frame_select;
    mem_copy_if copy_if ();
`endif

    framebuffer_fabric dut (
        .clk_a(clk_root),
        .clk_b(clk_root),
        .reset(reset),
        .ctrl_ram_address(ctrl_ram_address),
        .ctrl_ram_data_out(ctrl_ram_data_out),
        .ctrl_ram_write_enable(ctrl_ram_write_enable),
        .ctrl_ram_clk_enable(ctrl_ram_clk_enable),
        .ram_b_address(ram_b_address),
        .ram_b_clk_enable(ram_b_clk_enable),
        .ram_b_data_out(ram_b_data_out)
`ifdef DOUBLE_BUFFER,
        .frame_select(frame_select),
        .copy_if(copy_if)
`endif
    );

    // ----- Clock generation -----
    always #(CLK_PERIOD / 2) clk_root = ~clk_root;

`ifdef DOUBLE_BUFFER
    // Drive the copy engine outputs (fabric inputs) explicitly.
    // We keep the copy engine inactive for this test.
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

    // ----- Helpers -----
    task automatic ctrl_write(input types::mem_write_data_t data);
        // One-cycle write pulse on the controller path.
        ctrl_ram_data_out = data;
        ctrl_ram_write_enable = 1'b1;
        @(posedge clk_root);
        ctrl_ram_write_enable = 1'b0;
    endtask

    // ----- Test sequence -----
    initial begin
        // Default/reset state.
        clk_root = 1'b0;
        reset = 1'b1;
        ctrl_ram_address = WRITE_ADDR;
        ctrl_ram_data_out = '0;
        ctrl_ram_write_enable = 1'b0;
        ctrl_ram_clk_enable = 1'b1;
        ram_b_address = READ_ADDR;
        ram_b_clk_enable = 1'b1;
`ifdef DOUBLE_BUFFER
        frame_select = 1'b0;
        copy_active = 1'b0;
        copy_read_addr = '0;
        copy_write_addr = '0;
        copy_write_data_out = '0;
        copy_write_enable = 1'b0;
        copy_access_start = 1'b0;
`endif

        // Hold reset for a few cycles to clear internal state.
        repeat (RESET_CYCLES) @(posedge clk_root);
        reset = 1'b0;
        repeat (RESET_CYCLES) @(posedge clk_root);

`ifdef DOUBLE_BUFFER
        // 1) With frame_select=0, back buffer is frame1.
        //    Write DATA_A via controller -> should land in frame1.
        frame_select = 1'b0;
        ctrl_write(DATA_A);
        repeat (WRITE_SETTLE_CYCLES) @(posedge clk_root);

        // 2) With frame_select=1, back buffer is frame0.
        //    Write DATA_B via controller -> should land in frame0.
        frame_select = 1'b1;
        ctrl_write(DATA_B);
        repeat (WRITE_SETTLE_CYCLES) @(posedge clk_root);

        // 3) Read front buffer with frame_select=0 (front=frame0).
        frame_select = 1'b0;
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (ram_b_data_out.lane[LANE0_IDX] !== DATA_B) begin
            $fatal(1, "frame_select=0 expected DATA_B=%02x, got %02x", DATA_B, ram_b_data_out.lane[LANE0_IDX]);
        end

        // 4) Read front buffer with frame_select=1 (front=frame1).
        frame_select = 1'b1;
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (ram_b_data_out.lane[LANE0_IDX] !== DATA_A) begin
            $fatal(1, "frame_select=1 expected DATA_A=%02x, got %02x", DATA_A, ram_b_data_out.lane[LANE0_IDX]);
        end
`else
        // Single-buffer build: no front/back swapping to verify.
        ctrl_write(DATA_A);
        repeat (READ_LATENCY_CYCLES) @(posedge clk_root);
        if (ram_b_data_out.lane[LANE0_IDX] !== DATA_A) begin
            $fatal(1, "single-buffer expected DATA_A=%02x, got %02x", DATA_A, ram_b_data_out.lane[LANE0_IDX]);
        end
`endif

        $display("tb_framebuffer_fabric: PASS");
        $finish;
    end
endmodule
