// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT

// multimem: A banked framebuffer RAM
//      - on ClockA, one byte written to single lane (subpanel + pixel‑color select) selected by AddressA
//      - on ClockB:
//          - AddressB reads that address from all lanes in parallel [2‑cycle read]
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
    // consider
    // 8 bits addr a, 2 bits colorselect, 2 bits display
    //      addrA = 8
    //      colorselect = 2
    //      display = 2

    //      7 display          = (addrA - 1)
    //      6 display          = (addrA - display)
    //      5 body             = (addrA - display) -1           // aka addrb
    //      4 body             =                                // aka addrb
    //      3 body             =                                // aka addrb
    //      2 body             = (colorselect - 1) + 1          // aka addrb
    //      1 pixelcolorselect = colorselect - 1
    //      0 pixelcolorselect = 0
    //  [7:0] mem [displaybits,colorselectbits] [addr_b bits]

    localparam integer unsigned LANES = (1 << $bits(types::mem_structure_t));
    localparam integer unsigned QA_PIPE_DEPTH = 3;
    wire types::mem_read_data_t qb_lanes_w;
    wire types::mem_write_data_t qa_lanes_w[LANES];
    wire types::mem_write_data_t qa_masked_per_lane[LANES];
    wire types::mem_structure_t lane_idx_from_addr = types::mem_structure(AddressA);
    // Register write qualifiers once to keep the wide ClockEnA fanout out of the per-lane BRAM enables.
    logic wr_en_q;
    types::mem_structure_t lane_idx_w_q;

    // Capture the write lane index and enable in the same stage as addra_q/dia_q.
    // This preserves the existing one-cycle write latency while shortening the critical enable route.
    always @(posedge ClockA) begin
        if (ResetA) begin
            wr_en_q <= 1'b0;
            lane_idx_w_q <= '0;
        end else begin
            wr_en_q <= ClockEnA & WrA;
            lane_idx_w_q <= lane_idx_from_addr;
        end
    end

    genvar i;
    generate
        for (i = 0; i < LANES; i = i + 1) begin : g_lane
            (* keep = "true" *) types::mem_read_addr_t addra_q;
            (* keep = "true" *) types::mem_write_data_t dia_q;
            types::mem_write_data_t qa_lane_q;
            types::mem_write_data_t qa_masked_q;
            // Per-lane boolean pipeline: tracks whether this lane is selected,
            // delayed QA_PIPE_DEPTH stages to align with the BRAM OUTREG output.
            logic lane_sel_pipe[QA_PIPE_DEPTH];

            // Use the registered write qualifier to keep per-lane write enables local.
            wire we_lane_sel = wr_en_q & (lane_idx_w_q == types::mem_structure_t'(i));

            // Align lane select with the registered Port A read data.
            // QA latency is: AddressA -> addra_q -> mem_lane doa -> qa_lane_q -> qa_pipe_q.
            // Shift the lane index by the same number of cycles so QA selects the correct lane
            // even when AddressA changes every cycle (copyframe fast path).
            always @(posedge ClockA) begin
                if (ResetA) begin
                    for (int stage = 0; stage < QA_PIPE_DEPTH; stage++) lane_sel_pipe[stage] <= '0;
                end else if (ClockEnA) begin
                    lane_sel_pipe[0] <= (lane_idx_from_addr == types::mem_structure_t'(i));
                    for (int stage = 1; stage < QA_PIPE_DEPTH; stage++) lane_sel_pipe[stage] <= lane_sel_pipe[stage-1];
                end
            end

            always @(posedge ClockA) begin
                addra_q <= {AddressA.row, AddressA.col};
                dia_q   <= DataInA;
            end

            mem_lane #(
                .ADDR_BITS($bits(types::mem_read_addr_t)),
                .DW($bits(types::mem_write_data_t))
            ) u_lane (
                .clka (ClockA),
                .ena  (1'b1),
                .wea  (we_lane_sel),
                .addra(addra_q),
                .dia  (dia_q),
                .doa  (qa_lanes_w[i]),
                .clkb (ClockB),
                .enb  (ClockEnB),
                .rstb (ResetA || ResetB),
                .addrb(AddressB),
                .dob  (qb_lanes_w.lane[i])
            );

            // Unconditional so ecp5_infer_bram_outreg can pack this into the BRAM OUTREG (constant OCEA).
            always @(posedge ClockA) begin
                qa_lane_q <= qa_lanes_w[i];
            end

            // Mask this lane's output here, near the BRAM.
            // The long BRAM OUTREG routing stays before this register boundary.
            always @(posedge ClockA) begin
                if (ClockEnA) qa_masked_q <= lane_sel_pipe[QA_PIPE_DEPTH-1] ? qa_lane_q : '0;
            end

            assign qa_masked_per_lane[i] = qa_masked_q;

        end
    endgenerate

    assign QB = qb_lanes_w;
    // Select the single lane addressed by AddressA for the copy engine.
    types::mem_write_data_t qa_sel;
    always_comb begin
        qa_sel = '0;
        for (int lane = 0; lane < LANES; lane++) qa_sel |= qa_masked_per_lane[lane];
    end
    assign QA = qa_sel;
    wire _unused_ok = &{1'b0, WrB, DataInB, 1'b0};
endmodule
