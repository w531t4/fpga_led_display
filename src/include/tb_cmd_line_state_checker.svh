// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// Shared checker for the control_module command-state sequence.
// Keep this logic centralized so tb_main and tb_control_module stay in sync.
`ifndef TB_CMD_LINE_STATE_CHECKER_SVH
`define TB_CMD_LINE_STATE_CHECKER_SVH
`include "tb_helper.svh"

// Verifies the cmd_line_state sequence that corresponds to cmd_series (row4.svh).
module tb_cmd_line_state_checker #(
    // spi_master divide setting used by the TB driving the command stream.
    parameter logic [1:0] SPI_CDIV = 2'b0,
    // Readrect sizing from row4.svh (used to size wait windows).
    parameter int unsigned READRECT_W = 0,
    parameter int unsigned READRECT_TOTAL_BYTES = 0
) (
    input  logic                       clk,
    input  logic                       reset,
    input  enums::control_module_fsm_e cmd_line_state,
    output logic                       seq_done
);
    // Per-step timeout. Historically 500us at ROOT_CLOCK -- fine at 80MHz (40000
    // cyc) but the panel-fill commands (blankpanel/fillpanel) take a FREQUENCY-
    // INDEPENDENT ~PIXEL_WIDTH*PIXEL_HEIGHT*BYTES_PER_PIXEL cycles, which exceeds a
    // time-based 500us budget at lower clocks (only 25000 cyc at 50MHz). So floor
    // the budget at 1.5x a full-panel fill (cycle-based, frequency-robust).
    localparam integer CMD_LINE_STATE_STEP_NS = 500_000;
    localparam longint unsigned CMD_LINE_STATE_STEP_CYCLES_TIME =
        (64'd1 * params::ROOT_CLOCK * CMD_LINE_STATE_STEP_NS) / 1_000_000_000;
    localparam longint unsigned FILL_PANEL_CYCLES =
        longint'(params::PIXEL_WIDTH) * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // BRAM fills run at ~1 byte/cycle, so 1.5x the byte count is plenty. SDRAM writes
    // are FUNDAMENTALLY slower for a whole-panel fill: the single-inflight write client
    // drains one write per memory round-trip while sharing the bus with display fills,
    // measured ~5x slower than BRAM (tb_main fillpanel ~177k vs ~37k cycles). Scale the
    // per-fill budget under USE_SDRAM_FB so the timeout reflects real SDRAM write
    // throughput -- the fill is still REQUIRED to complete correctly (tb_main verifies
    // every command finishes and the write client fully drains); this only gives it the
    // realistic SDRAM time instead of the BRAM time. (8x covers the ~5x with margin; a
    // genuine hang still trips it.)
`ifdef USE_SDRAM_FB
    localparam longint unsigned FILL_PANEL_BUDGET = 8 * (FILL_PANEL_CYCLES + (FILL_PANEL_CYCLES / 2));
`else
    localparam longint unsigned FILL_PANEL_BUDGET = FILL_PANEL_CYCLES + (FILL_PANEL_CYCLES / 2);
`endif
    localparam longint unsigned CMD_LINE_STATE_STEP_CYCLES =
        (FILL_PANEL_BUDGET > CMD_LINE_STATE_STEP_CYCLES_TIME) ? FILL_PANEL_BUDGET : CMD_LINE_STATE_STEP_CYCLES_TIME;

    // Derive SPI byte cadence from the same divider as tb_main's spi_master.
    localparam int unsigned SPI_CLK_DIVIDE = 4 << SPI_CDIV;  // spi_master: 00=/4, 01=/8, 10=/16, 11=/32
    localparam int unsigned SPI_BITS_PER_BYTE = $bits(byte);
    localparam longint unsigned SPI_BYTE_CYCLES = longint'(SPI_CLK_DIVIDE) * SPI_BITS_PER_BYTE;

    // Readframe payload is large; compute a safe wait window for the idle transition after it.
    localparam longint unsigned READFRAME_TOTAL_BYTES =
        longint'(params::PIXEL_WIDTH) * params::PIXEL_HEIGHT * params::BYTES_PER_PIXEL;
    // Add a full row of bytes as margin for SPI idle/finish overheads.
    localparam longint unsigned READFRAME_WAIT_EXTRA_BYTES = longint'(params::PIXEL_WIDTH) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READFRAME_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        ((READFRAME_TOTAL_BYTES + READFRAME_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);

    // Readrect payload is smaller; still compute a safe wait window for pipelined follow-ups.
    localparam longint unsigned READRECT_WAIT_EXTRA_BYTES = longint'(READRECT_W) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READRECT_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        ((longint'(READRECT_TOTAL_BYTES) + READRECT_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);

    // Command sequence length depends on watchdog being enabled.
