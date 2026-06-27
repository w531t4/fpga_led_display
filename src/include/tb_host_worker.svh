// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// =============================================================================
// tb_host_worker -- faithful behavioral model of the ESP32 host's SPI worker, so
// the F2.b host-queue-drop mechanism can be REPRODUCED in simulation (no real
// ESP32 needed). Replicates ESP32-FPGA-MatrixPanel matrix_panel_fpga:
//   - a TASK_Q_DEPTH (=34) deep job queue (xQueueCreate(34,...))
//   - drop-on-full enqueue (xQueueSend(...,0) -> dropped if full)
//   - a worker that drains one job at a time: SPI-send the column, then poll
//     fpga_busy with TICK-granularity sleeps (wait_for_fpga_busy_clear_'s
//     vTaskDelay(1) -- one FreeRTOS tick = 1..10ms; if busy is high at the poll,
//     the worker sleeps a WHOLE tick and the enqueue loop floods the queue).
//
// The host (this module) drives the SPI mosi/clk/cs directly via the same
// tb_spi_streamer the rest of tb_main uses -- but one COLUMN command at a time,
// gated by fpga_busy exactly like the firmware worker.
//
// Knobs (override per build):
//   HOST_TICK_CYCLES        : sim cycles per FreeRTOS tick (the vTaskDelay grain)
//   HOST_ENQUEUE_GAP_CYCLES : cycles between the host loop's xQueueSend calls
//   HOST_NUM_COLS           : columns the loop tries to draw (the magenta bar)
// Output: host_cols_sent / host_cols_dropped -- how many of the bar's columns
// actually reached the FPGA vs were dropped on the host queue.
// =============================================================================
`ifndef TB_HOST_WORKER_SVH
`define TB_HOST_WORKER_SVH

`ifndef HOST_TICK_CYCLES
`define HOST_TICK_CYCLES 5000        // 10ms-ish tick at the sim clock (sweepable)
`endif
`ifndef HOST_ENQUEUE_GAP_CYCLES
`define HOST_ENQUEUE_GAP_CYCLES 4    // host loop enqueues a column every few cycles
`endif
`ifndef HOST_NUM_COLS
`define HOST_NUM_COLS 48
`endif

module tb_host_worker #(
    parameter int unsigned TASK_Q_DEPTH = 34,
    parameter int unsigned NUM_COLS     = `HOST_NUM_COLS
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic fpga_busy,        // the FPGA's off-chip busy line (wifi_gpio35)
    output int unsigned cols_sent,
    output int unsigned cols_dropped,
    // a 1-cycle pulse + the column index when the worker wants a column streamed
    output logic        send_col_req,
    output int unsigned send_col_idx,
    input  logic        send_col_done   // streamer asserts when the column's bytes are out
);
    // ---- the 34-deep job queue (column indices the host wants drawn) ----
    int unsigned q[$];
    int unsigned enq_idx;            // next column the host loop will try to enqueue
    logic        enq_running;

    // ---- the host enqueue loop: push NUM_COLS columns, drop-on-full ----
    initial begin
        cols_dropped = 0; enq_idx = 0; enq_running = 1'b0;
        @(posedge start);
        enq_running = 1'b1;
        for (int unsigned c = 0; c < NUM_COLS; c++) begin
            repeat (`HOST_ENQUEUE_GAP_CYCLES) @(posedge clk);
            if (q.size() < TASK_Q_DEPTH) q.push_back(c);     // xQueueSend ok
            else                          cols_dropped++;     // xQueueSend(...,0) FAILED -> dropped
        end
        enq_running = 1'b0;
    end

    // ---- the worker task: drain one job, SPI-send it, then busy-poll ----
    initial begin
        cols_sent = 0; send_col_req = 1'b0; send_col_idx = 0;
        @(posedge start);
        forever begin
            // xQueueReceive(portMAX_DELAY): wait for a job
            while (q.size() == 0) begin
                @(posedge clk);
                if (!enq_running && q.size() == 0) break;  // loop finished + drained
            end
            if (!enq_running && q.size() == 0) break;
            send_col_idx = q.pop_front();
            // do_drawColumnRGB888_: stream the column's bytes over SPI
            @(negedge clk); send_col_req = 1'b1; @(negedge clk); send_col_req = 1'b0;
            @(posedge send_col_done);
            cols_sent++;
            // wait_for_fpga_busy_clear_(): poll busy; if high, sleep a FULL tick
            while (fpga_busy === 1'b1) repeat (`HOST_TICK_CYCLES) @(posedge clk);
        end
    end
endmodule
`endif
