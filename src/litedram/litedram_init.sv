// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

// Minimal hardware version of the LiteDRAM SDR init sequence emitted in
// build/litedram/software/include/generated/sdram_phy.h. This only covers the
// current GENSDRPHY/MT48LC16M16 configuration: one DFI phase, SDR, CL=2, BL=1.
module litedram_init (
    input  logic        clk,
    input  logic        reset,

    output logic [29:0] wb_adr,
    output logic [31:0] wb_dat_w,
    input  logic [31:0] wb_dat_r,
    output logic  [3:0] wb_sel,
    output logic        wb_cyc,
    output logic        wb_stb,
    output logic        wb_we,
    input  logic        wb_ack,
    output logic  [2:0] wb_cti,
    output logic  [1:0] wb_bte,

    output logic        done
);
    localparam logic [29:0] CSR_DDRCTRL_INIT_DONE_WORD      = 30'h000;
    localparam logic [29:0] CSR_DDRCTRL_INIT_ERROR_WORD     = 30'h001;
    localparam logic [29:0] CSR_SDRAM_DFII_CONTROL_WORD     = 30'h200;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_COMMAND_WORD = 30'h201;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_ISSUE_WORD   = 30'h202;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_ADDRESS_WORD = 30'h203;
    localparam logic [29:0] CSR_SDRAM_DFII_PI0_BADDR_WORD   = 30'h204;

    localparam logic [31:0] DFII_CONTROL_SEL     = 32'h0000_0001;
    localparam logic [31:0] DFII_CONTROL_CKE     = 32'h0000_0002;
    localparam logic [31:0] DFII_CONTROL_ODT     = 32'h0000_0004;
    localparam logic [31:0] DFII_CONTROL_RESET_N = 32'h0000_0008;

    localparam logic [31:0] DFII_COMMAND_CS  = 32'h0000_0001;
    localparam logic [31:0] DFII_COMMAND_WE  = 32'h0000_0002;
    localparam logic [31:0] DFII_COMMAND_CAS = 32'h0000_0004;
    localparam logic [31:0] DFII_COMMAND_RAS = 32'h0000_0008;

    localparam logic [31:0] DFII_CONTROL_SOFTWARE = DFII_CONTROL_CKE | DFII_CONTROL_ODT | DFII_CONTROL_RESET_N;
    localparam logic [31:0] DFII_CONTROL_HARDWARE = DFII_CONTROL_SEL;

    localparam logic [31:0] SDRAM_CMD_PRECHARGE_ALL = DFII_COMMAND_RAS | DFII_COMMAND_WE | DFII_COMMAND_CS;
    localparam logic [31:0] SDRAM_CMD_LOAD_MODE     = DFII_COMMAND_RAS | DFII_COMMAND_CAS | DFII_COMMAND_WE | DFII_COMMAND_CS;
    localparam logic [31:0] SDRAM_CMD_AUTO_REFRESH  = DFII_COMMAND_RAS | DFII_COMMAND_CAS | DFII_COMMAND_CS;

    localparam logic [31:0] SDRAM_ADDR_PRECHARGE_ALL = 32'h0000_0400;
    localparam logic [31:0] SDRAM_MODE_RESET_DLL     = 32'h0000_0120;
    localparam logic [31:0] SDRAM_MODE_NORMAL        = 32'h0000_0020;

    localparam int unsigned INIT_POWERUP_WAIT_TICKS = 20000;
    localparam int unsigned INIT_SHORT_WAIT_TICKS   = 200;
    localparam int unsigned INIT_REFRESH_WAIT_TICKS = 4;
    localparam int unsigned WAIT_COUNT_BITS         = $clog2(INIT_POWERUP_WAIT_TICKS + 1);

    typedef enum logic [5:0] {
        STEP_CLEAR_DONE,
        STEP_CLEAR_ERROR,
        STEP_SW_CONTROL,
        STEP_CKE_HIGH,
        STEP_PRECHARGE0_ADDR,
        STEP_PRECHARGE0_BANK,
        STEP_PRECHARGE0_CMD,
        STEP_PRECHARGE0_ISSUE,
        STEP_MODE_RESET_ADDR,
        STEP_MODE_RESET_BANK,
        STEP_MODE_RESET_CMD,
        STEP_MODE_RESET_ISSUE,
        STEP_PRECHARGE1_ADDR,
        STEP_PRECHARGE1_BANK,
        STEP_PRECHARGE1_CMD,
        STEP_PRECHARGE1_ISSUE,
        STEP_REFRESH0_ADDR,
        STEP_REFRESH0_BANK,
        STEP_REFRESH0_CMD,
        STEP_REFRESH0_ISSUE,
        STEP_REFRESH1_ADDR,
        STEP_REFRESH1_BANK,
        STEP_REFRESH1_CMD,
        STEP_REFRESH1_ISSUE,
        STEP_MODE_NORMAL_ADDR,
        STEP_MODE_NORMAL_BANK,
        STEP_MODE_NORMAL_CMD,
        STEP_MODE_NORMAL_ISSUE,
        STEP_HW_CONTROL,
        STEP_SET_DONE,
        STEP_DONE
    } step_t;

    typedef enum logic [1:0] {
        PHASE_WRITE,
        PHASE_DELAY,
        PHASE_GAP,
        PHASE_DONE
    } phase_t;

    step_t step_q;
    step_t step_next;
    phase_t phase_q;
    logic [WAIT_COUNT_BITS-1:0] delay_count_q;
    logic [WAIT_COUNT_BITS-1:0] delay_after_write;
    logic [29:0] write_addr;
    logic [31:0] write_data;

    always_comb begin
        step_next = STEP_DONE;
        write_addr = CSR_DDRCTRL_INIT_DONE_WORD;
        write_data = 32'h0000_0000;
        delay_after_write = '0;

        case (step_q)
            STEP_CLEAR_DONE: begin
                write_addr = CSR_DDRCTRL_INIT_DONE_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_CLEAR_ERROR;
            end
            STEP_CLEAR_ERROR: begin
                write_addr = CSR_DDRCTRL_INIT_ERROR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_SW_CONTROL;
            end
            STEP_SW_CONTROL: begin
                write_addr = CSR_SDRAM_DFII_CONTROL_WORD;
                write_data = DFII_CONTROL_SOFTWARE;
                step_next = STEP_CKE_HIGH;
            end
            STEP_CKE_HIGH: begin
                write_addr = CSR_SDRAM_DFII_CONTROL_WORD;
                write_data = DFII_CONTROL_SOFTWARE;
                delay_after_write = WAIT_COUNT_BITS'(INIT_POWERUP_WAIT_TICKS);
                step_next = STEP_PRECHARGE0_ADDR;
            end
            STEP_PRECHARGE0_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = SDRAM_ADDR_PRECHARGE_ALL;
                step_next = STEP_PRECHARGE0_BANK;
            end
            STEP_PRECHARGE0_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_PRECHARGE0_CMD;
            end
            STEP_PRECHARGE0_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_PRECHARGE_ALL;
                step_next = STEP_PRECHARGE0_ISSUE;
            end
            STEP_PRECHARGE0_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                step_next = STEP_MODE_RESET_ADDR;
            end
            STEP_MODE_RESET_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = SDRAM_MODE_RESET_DLL;
                step_next = STEP_MODE_RESET_BANK;
            end
            STEP_MODE_RESET_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_MODE_RESET_CMD;
            end
            STEP_MODE_RESET_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_LOAD_MODE;
                step_next = STEP_MODE_RESET_ISSUE;
            end
            STEP_MODE_RESET_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                delay_after_write = WAIT_COUNT_BITS'(INIT_SHORT_WAIT_TICKS);
                step_next = STEP_PRECHARGE1_ADDR;
            end
            STEP_PRECHARGE1_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = SDRAM_ADDR_PRECHARGE_ALL;
                step_next = STEP_PRECHARGE1_BANK;
            end
            STEP_PRECHARGE1_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_PRECHARGE1_CMD;
            end
            STEP_PRECHARGE1_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_PRECHARGE_ALL;
                step_next = STEP_PRECHARGE1_ISSUE;
            end
            STEP_PRECHARGE1_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                step_next = STEP_REFRESH0_ADDR;
            end
            STEP_REFRESH0_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_REFRESH0_BANK;
            end
            STEP_REFRESH0_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_REFRESH0_CMD;
            end
            STEP_REFRESH0_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_AUTO_REFRESH;
                step_next = STEP_REFRESH0_ISSUE;
            end
            STEP_REFRESH0_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                delay_after_write = WAIT_COUNT_BITS'(INIT_REFRESH_WAIT_TICKS);
                step_next = STEP_REFRESH1_ADDR;
            end
            STEP_REFRESH1_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_REFRESH1_BANK;
            end
            STEP_REFRESH1_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_REFRESH1_CMD;
            end
            STEP_REFRESH1_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_AUTO_REFRESH;
                step_next = STEP_REFRESH1_ISSUE;
            end
            STEP_REFRESH1_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                delay_after_write = WAIT_COUNT_BITS'(INIT_REFRESH_WAIT_TICKS);
                step_next = STEP_MODE_NORMAL_ADDR;
            end
            STEP_MODE_NORMAL_ADDR: begin
                write_addr = CSR_SDRAM_DFII_PI0_ADDRESS_WORD;
                write_data = SDRAM_MODE_NORMAL;
                step_next = STEP_MODE_NORMAL_BANK;
            end
            STEP_MODE_NORMAL_BANK: begin
                write_addr = CSR_SDRAM_DFII_PI0_BADDR_WORD;
                write_data = 32'h0000_0000;
                step_next = STEP_MODE_NORMAL_CMD;
            end
            STEP_MODE_NORMAL_CMD: begin
                write_addr = CSR_SDRAM_DFII_PI0_COMMAND_WORD;
                write_data = SDRAM_CMD_LOAD_MODE;
                step_next = STEP_MODE_NORMAL_ISSUE;
            end
            STEP_MODE_NORMAL_ISSUE: begin
                write_addr = CSR_SDRAM_DFII_PI0_ISSUE_WORD;
                write_data = 32'h0000_0001;
                delay_after_write = WAIT_COUNT_BITS'(INIT_SHORT_WAIT_TICKS);
                step_next = STEP_HW_CONTROL;
            end
            STEP_HW_CONTROL: begin
                write_addr = CSR_SDRAM_DFII_CONTROL_WORD;
                write_data = DFII_CONTROL_HARDWARE;
                step_next = STEP_SET_DONE;
            end
            STEP_SET_DONE: begin
                write_addr = CSR_DDRCTRL_INIT_DONE_WORD;
                write_data = 32'h0000_0001;
                step_next = STEP_DONE;
            end
            default: begin
                step_next = STEP_DONE;
            end
        endcase
    end

    assign wb_adr = write_addr;
    assign wb_dat_w = write_data;
    assign wb_sel = 4'hf;
    assign wb_cyc = (phase_q == PHASE_WRITE) && (step_q != STEP_DONE);
    assign wb_stb = wb_cyc;
    assign wb_we = wb_cyc;
    assign wb_cti = 3'b000;
    assign wb_bte = 2'b00;

    always_ff @(posedge clk) begin
        if (reset) begin
            step_q <= STEP_CLEAR_DONE;
            phase_q <= PHASE_WRITE;
            delay_count_q <= '0;
            done <= 1'b0;
        end else begin
            case (phase_q)
                PHASE_WRITE: begin
                    if (wb_ack) begin
                        step_q <= step_next;
                        if (step_next == STEP_DONE) begin
                            done <= 1'b1;
                            phase_q <= PHASE_DONE;
                        end else if (delay_after_write != '0) begin
                            delay_count_q <= delay_after_write;
                            phase_q <= PHASE_DELAY;
                        end else begin
                            phase_q <= PHASE_GAP;
                        end
                    end
                end
                PHASE_DELAY: begin
                    if (delay_count_q <= WAIT_COUNT_BITS'(1)) begin
                        delay_count_q <= '0;
                        phase_q <= PHASE_GAP;
                    end else begin
                        delay_count_q <= delay_count_q - WAIT_COUNT_BITS'(1);
                    end
                end
                PHASE_GAP: begin
                    phase_q <= PHASE_WRITE;
                end
                default: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

    wire _unused_ok_wb_dat_r = &{1'b0, wb_dat_r, 1'b0};
endmodule