`ifdef USE_WATCHDOG
    localparam int CMD_LINE_STATE_SEQ_LEN = 20;
`else
    localparam int CMD_LINE_STATE_SEQ_LEN = 18;
`endif

`ifdef USE_WATCHDOG
    // Map cmd_series order to the expected state sequence.
    function automatic enums::control_module_fsm_e cmd_line_state_expected(input int idx);
        case (idx)
            0: cmd_line_state_expected = enums::STATE_CMD_BLANKPANEL;
            1: cmd_line_state_expected = enums::STATE_IDLE;
            2: cmd_line_state_expected = enums::STATE_CMD_WATCHDOG;
            3: cmd_line_state_expected = enums::STATE_IDLE;
            4: cmd_line_state_expected = enums::STATE_CMD_FILLPANEL;
            5: cmd_line_state_expected = enums::STATE_IDLE;
            6: cmd_line_state_expected = enums::STATE_CMD_FILLRECT;
            7: cmd_line_state_expected = enums::STATE_IDLE;
            8: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            9: cmd_line_state_expected = enums::STATE_IDLE;
            10: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            11: cmd_line_state_expected = enums::STATE_IDLE;
            12: cmd_line_state_expected = enums::STATE_CMD_READBRIGHTNESS;
            13: cmd_line_state_expected = enums::STATE_IDLE;
            14: cmd_line_state_expected = enums::STATE_CMD_READBRIGHTNESS;
            15: cmd_line_state_expected = enums::STATE_IDLE;
            16: cmd_line_state_expected = enums::STATE_CMD_READROW;
            17: cmd_line_state_expected = enums::STATE_IDLE;
            18: cmd_line_state_expected = enums::STATE_CMD_READRECT;
            19: cmd_line_state_expected = enums::STATE_CMD_READFRAME;
            default: cmd_line_state_expected = enums::control_module_fsm_e'('hf);
        endcase
    endfunction
`else
    // Map cmd_series order to the expected state sequence.
    function automatic enums::control_module_fsm_e cmd_line_state_expected(input int idx);
        case (idx)
            0: cmd_line_state_expected = enums::STATE_CMD_BLANKPANEL;
            1: cmd_line_state_expected = enums::STATE_IDLE;
            2: cmd_line_state_expected = enums::STATE_CMD_FILLPANEL;
            3: cmd_line_state_expected = enums::STATE_IDLE;
            4: cmd_line_state_expected = enums::STATE_CMD_FILLRECT;
            5: cmd_line_state_expected = enums::STATE_IDLE;
            6: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            7: cmd_line_state_expected = enums::STATE_IDLE;
            8: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            9: cmd_line_state_expected = enums::STATE_IDLE;
            10: cmd_line_state_expected = enums::STATE_CMD_READBRIGHTNESS;
            11: cmd_line_state_expected = enums::STATE_IDLE;
            12: cmd_line_state_expected = enums::STATE_CMD_READBRIGHTNESS;
            13: cmd_line_state_expected = enums::STATE_IDLE;
            14: cmd_line_state_expected = enums::STATE_CMD_READROW;
            15: cmd_line_state_expected = enums::STATE_IDLE;
            16: cmd_line_state_expected = enums::STATE_CMD_READRECT;
            17: cmd_line_state_expected = enums::STATE_CMD_READFRAME;
            default: cmd_line_state_expected = enums::control_module_fsm_e'('hf);
        endcase
    endfunction
`endif


    // Walk the expected state sequence and fail fast if any step is missing.
    initial begin : assert_cmd_line_state_sequence
        integer idx;
        enums::control_module_fsm_e expected;
        enums::control_module_fsm_e prev_expected;
        int unsigned step_cycles;
        seq_done = 1'b0;
        @(negedge reset);
        // Sentinel for "no previous state yet"; avoids readframe idle timing on first step.
        prev_expected = enums::control_module_fsm_e'('hf);
        for (idx = 0; idx < CMD_LINE_STATE_SEQ_LEN; idx = idx + 1) begin
            expected = cmd_line_state_expected(idx);
            // Allow extra time for large payloads to drain before expecting the next state.
            if ((expected == enums::STATE_CMD_READFRAME) && (prev_expected == enums::STATE_CMD_READRECT)) begin
                step_cycles = int'(READRECT_WAIT_CYCLES);
            end else if ((expected == enums::STATE_IDLE) && (prev_expected == enums::STATE_CMD_READFRAME)) begin
                step_cycles = int'(READFRAME_WAIT_CYCLES);
            end else begin
                step_cycles = int'(CMD_LINE_STATE_STEP_CYCLES);
            end
            `WAIT_ASSERT(clk, cmd_line_state === expected, step_cycles)
            $display("cmd_line_state[%0d] expected %0d observed %0d at %0t", idx, expected, cmd_line_state, $time);
            prev_expected = expected;
        end
        seq_done = 1'b1;
    end
endmodule
`endif
