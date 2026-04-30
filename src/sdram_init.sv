// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module sdram_init (
    input  logic             clk_in,
    input  logic             reset,
    output logic             done,
    output logic             busy,
    output logic             cmd_valid,
    output enums::sdram_cmd_e cmd_code,
    output logic [params::SDRAM_ADDR_BITS-1:0] cmd_addr
);
    typedef enum logic [3:0] {
        INIT_WAIT,
        INIT_PRECHARGE,
        INIT_WAIT_TRP,
        INIT_REFRESH_0,
        INIT_WAIT_RFC_0,
        INIT_REFRESH_1,
        INIT_WAIT_RFC_1,
        INIT_LOAD_MODE,
        INIT_WAIT_MRD,
        INIT_DONE
    } init_state_e;

    localparam logic [params::SDRAM_ADDR_BITS-1:0] PRECHARGE_ALL_ADDR = {
        {(params::SDRAM_ADDR_BITS - 11){1'b0}},
        1'b1,
        10'b0
    };
    localparam logic [params::SDRAM_ADDR_BITS-1:0] MODE_REGISTER_ADDR = {
        {(params::SDRAM_ADDR_BITS - 10){1'b0}},
        1'b0,                                           // write burst = programmed burst length
        2'b00,                                          // operation mode = standard
        3'(params::SDRAM_CAS_LATENCY),                  // CAS latency
        1'b0,                                           // burst type = sequential
        3'b010                                          // burst length = 4
    };

    init_state_e state;
    logic [calc::safe_clog2(params::SDRAM_INIT_WAIT_CYCLES + 1)-1:0] init_wait_count;
    logic [calc::safe_clog2(params::SDRAM_TRFC_CYCLES + 1)-1:0] trfc_count;
    logic [calc::safe_clog2(params::SDRAM_TRP_CYCLES + 1)-1:0] trp_count;
    logic [calc::safe_clog2(params::SDRAM_TMRD_CYCLES + 1)-1:0] tmrd_count;

    always_ff @(posedge clk_in) begin
        if (reset) begin
            state <= INIT_WAIT;
            init_wait_count <= '0;
            trfc_count <= '0;
            trp_count <= '0;
            tmrd_count <= '0;
        end else begin
            case (state)
                INIT_WAIT: begin
                    if (init_wait_count == $bits(init_wait_count)'(params::SDRAM_INIT_WAIT_CYCLES - 1)) begin
                        state <= INIT_PRECHARGE;
                    end else begin
                        init_wait_count <= init_wait_count + 'd1;
                    end
                end
                INIT_PRECHARGE: begin
                    state <= INIT_WAIT_TRP;
                    trp_count <= '0;
                end
                INIT_WAIT_TRP: begin
                    if (trp_count == $bits(trp_count)'(params::SDRAM_TRP_CYCLES - 1)) begin
                        state <= INIT_REFRESH_0;
                    end else begin
                        trp_count <= trp_count + 'd1;
                    end
                end
                INIT_REFRESH_0: begin
                    state <= INIT_WAIT_RFC_0;
                    trfc_count <= '0;
                end
                INIT_WAIT_RFC_0: begin
                    if (trfc_count == $bits(trfc_count)'(params::SDRAM_TRFC_CYCLES - 1)) begin
                        state <= INIT_REFRESH_1;
                    end else begin
                        trfc_count <= trfc_count + 'd1;
                    end
                end
                INIT_REFRESH_1: begin
                    state <= INIT_WAIT_RFC_1;
                    trfc_count <= '0;
                end
                INIT_WAIT_RFC_1: begin
                    if (trfc_count == $bits(trfc_count)'(params::SDRAM_TRFC_CYCLES - 1)) begin
                        state <= INIT_LOAD_MODE;
                    end else begin
                        trfc_count <= trfc_count + 'd1;
                    end
                end
                INIT_LOAD_MODE: begin
                    state <= INIT_WAIT_MRD;
                    tmrd_count <= '0;
                end
                INIT_WAIT_MRD: begin
                    if (tmrd_count == $bits(tmrd_count)'(params::SDRAM_TMRD_CYCLES - 1)) begin
                        state <= INIT_DONE;
                    end else begin
                        tmrd_count <= tmrd_count + 'd1;
                    end
                end
                INIT_DONE: begin
                end
                default: begin
                    state <= INIT_WAIT;
                end
            endcase
        end
    end

    always_comb begin
        done = (state == INIT_DONE);
        busy = (state != INIT_DONE);
        cmd_valid = 1'b1;
        cmd_code = enums::SDRAM_CMD_NOP;
        cmd_addr = '0;

        case (state)
            INIT_PRECHARGE: begin
                cmd_code = enums::SDRAM_CMD_PRECHARGE;
                cmd_addr = PRECHARGE_ALL_ADDR;
            end
            INIT_REFRESH_0, INIT_REFRESH_1: begin
                cmd_code = enums::SDRAM_CMD_AUTO_REFRESH;
            end
            INIT_LOAD_MODE: begin
                cmd_code = enums::SDRAM_CMD_LOAD_MODE;
                cmd_addr = MODE_REGISTER_ADDR;
            end
            default: begin
            end
        endcase
    end
endmodule
