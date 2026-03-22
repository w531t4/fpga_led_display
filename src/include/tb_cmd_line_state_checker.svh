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
    // Mirror tb_main timing assumptions: 500us per step at ROOT_CLOCK.
    localparam integer CMD_LINE_STATE_STEP_NS = 500_000;
    localparam longint unsigned CMD_LINE_STATE_STEP_CYCLES =
        (64'd1 * params::ROOT_CLOCK * CMD_LINE_STATE_STEP_NS) / 1_000_000_000;

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

    // Readrect payload is smaller; compute a safe wait window for its return to IDLE.
    localparam longint unsigned READRECT_WAIT_EXTRA_BYTES = longint'(READRECT_W) * params::BYTES_PER_PIXEL;
    localparam longint unsigned READRECT_WAIT_CYCLES =
        CMD_LINE_STATE_STEP_CYCLES +
        ((longint'(READRECT_TOTAL_BYTES) + READRECT_WAIT_EXTRA_BYTES) * SPI_BYTE_CYCLES);

    // Command sequence length depends on watchdog being enabled.
`ifdef USE_WATCHDOG
    localparam int CMD_LINE_STATE_SEQ_LEN = 24;
`else
    localparam int CMD_LINE_STATE_SEQ_LEN = 22;
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
            19: cmd_line_state_expected = enums::STATE_IDLE;
            20: cmd_line_state_expected = enums::STATE_CMD_READFRAME;
            21: cmd_line_state_expected = enums::STATE_IDLE;
            22: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            23: cmd_line_state_expected = enums::STATE_IDLE;
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
            17: cmd_line_state_expected = enums::STATE_IDLE;
            18: cmd_line_state_expected = enums::STATE_CMD_READFRAME;
            19: cmd_line_state_expected = enums::STATE_IDLE;
            20: cmd_line_state_expected = enums::STATE_CMD_READPIXEL;
            21: cmd_line_state_expected = enums::STATE_IDLE;
            default: cmd_line_state_expected = enums::control_module_fsm_e'('hf);
        endcase
    endfunction
`endif

    function automatic int unsigned cmd_line_state_step_cycles(input enums::control_module_fsm_e prev_expected,
                                                               input enums::control_module_fsm_e expected);
        begin
            // Allow extra time for large payloads to drain before expecting the next state.
            if ((expected == enums::STATE_IDLE) && (prev_expected == enums::STATE_CMD_READRECT)) begin
                cmd_line_state_step_cycles = int'(READRECT_WAIT_CYCLES);
            end else if ((expected == enums::STATE_IDLE) && (prev_expected == enums::STATE_CMD_READFRAME)) begin
                cmd_line_state_step_cycles = int'(READFRAME_WAIT_CYCLES);
            end else begin
                cmd_line_state_step_cycles = int'(CMD_LINE_STATE_STEP_CYCLES);
            end
        end
    endfunction


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
            step_cycles = cmd_line_state_step_cycles(prev_expected, expected);
            `WAIT_ASSERT(clk, cmd_line_state === expected, step_cycles)
            $display("cmd_line_state[%0d] expected %0d observed %0d at %0t", idx, expected, cmd_line_state, $time);
            prev_expected = expected;
        end
        seq_done = 1'b1;
    end

    // Prove that each expected state transition is immediate: once the DUT
    // leaves one expected state, the next distinct state must be the next one
    // in the sequence. This catches cases where an eventual-state check would
    // miss an intermediate unexpected state.
    initial begin : assert_cmd_line_state_next_distinct_transition
        integer idx;
        enums::control_module_fsm_e expected;
        enums::control_module_fsm_e prev_expected;
        int unsigned step_cycles;
        int unsigned waited_cycles;
        @(negedge reset);
        prev_expected = cmd_line_state_expected(0);
        `WAIT_ASSERT(clk, cmd_line_state === prev_expected, int'(CMD_LINE_STATE_STEP_CYCLES))
        for (idx = 1; idx < CMD_LINE_STATE_SEQ_LEN; idx = idx + 1) begin
            expected = cmd_line_state_expected(idx);
            step_cycles = cmd_line_state_step_cycles(prev_expected, expected);
            waited_cycles = 0;
            while ((cmd_line_state === prev_expected) && (waited_cycles < step_cycles)) begin
                @(posedge clk);
                waited_cycles = waited_cycles + 1;
            end
            if (cmd_line_state === prev_expected) begin
                $fatal(1, "Timeout after %0d cycles waiting for transition from %0d to %0d", step_cycles,
                       prev_expected, expected);
            end
            if (cmd_line_state !== expected) begin
                $fatal(1, "Next-state mismatch after %0d: saw %0d, expected %0d", prev_expected, cmd_line_state,
                       expected);
            end
            prev_expected = expected;
        end
    end
endmodule
`endif
