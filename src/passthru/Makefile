# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

# Toolchain

# Directory containing this Makefile (absolute)
THIS_MK_DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# Paths
ROOT      := $(abspath $(THIS_MK_DIR)/../..)
OSS_CAD   := $(ROOT)/oss-cad-suite/bin
SRC_DIR   := $(ROOT)/src
BUILD_DIR := $(ROOT)/build/passthru

# Toolchain
YOSYS   := $(OSS_CAD)/yosys
NEXTPNR := $(OSS_CAD)/nextpnr-ecp5
ECPPACK := $(OSS_CAD)/ecppack

# Design
TOP := ulx3s_esp32_passthru
SRC := $(SRC_DIR)/passthru/$(TOP).sv

# Board
DEVICE  := --85k
PACKAGE := CABGA381
LPF     := $(SRC_DIR)/constraints/ulx3s_v316.lpf
FREQ    := 25

# Outputs
JSON   := $(BUILD_DIR)/ulx3s_esp32_passthru.json
CONFIG := $(BUILD_DIR)/ulx3s_esp32_passthru.config
BIT    := $(BUILD_DIR)/ulx3s_esp32_passthru.bit

.PHONY: all clean dirs

all: $(BIT)

dirs:
	mkdir -p $(BUILD_DIR)

$(JSON): $(SRC) | dirs
	$(YOSYS) -p "read_verilog $(SRC); synth_ecp5 -top $(TOP) -json $(JSON);"

$(CONFIG): $(JSON) $(LPF)
	$(NEXTPNR) $(DEVICE) --package $(PACKAGE) \
		--json $(JSON) \
		--lpf $(LPF) \
		--textcfg $(CONFIG) \
		--freq $(FREQ)

$(BIT): $(CONFIG)
	$(ECPPACK) --compress $(CONFIG) $(BIT)

clean:
	rm -rf $(BUILD_DIR)
