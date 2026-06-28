// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`timescale 1ns / 1ns
`default_nettype none
// =============================================================================
// tb_f4_row_probe -- proves the F4 hardware probe samples the displayed-data
// stream and serializes the right ASCII line before we flash it. Drives a full
// PROBE_ROW scan with a known read_data_out ramp, decodes the UART line bit-by-bit,
// and checks the strided samples come out as expected hex.
// =============================================================================
module tb_f4_row_probe #(
    // verilator lint_off UNUSEDPARAM
    parameter integer unsigned _UNUSED = 0
    // verilator lint_on UNUSEDPARAM
);
    localparam integer unsigned TPB     = 16;
    localparam integer unsigned PROW    = 2;
    localparam integer unsigned NSAMP   = 8;
    localparam integer unsigned STRIDE  = params::PIXEL_WIDTH / NSAMP;

    logic clk = 1'b0;
    logic reset = 1'b1;
    types::row_subpanel_addr_t row_address = '0;
    logic read_valid = 1'b0;
    types::mem_read_data_t read_data_out = '0;
    logic frame_select = 1'b0;
    wire  tx;

    always #5 clk = ~clk;

    f4_row_probe #(.UART_TICKS_PER_BIT(TPB), .PROBE_ROW(PROW), .NUM_SAMPLES(NSAMP), .THROTTLE(1),
                   .SWEEP(1'b0))
        dut (.clk(clk), .reset(reset), .row_address(row_address), .read_valid(read_valid),
             .read_data_out(read_data_out), .frame_select(frame_select), .tx(tx));

    // hex pair -> byte
    function automatic logic [3:0] unhex(input logic [7:0] c);
        unhex = (c >= "0" && c <= "9") ? 4'(c - "0") : 4'(c - "A" + 8'd10);
    endfunction

    task automatic get_byte(output logic [7:0] b);
        int i;
        begin
            @(negedge tx);
            repeat (TPB + TPB/2) @(posedge clk);
            for (i = 0; i < 8; i++) begin b[i] = tx; repeat (TPB) @(posedge clk); end
        end
    endtask

    logic [7:0] line [0:3 + NSAMP*2];   // row(2 hex) + frame char(1) + hex samples + newline
    int errors = 0;

    function automatic logic [7:0] hexd(input logic [3:0] n);
        hexd = (n < 4'd10) ? (8'h30 + {4'd0, n}) : (8'h41 + ({4'd0, n} - 8'd10));
    endfunction

    initial begin
        repeat (4) @(posedge clk);
        reset = 1'b0;
        repeat (4) @(posedge clk);

        // enter PROBE_ROW, settle the row-entry (read_valid low) so capture starts clean
        @(negedge clk);
        row_address = types::row_subpanel_addr_t'(PROW);
        read_valid = 1'b0;
        repeat (4) @(negedge clk);
        // scan the row with a known ramp on read_data_out (raw[7:0] = read index)
        for (int unsigned r = 0; r < params::PIXEL_WIDTH; r++) begin
            read_data_out = types::mem_read_data_t'(r);
            read_valid = 1'b1;
            @(negedge clk);
        end
        read_valid = 1'b0;
        @(negedge clk);
        row_address = '0;                 // leave the row -> triggers the line send

        // decode the emitted line: row(2 hex), frame char, NSAMP hex bytes, '\n'
        for (int unsigned c = 0; c < 4 + NSAMP*2; c++) get_byte(line[c]);

        $write("  decoded line: \"");
        for (int unsigned c = 0; c < 3 + NSAMP*2; c++) $write("%c", line[c]);
        $display("\"");

        // well-formed line: row prefix == PROW, frame char '0', trailing newline
        if (line[0] !== "0" || line[1] !== "2") begin errors++; $display("  row prefix wrong: %c%c", line[0], line[1]); end
        if (line[2] !== "0") begin errors++; $display("  frame char wrong: %02h", line[2]); end
        if (line[3 + NSAMP*2] !== 8'h0A) begin errors++; $display("  missing newline"); end
        // the probe samples read_data_out at fixed STRIDE -> the bytes must form a
        // step-STRIDE ramp (mod 256), regardless of the exact start column.
        for (int unsigned k = 1; k < NSAMP; k++) begin
            logic [7:0] bcur, bprev;
            bcur  = {unhex(line[3 + k*2]),     unhex(line[3 + k*2 + 1])};
            bprev = {unhex(line[3 + (k-1)*2]), unhex(line[3 + (k-1)*2 + 1])};
            if (8'(bcur - bprev) !== 8'(STRIDE)) begin
                errors++;
                $display("  sample %0d step != STRIDE: %02h - %02h = %02h (exp %02h)",
                         k, bcur, bprev, 8'(bcur - bprev), 8'(STRIDE));
            end
        end

        if (errors == 0) $display("tb_f4_row_probe: PASS");
        else $error("tb_f4_row_probe: FAIL (%0d errors)", errors);
        $finish;
    end

    initial begin #5_000_000; $error("tb_f4_row_probe: TIMEOUT"); $finish; end
endmodule
