// SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
// SPDX-License-Identifier: MIT
// SPI streamer helper for testbenches.
// - Mirrors tb_main's spi_master behavior (start held high, byte loaded on txdone).
// - Optionally includes spi_slave + ff_sync to generate data_ready_n/data_rx.
`ifndef TB_SPI_STREAMER_SVH
`define TB_SPI_STREAMER_SVH

module tb_spi_streamer #(
    // spi_master divider: 00=/4, 01=/8, 10=/16, 11=/32
    parameter logic [1:0] SPI_CDIV = 2'b0,
    // Total stream width in bits (must be a multiple of 8).
    parameter int unsigned DATA_BITS = 8,
    // When 1, instantiate spi_slave + ff_sync and drive data_rx/data_ready_n.
    parameter bit USE_SLAVE = 1'b0
) (
    input  logic clk,
    input  logic reset,
    input  logic start,
    input  logic ready_for_data,
    input  logic [DATA_BITS-1:0] data,
    output logic done,

    // SPI link signals (master outputs).
    output logic spi_clk_en,
    output logic spi_mosi,
    output logic spi_clk,
    output logic spi_cs,

    // Optional slave outputs (valid when USE_SLAVE=1).
    output logic [7:0] data_rx,
    output logic       data_ready_n
);
    localparam int unsigned DATA_BYTES = DATA_BITS / 8;

    logic [7:0] thebyte;
    int unsigned byte_idx;
    logic spi_start;
    wire spi_master_txdone;
    wire [7:0] _unused_ok_rdata;

    // Drive the spi_master exactly as tb_main does (start held high), but gate
    // the clock on ready_for_data: the master only advances bits while the FPGA
    // is ready for the next byte. Without this, the free-running master keeps
    // clocking when ready_for_data drops (e.g. SDRAM write backpressure) and
    // RE-TRANSMITS the current byte -- injecting duplicate bytes that desync the
    // command stream. Gating models the real host holding off SPI until ready.
    // (Under BRAM ready_for_data stays high, so behavior is unchanged.)
    spi_master #(
        ._UNUSED('d0)
    ) spimaster (
        .rstb (~reset),
        .clk  (clk && spi_clk_en && ready_for_data),
        .mlb  (1'b1),               // shift msb first
        .start(spi_start),
        .tdat (thebyte),
        .cdiv (SPI_CDIV),
        .din  (1'b0),
        .ss   (spi_cs),
        .sck  (spi_clk),
        .dout (spi_mosi),
        .done (spi_master_txdone),
        .rdata(_unused_ok_rdata)
    );

    // Latch start high once requested so spi_master keeps running, just like tb_main.
    always_ff @(posedge clk) begin
        if (reset) begin
            spi_start <= 1'b0;
        end else if (start) begin
            spi_start <= 1'b1;
        end else if ((byte_idx == DATA_BYTES) && !spi_clk_en) begin
            spi_start <= 1'b0;
        end
    end

    // Initialize the stream state once at time 0 (tb reset only occurs at startup).
    initial begin
        spi_clk_en = 1'b1;
        thebyte = 8'd0;
        byte_idx = 0;
    end

    // Advance the byte stream on the spi_master_txdone pulse (async to clk).
    // This matches tb_main's event-based update and avoids missing the done pulse.
    always @(posedge spi_master_txdone) begin
        if (ready_for_data) begin
            if (byte_idx < DATA_BYTES) begin
                thebyte <= data[DATA_BITS-1-(byte_idx*8)-:8];
                byte_idx <= byte_idx + 1;
            end else if (byte_idx == DATA_BYTES) begin
                spi_clk_en <= 1'b0;
            end
        end
    end

    assign done = (byte_idx == DATA_BYTES) && !spi_clk_en;

    // Optional SPI slave + sync path (mirrors main.sv).
    generate
        if (USE_SLAVE) begin : gen_slave
            wire       rxdata_ready;
            wire       rxdata_ready_level;
            wire       rxdata_ready_pulse;
            wire [7:0] rxdata_to_controller;
            wire       _unused_ok_sdout;

            spi_slave #(
                ._UNUSED('d0)
            ) spislave (
                .rstb ( ~reset),
                .ss   (spi_cs),
                .sck  (spi_clk),
                .sdin (spi_mosi),
                .ten  (1'b0),               // transmit disable
                .mlb  (1'b1),
                .tdata(8'b0),
                .sdout(_unused_ok_sdout),
                .done (rxdata_ready),
                .rdata(rxdata_to_controller)
            );

            ff_sync #(
                ._UNUSED('d0)
            ) rxdata_sync (
                .clk       (clk),
                .signal    (rxdata_ready),
                .sync_level(rxdata_ready_level),
                .sync_pulse(rxdata_ready_pulse),
                .reset     (reset)
            );

            assign data_rx = rxdata_to_controller;
            assign data_ready_n = ~rxdata_ready_pulse;

            // Silence unuseds that only exist for parity with main.sv.
            wire _unused_ok_slave = &{1'b0, rxdata_ready_level, _unused_ok_sdout, 1'b0};
        end else begin : gen_no_slave
            assign data_rx = 8'b0;
            assign data_ready_n = 1'b1;
        end
    endgenerate

    wire _unused_ok_master = &{1'b0, _unused_ok_rdata, 1'b0};
endmodule
`endif
