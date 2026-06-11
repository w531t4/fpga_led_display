# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

ARTIFACT_DIR:=build
SIMULATION_DIR:=$(ARTIFACT_DIR)/simulation
SIM_BIN_DIR:=$(ARTIFACT_DIR)/verilator_bin
SIM_OBJ_DIR:=$(ARTIFACT_DIR)/verilator_obj
SIMULATION_DIR_ABS:=$(abspath $(SIMULATION_DIR))
SIM_BIN_DIR_ABS:=$(abspath $(SIM_BIN_DIR))
# Dependency files for per-testbench rebuilds.
DEPDIR:=$(ARTIFACT_DIR)/deps
SRC_DIR:=src
PKG_DIR:=$(SRC_DIR)/packages
INTERFACE_DIR:=$(SRC_DIR)/interfaces
TB_DIR:=$(SRC_DIR)/testbenches
CONSTRAINTS_DIR:=$(SRC_DIR)/constraints
VINCLUDE_DIR:=$(SRC_DIR)/include
VINCLUDE_MEM_DIR:=$(VINCLUDE_DIR)/memory
CCACHE_DIR ?= $(abspath .ccache)
export CCACHE_DIR

# == NOTE == CHANGING THESE PARAMS REQUIRES A `make clean` and subsequent `make`
# USE_FM6126A - enable behavior changes to acccomodate FM6126A (like multiple clk per latch, init, etc)
# SIM - disable use of PLL in simulations
# DEBUGGER - enable UART TX debugger (for use with src/scripts/uart_rx.py)
# W128 - enable 128 pixel width
# FOCUS_TB_MAIN_UART - limit main testbench to include only signals applicable to uart debugging
# SPI - use SPI for data ingress instead of a UART
# SPI_ESP32 - must also specify SPI. Uses esp32 pinout
# CLK_110 - Use 110Mhz clock for clk_root
# CLK_100 - Use 100MHz clock for clk_root
# CLK_90 - Use 90MHz clock for clk_root
# CLK_80 - Use 90MHz clock for clk_root
# CLK_50 - Use 50MHz clock for clk_root
# RGB24 - Use RGB24 instead of RGB565
# GAMMA - Enable Gamma Correction
# USE_BOARDLEDS_BRIGHTNESS - Use development board led's to show brightness levels
# DOUBLE_BUFFER - Allow image to be written to one buffer while displaying the other buffer at led's.
# USE_INFER_BRAM_PLUGIN - Compile and use Yosys plugin to assist with inferring OUTREG for BRAM's
# USE_WATCHDOG - Requires recurring command sequence to be present, otherwise board resets
# SWAP_BLUE_GREEN_CHAN - Swaps the pins for blue/green channels (see Adafruit note about "...green and blue channels are swapped..
#				         .with the 2.5mm pitch 64x32 display..." https://www.adafruit.com/product/5036)
# USE_PASSTHRU - Connects passthru pins which allows flashing the ESP32 from the same USB port as the FPGA
# USE_LITEDRAM - Instantiate generated LiteDRAM SDRAM core at top level; framebuffer traffic is not connected yet
# USE_LITEDRAM_BIST - With USE_LITEDRAM, run a tiny write/read hardware probe and show its status on led[4:0]
# USE_LITEDRAM_WRITE_MIRROR - With USE_LITEDRAM, mirror controller framebuffer writes into LiteDRAM

BUILD_FLAGS ?=-DSPI -DGAMMA -DCLK_90 -DW128 -DRGB24 -DSPI_ESP32 -DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN -DSWAP_BLUE_GREEN_CHAN -DUSE_PASSTHRU
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=depends/netlistsvg/node_modules/netlistsvg/bin/netlistsvg.js
