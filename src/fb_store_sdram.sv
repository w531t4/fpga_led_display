// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module fb_store_sdram (
    input logic clk_root,
    input logic reset,

    fb_store_if.backend store_if,

    output logic sdram_clk,
    output logic sdram_cke,
    output logic sdram_csn,
    output logic sdram_rasn,
    output logic sdram_casn,
    output logic sdram_wen,
    output logic [params::SDRAM_ADDR_BITS-1:0] sdram_a,
    output logic [params::SDRAM_BANK_BITS-1:0] sdram_ba,
    output logic [params::SDRAM_DQM_BITS-1:0] sdram_dqm,
    output logic [params::SDRAM_DATA_BITS-1:0] sdram_dq_out,
    output logic sdram_dq_oe,
    input  logic [params::SDRAM_DATA_BITS-1:0] sdram_dq_in
);
    localparam int unsigned NUM_SUBPANELS = calc::num_subpanels(params::PIXEL_HEIGHT, params::PIXEL_HALFHEIGHT);
    localparam int unsigned BURST_WORD_BITS = params::SDRAM_DATA_BITS * params::SDRAM_BURST_LENGTH;
    localparam int unsigned BURST_BYTES = params::SDRAM_BURST_BYTES;
    localparam int unsigned ROW_BYTES = params::PIXEL_WIDTH * params::BYTES_PER_PIXEL;
    localparam int unsigned COLOR_BYTES = calc::num_bytes_to_contain($bits(types::color_t));

    typedef enum logic [4:0] {
        STORE_IDLE,
        STORE_CMD_READ_REQ,
        STORE_CMD_READ_WAIT,
        STORE_CMD_WRITE_REQ,
        STORE_CMD_WRITE_WAIT,
        STORE_PREFETCH_ROW_REQ,
        STORE_PREFETCH_ROW_WAIT,
        STORE_PREFETCH_STREAM,
        STORE_COPY_READ_REQ,
        STORE_COPY_READ_WAIT,
        STORE_COPY_WRITE_REQ,
        STORE_COPY_WRITE_WAIT,
        STORE_COPY_DONE
    } store_state_e;

    store_state_e state;

    logic controller_req_valid;
    logic controller_req_ready;
    logic controller_req_write;
    logic [params::SDRAM_BANK_BITS-1:0] controller_req_bank;
    logic [params::SDRAM_ROW_BITS-1:0] controller_req_row;
    logic [params::SDRAM_COLUMN_BITS-1:0] controller_req_col;
    logic [BURST_WORD_BITS-1:0] controller_req_write_data;
    logic controller_resp_valid;
    logic [BURST_WORD_BITS-1:0] controller_resp_read_data;
    logic controller_init_done;
    logic controller_refresh_active;
    logic controller_busy;

    types::color_field_t prefetch_cache[NUM_SUBPANELS][params::PIXEL_WIDTH];
    types::color_field_t prefetch_pixels_q[NUM_SUBPANELS];
    types::sdram_byte_addr_t cmd_target_byte_addr_q;
    types::sdram_byte_addr_t burst_base_byte_addr_q;
    types::sdram_byte_addr_t prefetch_row_base_q;
    types::sdram_byte_addr_t prefetch_row_end_q;
    types::sdram_byte_addr_t copy_src_byte_addr_q;
    types::sdram_byte_addr_t copy_dst_byte_addr_q;
    logic [BURST_WORD_BITS-1:0] burst_data_q;
    logic [BURST_WORD_BITS-1:0] copy_burst_data_q;
    logic [calc::safe_clog2(NUM_SUBPANELS)-1:0] prefetch_subpanel_index_q;
    types::col_addr_t prefetch_stream_col_q;
    logic copy_done_q;

    function automatic logic front_frame_index(input logic frame_select);
`ifdef DOUBLE_BUFFER
        front_frame_index = frame_select;
`else
        front_frame_index = 1'b0;
`endif
    endfunction

    function automatic logic back_frame_index(input logic frame_select);
`ifdef DOUBLE_BUFFER
        back_frame_index = ~frame_select;
