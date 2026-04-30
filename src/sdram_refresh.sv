// SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
`default_nettype none

module sdram_refresh (
    input  logic clk_in,
    input  logic reset,
    input  logic init_done,
    input  logic refresh_ack,
    output logic refresh_pending
);
    logic [calc::safe_clog2(params::SDRAM_REFRESH_INTERVAL_CYCLES + 1)-1:0] refresh_count;

    always_ff @(posedge clk_in) begin
        if (reset || !init_done) begin
            refresh_count <= '0;
            refresh_pending <= 1'b0;
        end else if (refresh_ack) begin
            refresh_count <= '0;
            refresh_pending <= 1'b0;
        end else if (!refresh_pending) begin
            if (refresh_count == $bits(refresh_count)'(params::SDRAM_REFRESH_INTERVAL_CYCLES - 1)) begin
                refresh_pending <= 1'b1;
            end else begin
                refresh_count <= refresh_count + 'd1;
            end
        end
    end
endmodule
