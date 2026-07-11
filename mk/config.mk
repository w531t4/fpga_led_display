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
# CLK_110 - Use 110Mhz clock for clk_root
# CLK_100 - Use 100MHz clock for clk_root
# CLK_90 - Use 90MHz clock for clk_root
# CLK_80 - Use 90MHz clock for clk_root
# CLK_50 - Use 50MHz clock for clk_root
# RGB24 - Use RGB24 instead of RGB565
# GAMMA - Enable Gamma Correction
# DOUBLE_BUFFER - Allow image to be written to one buffer while displaying the other buffer at led's.
# USE_INFER_BRAM_PLUGIN - Compile and use Yosys plugin to assist with inferring OUTREG for BRAM's
# USE_WATCHDOG - Requires recurring command sequence to be present, otherwise board resets
# SWAP_BLUE_GREEN_CHAN - Swaps the pins for blue/green channels (see Adafruit note about "...green and blue channels are swapped..
#				         .with the 2.5mm pitch 64x32 display..." https://www.adafruit.com/product/5036)
# USE_PASSTHRU - Connects passthru pins which allows flashing the ESP32 from the same USB port as the FPGA
# USE_STATUS_SPI - READSTATUS command + host-clocked CS-framed register read port (see PLAN.md)

BUILD_FLAGS ?=-DGAMMA -DCLK_90 -DW128 -DRGB24 -DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN -DSWAP_BLUE_GREEN_CHAN -DUSE_PASSTHRU -DUSE_STATUS_SPI
SIM_FLAGS:=-DSIM $(BUILD_FLAGS)

# == BOARD SELECTION ==
# Each board has a thin top wrapper (src/top_<board>.sv) whose ports match its
# constraint file. The board-agnostic logic lives in display_core (src/main.sv).
# Switch boards with e.g. `make BOARD=ulx3s pack`. Default is panelith.
BOARD ?= panelith
ifeq ($(BOARD),panelith)
  TOP := top_panelith
  LPF := $(CONSTRAINTS_DIR)/panelith_v1.0.17.lpf
else ifeq ($(BOARD),ulx3s)
  TOP := top_ulx3s
  LPF := $(CONSTRAINTS_DIR)/ulx3s_v316.lpf
else
  $(error Unknown BOARD '$(BOARD)' -- use 'panelith' or 'ulx3s')
endif
TOOLPATH:=oss-cad-suite/bin
NETLISTSVG:=depends/netlistsvg/node_modules/netlistsvg/bin/netlistsvg.js
