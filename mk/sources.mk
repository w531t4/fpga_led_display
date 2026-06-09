# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

# PKG_SOURCES are listed manually because their compilation order matters
PKG_SOURCES := $(PKG_DIR)/params.sv $(PKG_DIR)/calc.sv $(PKG_DIR)/cmd.sv $(PKG_DIR)/types.sv $(PKG_DIR)/enums.sv
INTERFACE_SOURCES := $(sort $(shell find $(INTERFACE_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
PROJROOT_VSOURCES := $(sort $(shell find $(SRC_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
VSOURCES := $(PKG_SOURCES) $(INTERFACE_SOURCES) $(PROJROOT_VSOURCES)