`else
        back_frame_index = 1'b0;
`endif
    endfunction

    function automatic types::row_addr_t logical_row_for_subpanel(input types::row_subpanel_addr_t row_in_subpanel,
                                                                  input int unsigned subpanel_index);
        logical_row_for_subpanel = types::row_addr_t'(types::uint_t'(row_in_subpanel)
                                                      + (types::uint_t'(subpanel_index) * params::PIXEL_HALFHEIGHT));
    endfunction

    function automatic types::sdram_byte_addr_t align_down_to_burst(input types::sdram_byte_addr_t byte_addr);
        align_down_to_burst = types::sdram_byte_addr_t'(longint'(byte_addr)
                                                        - (longint'(byte_addr) % longint'(BURST_BYTES)));
    endfunction

    function automatic logic [7:0] burst_byte(input logic [BURST_WORD_BITS-1:0] burst_data,
                                              input int unsigned byte_index);
        int unsigned word_index;
        int unsigned byte_lane;
        word_index = byte_index / params::SDRAM_WORD_BYTES;
        byte_lane = byte_index % params::SDRAM_WORD_BYTES;
        burst_byte = burst_data[(word_index * params::SDRAM_DATA_BITS) + (byte_lane * 8) +: 8];
    endfunction

    function automatic logic [BURST_WORD_BITS-1:0] burst_write_byte(input logic [BURST_WORD_BITS-1:0] burst_data,
                                                                    input int unsigned byte_index,
                                                                    input logic [7:0] byte_value);
        logic [BURST_WORD_BITS-1:0] updated;
        int unsigned word_index;
        int unsigned byte_lane;
        updated = burst_data;
        word_index = byte_index / params::SDRAM_WORD_BYTES;
        byte_lane = byte_index % params::SDRAM_WORD_BYTES;
        updated[(word_index * params::SDRAM_DATA_BITS) + (byte_lane * 8) +: 8] = byte_value;
        burst_write_byte = updated;
    endfunction

    task automatic load_controller_address(input types::sdram_byte_addr_t byte_addr,
                                           output logic [params::SDRAM_BANK_BITS-1:0] bank,
                                           output logic [params::SDRAM_ROW_BITS-1:0] row,
                                           output logic [params::SDRAM_COLUMN_BITS-1:0] col);
        types::sdram_word_addr_t word_addr;
        begin
            word_addr = types::sdram_word_addr_from_byte_addr(byte_addr);
            bank = word_addr.bank;
            row = word_addr.row;
            col = word_addr.col;
        end
    endtask

    sdram_controller controller (
        .clk_in(clk_root),
        .reset(reset),
        .host_req_valid(controller_req_valid),
        .host_req_ready(controller_req_ready),
        .host_req_write(controller_req_write),
        .host_req_bank(controller_req_bank),
        .host_req_row(controller_req_row),
        .host_req_col(controller_req_col),
        .host_req_write_data(controller_req_write_data),
        .host_resp_valid(controller_resp_valid),
        .host_resp_read_data(controller_resp_read_data),
        .init_done(controller_init_done),
        .refresh_active(controller_refresh_active),
        .controller_busy(controller_busy),
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

    integer subpanel_idx;
    integer col_idx;
    integer byte_idx;
    always_ff @(posedge clk_root) begin
        if (reset) begin
            state <= STORE_IDLE;
            cmd_target_byte_addr_q <= '0;
            burst_base_byte_addr_q <= '0;
            prefetch_row_base_q <= '0;
            prefetch_row_end_q <= '0;
            copy_src_byte_addr_q <= '0;
            copy_dst_byte_addr_q <= '0;
            burst_data_q <= '0;
            copy_burst_data_q <= '0;
            prefetch_subpanel_index_q <= '0;
            prefetch_stream_col_q <= '0;
            copy_done_q <= 1'b0;
            for (subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx = subpanel_idx + 1) begin
                prefetch_pixels_q[subpanel_idx] <= '0;
                for (col_idx = 0; col_idx < params::PIXEL_WIDTH; col_idx = col_idx + 1) begin
                    prefetch_cache[subpanel_idx][col_idx] <= '0;
                end
            end
        end else begin
            copy_done_q <= 1'b0;

            case (state)
                STORE_IDLE: begin
                    if (controller_init_done && store_if.copy_start) begin
                        copy_src_byte_addr_q <= types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select));
                        copy_dst_byte_addr_q <= types::sdram_frame_base_bytes(back_frame_index(store_if.frame_select));
                        state <= STORE_COPY_READ_REQ;
                    end else if (controller_init_done && store_if.prefetch_req_valid) begin
                        for (subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx = subpanel_idx + 1) begin
                            for (col_idx = 0; col_idx < params::PIXEL_WIDTH; col_idx = col_idx + 1) begin
                                prefetch_cache[subpanel_idx][col_idx] <= '0;
                            end
                        end
                        prefetch_subpanel_index_q <= '0;
                        prefetch_stream_col_q <= '0;
                        prefetch_row_base_q <= types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                                               + types::sdram_byte_addr_t'(
                                                   types::uint_t'(logical_row_for_subpanel(store_if.prefetch_row, 0))
                                                   * ROW_BYTES
                                               );
                        prefetch_row_end_q <= types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                                              + types::sdram_byte_addr_t'(
                                                  (types::uint_t'(logical_row_for_subpanel(store_if.prefetch_row, 0))
                                                   * ROW_BYTES) + ROW_BYTES
                                              );
                        burst_base_byte_addr_q <= align_down_to_burst(
                            types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                            + types::sdram_byte_addr_t'(
                                types::uint_t'(logical_row_for_subpanel(store_if.prefetch_row, 0)) * ROW_BYTES
                            )
                        );
                        state <= STORE_PREFETCH_ROW_REQ;
                    end else if (controller_init_done && store_if.cmd_write_valid) begin
                        cmd_target_byte_addr_q <= types::sdram_frame_byte_addr(back_frame_index(store_if.frame_select),
                                                                               store_if.cmd_write_addr);
                        burst_base_byte_addr_q <= align_down_to_burst(
                            types::sdram_frame_byte_addr(back_frame_index(store_if.frame_select), store_if.cmd_write_addr)
                        );
                        state <= STORE_CMD_READ_REQ;
                    end
                end
                STORE_CMD_READ_REQ: begin
                    if (controller_req_ready) begin
                        state <= STORE_CMD_READ_WAIT;
                    end
                end
                STORE_CMD_READ_WAIT: begin
                    if (controller_resp_valid) begin
                        burst_data_q <= burst_write_byte(
                            controller_resp_read_data,
                            int'(longint'(cmd_target_byte_addr_q) - longint'(burst_base_byte_addr_q)),
                            store_if.cmd_write_data
                        );
                        state <= STORE_CMD_WRITE_REQ;
                    end
                end
                STORE_CMD_WRITE_REQ: begin
                    if (controller_req_ready) begin
                        state <= STORE_CMD_WRITE_WAIT;
                    end
                end
                STORE_CMD_WRITE_WAIT: begin
                    if (!controller_busy) begin
                        state <= STORE_IDLE;
                    end
                end
                STORE_PREFETCH_ROW_REQ: begin
                    if (controller_req_ready) begin
                        state <= STORE_PREFETCH_ROW_WAIT;
                    end
                end
                STORE_PREFETCH_ROW_WAIT: begin
                    if (controller_resp_valid) begin
                        /* verilator lint_off BLKSEQ */
                        for (byte_idx = 0; byte_idx < BURST_BYTES; byte_idx = byte_idx + 1) begin
                            longint unsigned cache_byte_addr_abs;
                            int row_relative_byte;
                            int cache_col_idx;
                            int cache_pixel_idx;

                            cache_byte_addr_abs = longint'(burst_base_byte_addr_q) + longint'(byte_idx);
                            if (cache_byte_addr_abs >= longint'(prefetch_row_base_q)
                                && cache_byte_addr_abs < longint'(prefetch_row_end_q)) begin
                                row_relative_byte = int'(cache_byte_addr_abs - longint'(prefetch_row_base_q));
                                cache_col_idx = row_relative_byte / params::BYTES_PER_PIXEL;
                                cache_pixel_idx = row_relative_byte % params::BYTES_PER_PIXEL;
                                if (cache_col_idx < params::PIXEL_WIDTH) begin
                                    prefetch_cache[prefetch_subpanel_index_q][cache_col_idx].bytes[cache_pixel_idx]
                                        <= burst_byte(controller_resp_read_data, byte_idx);
                                end
                            end
                        end
                        /* verilator lint_on BLKSEQ */

                        if ((longint'(burst_base_byte_addr_q) + longint'(BURST_BYTES)) < longint'(prefetch_row_end_q)) begin
                            burst_base_byte_addr_q <= types::sdram_byte_addr_t'(longint'(burst_base_byte_addr_q)
                                                                                + longint'(BURST_BYTES));
                            state <= STORE_PREFETCH_ROW_REQ;
                        end else if (prefetch_subpanel_index_q
                                     != $bits(prefetch_subpanel_index_q)'(NUM_SUBPANELS - 1)) begin
                            prefetch_subpanel_index_q <= prefetch_subpanel_index_q + 'd1;
                            prefetch_row_base_q <= types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                                                   + types::sdram_byte_addr_t'(
                                                       types::uint_t'(logical_row_for_subpanel(store_if.prefetch_row,
                                                                                               int'(prefetch_subpanel_index_q) + 1))
                                                       * ROW_BYTES
                                                   );
                            prefetch_row_end_q <= types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                                                  + types::sdram_byte_addr_t'(
                                                      (types::uint_t'(
                                                           logical_row_for_subpanel(
                                                               store_if.prefetch_row,
                                                               int'(prefetch_subpanel_index_q) + 1
                                                           )
                                                       ) * ROW_BYTES) + ROW_BYTES
                                                  );
                            burst_base_byte_addr_q <= align_down_to_burst(
                                types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select))
                                + types::sdram_byte_addr_t'(
                                    types::uint_t'(
                                        logical_row_for_subpanel(store_if.prefetch_row,
                                                                 int'(prefetch_subpanel_index_q) + 1)
                                    )
                                    * ROW_BYTES
                                )
                            );
                            state <= STORE_PREFETCH_ROW_REQ;
                        end else begin
                            for (subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx = subpanel_idx + 1) begin
                                prefetch_pixels_q[subpanel_idx] <= prefetch_cache[subpanel_idx][0];
                            end
                            prefetch_stream_col_q <= '0;
                            state <= STORE_PREFETCH_STREAM;
                        end
                    end
                end
                STORE_PREFETCH_STREAM: begin
                    if (store_if.prefetch_data_ready) begin
                        if (prefetch_stream_col_q == types::col_addr_t'(params::PIXEL_WIDTH - 1)) begin
                            state <= STORE_IDLE;
                        end else begin
                            prefetch_stream_col_q <= prefetch_stream_col_q + 'd1;
                            for (subpanel_idx = 0; subpanel_idx < NUM_SUBPANELS; subpanel_idx = subpanel_idx + 1) begin
                                prefetch_pixels_q[subpanel_idx] <= prefetch_cache[subpanel_idx][prefetch_stream_col_q + 'd1];
                            end
                        end
                    end
                end
                STORE_COPY_READ_REQ: begin
                    if (controller_req_ready) begin
                        state <= STORE_COPY_READ_WAIT;
                    end
                end
                STORE_COPY_READ_WAIT: begin
                    if (controller_resp_valid) begin
                        copy_burst_data_q <= controller_resp_read_data;
                        state <= STORE_COPY_WRITE_REQ;
                    end
                end
                STORE_COPY_WRITE_REQ: begin
                    if (controller_req_ready) begin
                        state <= STORE_COPY_WRITE_WAIT;
                    end
                end
                STORE_COPY_WRITE_WAIT: begin
                    if (!controller_busy) begin
                        if ((longint'(copy_src_byte_addr_q) + longint'(BURST_BYTES))
                            < (longint'(types::sdram_frame_base_bytes(front_frame_index(store_if.frame_select)))
                               + params::SDRAM_FRAME_STRIDE_BYTES)) begin
                            copy_src_byte_addr_q <= types::sdram_byte_addr_t'(longint'(copy_src_byte_addr_q)
                                                                              + longint'(BURST_BYTES));
                            copy_dst_byte_addr_q <= types::sdram_byte_addr_t'(longint'(copy_dst_byte_addr_q)
                                                                              + longint'(BURST_BYTES));
                            state <= STORE_COPY_READ_REQ;
                        end else begin
                            copy_done_q <= 1'b1;
                            state <= STORE_COPY_DONE;
                        end
                    end
                end
                STORE_COPY_DONE: begin
                    state <= STORE_IDLE;
                end
                default: begin
                    state <= STORE_IDLE;
                end
            endcase
        end
    end

    always_comb begin
        controller_req_valid = 1'b0;
        controller_req_write = 1'b0;
        controller_req_bank = '0;
        controller_req_row = '0;
        controller_req_col = '0;
        controller_req_write_data = '0;

        case (state)
            STORE_CMD_READ_REQ, STORE_PREFETCH_ROW_REQ, STORE_COPY_READ_REQ: begin
                controller_req_valid = 1'b1;
                if (state == STORE_COPY_READ_REQ) begin
                    load_controller_address(copy_src_byte_addr_q, controller_req_bank, controller_req_row, controller_req_col);
                end else begin
                    load_controller_address(burst_base_byte_addr_q, controller_req_bank, controller_req_row, controller_req_col);
                end
            end
            STORE_CMD_WRITE_REQ: begin
                controller_req_valid = 1'b1;
                controller_req_write = 1'b1;
                controller_req_write_data = burst_data_q;
                load_controller_address(burst_base_byte_addr_q, controller_req_bank, controller_req_row, controller_req_col);
            end
            STORE_COPY_WRITE_REQ: begin
                controller_req_valid = 1'b1;
                controller_req_write = 1'b1;
                controller_req_write_data = copy_burst_data_q;
                load_controller_address(copy_dst_byte_addr_q, controller_req_bank, controller_req_row, controller_req_col);
            end
            default: begin
            end
        endcase
    end

    assign store_if.backend_ready = controller_init_done;
    assign store_if.backend_error = 1'b0;
    assign store_if.cmd_write_ready = (state == STORE_IDLE) && controller_init_done && !store_if.copy_start
                                      && !store_if.prefetch_req_valid;
    assign store_if.prefetch_req_ready = (state == STORE_IDLE) && controller_init_done && !store_if.copy_start;
    assign store_if.prefetch_data_valid = (state == STORE_PREFETCH_STREAM);
    assign store_if.prefetch_data_first = (state == STORE_PREFETCH_STREAM) && (prefetch_stream_col_q == '0);
    assign store_if.prefetch_data_last = (state == STORE_PREFETCH_STREAM)
                                         && (prefetch_stream_col_q == types::col_addr_t'(params::PIXEL_WIDTH - 1));
    assign store_if.prefetch_col = prefetch_stream_col_q;
    assign store_if.copy_busy = (state == STORE_COPY_READ_REQ) || (state == STORE_COPY_READ_WAIT)
                                || (state == STORE_COPY_WRITE_REQ) || (state == STORE_COPY_WRITE_WAIT);
    assign store_if.copy_done = copy_done_q;

    genvar out_subpanel_idx;
    generate
        for (out_subpanel_idx = 0; out_subpanel_idx < NUM_SUBPANELS; out_subpanel_idx = out_subpanel_idx + 1) begin
            assign store_if.prefetch_pixels[out_subpanel_idx] = prefetch_pixels_q[out_subpanel_idx];
        end
    endgenerate

    wire _unused_ok = &{1'b0,
                        controller_refresh_active,
                        COLOR_BYTES,
                        controller_busy,
                        1'b0};
endmodule
