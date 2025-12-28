# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
TOPLEVEL_LANG = verilog
SIM ?= icarus

COCOTB_TOPLEVEL ?= control_module
COCOTB_TEST_MODULES ?= test_control_module
SIM_BUILD ?= sim_build/$(COCOTB_TOPLEVEL)

ROOT_DIR := $(abspath $(CURDIR)/../..)
SRC_DIR := $(ROOT_DIR)/src
TEST_RTL_DIR := $(ROOT_DIR)/tests/cocotb/rtl
ICARUS_BIN_DIR ?= $(ROOT_DIR)/oss-cad-suite/libexec
PYTHON_BIN ?= python3
BUILD_FLAGS ?= -DSPI -DGAMMA -DCLK_90 -DW128 -DRGB24 -DSPI_ESP32 -DDOUBLE_BUFFER -DUSE_WATCHDOG -DUSE_INFER_BRAM_PLUGIN
export BUILD_FLAGS
export PYTHONPATH := $(ROOT_DIR)/tests/cocotb:$(PYTHONPATH)

VERILOG_SOURCES := $(SRC_DIR)/params_pkg.sv \
	$(filter-out $(SRC_DIR)/params_pkg.sv,$(shell find $(SRC_DIR) -type f \( -name '*.sv' -o -name '*.v' \) | grep -v '/testbenches/' | sort))
VERILOG_SOURCES += $(shell [ -d "$(TEST_RTL_DIR)" ] && find "$(TEST_RTL_DIR)" -type f -name '*.sv' | sort)

COMPILE_ARGS += -g2012 -I$(SRC_DIR)/include -DSIM $(BUILD_FLAGS)
COMPILE_ARGS += -p VVP_EXECUTABLE=$(ICARUS_BIN_DIR)/vvp
COMPILE_ARGS += -y $(SRC_DIR) -Y .sv -Y .v

include $(shell cocotb-config --makefiles)/Makefile.sim
