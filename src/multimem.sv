// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

// multimem: A banked framebuffer RAM
//      - on ClockA, one byte written to single lane (subpanel + pixel‑color select) selected by AddressA
//      - on ClockB:
//          - AddressB reads that address from all lanes in parallel [3‑cycle read]
//          - Concatenates the data read from lanes into QB (via mem_lane)
//      - on ClockA:
//          - QA provides a single‑lane readback for the copy engine

`default_nettype none
module multimem #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
) (
    input wire types::mem_write_data_t DataInA,
    input wire [15:0] DataInB,
    input wire types::mem_write_addr_t AddressA,
    input wire types::mem_read_addr_t AddressB,
    input wire ClockA,
    input wire ClockB,
    input wire ClockEnA,
    input wire ClockEnB,
    input wire WrA,
    input wire WrB,
    input wire ResetA,
    input wire ResetB,
    output wire types::mem_write_data_t QA,
    output wire types::mem_read_data_t QB
);
    localparam integer unsigned LANES = (1 << $bits(types::mem_structure_t));
    // addra_q is QA stage 1; the lane-select pipe covers the remaining registered QA stages.
    localparam integer unsigned QA_SELECT_PIPE_DEPTH = params::MULTIMEM_QA_LATENCY - 1;
    wire types::mem_read_data_t qb_lanes_w;
    types::mem_read_data_t qb_pipe_q;
    wire types::mem_write_data_t qa_lanes_w[LANES];
    wire types::mem_write_data_t qa_masked_per_lane[LANES];
    wire types::mem_structure_t lane_idx_from_addr = types::mem_structure(AddressA);

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_lane
            //** Stage 1: register inputs
            (* keep = "true" *) types::mem_read_addr_t addra_q;
            (* keep = "true" *) types::mem_write_data_t dia_q;
            logic we_lane_q;
            // Per-lane boolean pipeline: delays the selected-lane bit so it
            // reaches qa_masked_q in the same cycle as the matching QA data.
            logic lane_sel_pipe[QA_SELECT_PIPE_DEPTH];

            // Align lane select with the registered Port A read data.
            // QA stages:
            //   1. addra_q
            //   2. mem_lane doa_pipe[0]
            //   3. mem_lane doa_pipe[1] / qa_lanes_w[i]
            //   4. qa_lane_q
            //   5. qa_masked_q
            always @(posedge ClockA) begin
                addra_q <= {AddressA.row, AddressA.col};
                dia_q   <= DataInA;
                if (ResetA) begin
                    we_lane_q <= 1'b0;
                    for (int stage = 0; stage < QA_SELECT_PIPE_DEPTH; stage++) lane_sel_pipe[stage] <= '0;
                end else begin
                    we_lane_q <= (ClockEnA & WrA) & (lane_idx_from_addr == types::mem_structure_t'(i));
                    if (ClockEnA) begin
                        lane_sel_pipe[0] <= (lane_idx_from_addr == types::mem_structure_t'(i));
                        for (int stage = 1; stage < QA_SELECT_PIPE_DEPTH; stage++) begin
                            lane_sel_pipe[stage] <= lane_sel_pipe[stage-1];
                        end
                    end
                end
            end
            mem_lane #(
                .ADDR_BITS($bits(types::mem_read_addr_t)),
                .DW($bits(types::mem_write_data_t))
            ) u_lane (
                .clka (ClockA),
                .ena  (1'b1),
                .wea  (we_lane_q),
                .rsta (ResetA),
                .addra(addra_q),
                .dia  (dia_q),
                .doa  (qa_lanes_w[i]),
                .clkb (ClockB),
                .enb  (ClockEnB),
                .rstb (ResetA || ResetB),
                .addrb(AddressB),
                .dob  (qb_lanes_w.lane[i])
            );

            // ** Stage 4: register Port A read data after mem_lane's 2-cycle pipe
            // lane_sel_pipe advances in the shift loop above to stay aligned with qa_lane_q.
            types::mem_write_data_t qa_lane_q;
            always @(posedge ClockA) begin
                if (ResetA) qa_lane_q <= '0;
                else qa_lane_q <= qa_lanes_w[i];
            end

            // ** Stage 5: per-lane masking
            types::mem_write_data_t qa_masked_q;
            always @(posedge ClockA) begin
                if (ResetA) qa_masked_q <= '0;
                else if (ClockEnA) qa_masked_q <= lane_sel_pipe[QA_SELECT_PIPE_DEPTH-1] ? qa_lane_q : '0;
            end

            assign qa_masked_per_lane[i] = qa_masked_q;

        end
    endgenerate

    // Select the single lane addressed by AddressA for the copy engine.
    types::mem_write_data_t qa_sel;
    always_comb begin
        qa_sel = '0;
        for (int lane = 0; lane < LANES; lane++) qa_sel |= qa_masked_per_lane[lane];
    end
    assign QA = qa_sel;

    // Keep the QB output stage unconditional so single-cycle ClockEnB pulses
    // still return data without routing a wide enable into every lane.
    always @(posedge ClockB) begin
        if (ResetA || ResetB) qb_pipe_q <= '0;
        else qb_pipe_q <= qb_lanes_w;
    end

    assign QB = qb_pipe_q;
    wire _unused_ok = &{1'b0, WrB, DataInB, 1'b0};
endmodule
