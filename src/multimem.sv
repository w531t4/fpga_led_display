// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

// multimem: A banked framebuffer RAM
//      - on ClockA, one byte written to single lane (subpanel + pixel‑color select) selected by AddressA
//      - on ClockB:
//          - AddressB reads one packed word from each subpanel bank [3-cycle read]
//          - Concatenates those subpanel words into QB
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
    localparam integer unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam integer unsigned SUBPANEL_WORD_BITS = $bits(types::color_field_subpanel_t);
    // addra_q is QA stage 1; the lane-select pipe covers the remaining registered QA stages.
    localparam integer unsigned QA_SELECT_PIPE_DEPTH = params::MULTIMEM_QA_LATENCY - 1;
    wire [SUBPANEL_WORD_BITS-1:0] qb_subpanel_w[NUM_SUBPANELS];
    types::mem_read_data_t qb_pipe_q;
    wire [SUBPANEL_WORD_BITS-1:0] qa_subpanel_w[NUM_SUBPANELS];
    wire [SUBPANEL_WORD_BITS-1:0] qa_masked_per_subpanel[NUM_SUBPANELS];
    types::pixel_addr_t pixel_sel_pipe[QA_SELECT_PIPE_DEPTH];
    types::pixel_addr_t pixel_sel_q;

    always @(posedge ClockA) begin
        if (ResetA) begin
            for (int stage = 0; stage < QA_SELECT_PIPE_DEPTH; stage++) pixel_sel_pipe[stage] <= '0;
        end else if (ClockEnA) begin
            pixel_sel_pipe[0] <= AddressA.pixel;
            for (int stage = 1; stage < QA_SELECT_PIPE_DEPTH; stage++) begin
                pixel_sel_pipe[stage] <= pixel_sel_pipe[stage-1];
            end
        end
    end

    always @(posedge ClockA) begin
        if (ResetA) pixel_sel_q <= '0;
        else if (ClockEnA) pixel_sel_q <= pixel_sel_pipe[QA_SELECT_PIPE_DEPTH-1];
    end

    genvar i;
    generate
        for (i = 0; i < NUM_SUBPANELS; i = i + 1) begin : g_subpanel
            //** Stage 1: register inputs
            (* keep = "true" *) types::mem_read_addr_t addra_q;
            (* keep = "true" *) types::mem_write_data_t dia_q;
            (* keep = "true" *) types::pixel_addr_t bytea_q;
            logic we_subpanel_q;
            // Register reset locally in each bank's clock domain so the BRAM
            // reset fanout stays near the consuming subpanel instead of coming
            // straight from the top-level global reset net.
            logic rsta_q;
            logic rstb_async;
            logic rstb_q;
            // Per-bank boolean pipeline: delays the selected-subpanel bit so it
            // reaches qa_masked_q in the same cycle as the matching QA word.
            logic subpanel_sel_pipe[QA_SELECT_PIPE_DEPTH];

            // Align subpanel select with the registered Port A read data.
            // QA stages:
            //   1. addra_q
            //   2. mem_subpanel doa_pipe[0]
            //   3. mem_subpanel doa_pipe[1] / qa_subpanel_w[i]
            //   4. qa_subpanel_q
            //   5. qa_masked_q
            always @(posedge ClockA or posedge ResetA) begin
                if (ResetA) rsta_q <= 1'b1;
                else rsta_q <= 1'b0;
            end

            always @(posedge ClockA) begin
                addra_q <= {AddressA.row, AddressA.col};
                dia_q   <= DataInA;
                bytea_q <= AddressA.pixel;
                if (rsta_q) begin
                    we_subpanel_q <= 1'b0;
                    for (int stage = 0; stage < QA_SELECT_PIPE_DEPTH; stage++) subpanel_sel_pipe[stage] <= '0;
                end else begin
                    we_subpanel_q <= (ClockEnA & WrA) & (AddressA.subpanel == types::subpanel_addr_t'(i));
                    if (ClockEnA) begin
                        subpanel_sel_pipe[0] <= (AddressA.subpanel == types::subpanel_addr_t'(i));
                        for (int stage = 1; stage < QA_SELECT_PIPE_DEPTH; stage++) begin
                            subpanel_sel_pipe[stage] <= subpanel_sel_pipe[stage-1];
                        end
                    end
                end
            end

            assign rstb_async = ResetA || ResetB;
            always @(posedge ClockB or posedge rstb_async) begin
                if (rstb_async) rstb_q <= 1'b1;
                else rstb_q <= 1'b0;
            end
            mem_subpanel #(
                .ADDR_BITS($bits(types::mem_read_addr_t)),
                .WORD_W(SUBPANEL_WORD_BITS),
                .BYTE_SEL_BITS($bits(types::pixel_addr_t))
            ) u_subpanel (
                .clka (ClockA),
                .ena  (1'b1),
                .wea  (we_subpanel_q),
                .rsta (rsta_q),
                .addra(addra_q),
                .bytea(bytea_q),
                .dia  (dia_q),
                .doa  (qa_subpanel_w[i]),
                .clkb (ClockB),
                .enb  (ClockEnB),
                .rstb (rstb_q),
                .addrb(AddressB),
                .dob  (qb_subpanel_w[i])
            );

            // ** Stage 4: register Port A read data after mem_subpanel's 2-cycle pipe
            // subpanel_sel_pipe advances in the shift loop above to stay aligned with qa_subpanel_q.
            logic [SUBPANEL_WORD_BITS-1:0] qa_subpanel_q;
            always @(posedge ClockA) begin
                if (rsta_q) qa_subpanel_q <= '0;
                else qa_subpanel_q <= qa_subpanel_w[i];
            end

            // ** Stage 5: per-subpanel masking
            logic [SUBPANEL_WORD_BITS-1:0] qa_masked_q;
            always @(posedge ClockA) begin
                if (rsta_q) qa_masked_q <= '0;
                else if (ClockEnA) qa_masked_q <= subpanel_sel_pipe[QA_SELECT_PIPE_DEPTH-1] ? qa_subpanel_q : '0;
            end

            assign qa_masked_per_subpanel[i] = qa_masked_q;

        end
    endgenerate

    // Select the addressed subpanel word for the copy engine, then extract the byte slot.
    logic [SUBPANEL_WORD_BITS-1:0] qa_word_sel;
    always_comb begin
        qa_word_sel = '0;
        for (int subpanel = 0; subpanel < NUM_SUBPANELS; subpanel++) qa_word_sel |= qa_masked_per_subpanel[subpanel];
    end
    assign QA = qa_word_sel[pixel_sel_q*8+:8];

    // Keep the QB output stage unconditional so single-cycle ClockEnB pulses
    // still return data without routing a wide enable into every lane.
    always @(posedge ClockB) begin
        if (ResetA || ResetB) begin
            qb_pipe_q <= '0;
        end else begin
            for (int subpanel = 0; subpanel < NUM_SUBPANELS; subpanel++) begin
                qb_pipe_q.subpanel[subpanel] <= types::color_field_subpanel_t'(qb_subpanel_w[subpanel]);
            end
        end
    end

    assign QB = qb_pipe_q;
    wire _unused_ok = &{1'b0, WrB, DataInB, 1'b0};
endmodule
