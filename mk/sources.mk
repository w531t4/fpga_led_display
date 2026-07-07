# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

# PKG_SOURCES are listed manually because their compilation order matters
PKG_SOURCES := $(PKG_DIR)/params.sv $(PKG_DIR)/calc.sv $(PKG_DIR)/cmd.sv $(PKG_DIR)/types.sv $(PKG_DIR)/enums.sv
INTERFACE_SOURCES := $(sort $(shell find $(INTERFACE_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
PROJROOT_VSOURCES := $(sort $(shell find $(SRC_DIR) -maxdepth 1 -name '*.sv' -or -name '*.v'))
VSOURCES := $(PKG_SOURCES) $(INTERFACE_SOURCES) $(PROJROOT_VSOURCES)
# The ESP32-flashing passthrough submodule lives under src/passthru/ (it doubles as
# the standalone restore-flash top), so it's outside the depth-1 glob above. Pull it
# into the main build only when USE_PASSTHRU is set (matches main.sv's instantiation).
ifeq ($(findstring -DUSE_PASSTHRU,$(BUILD_FLAGS)), -DUSE_PASSTHRU)
VSOURCES += $(SRC_DIR)/passthru/ulx3s_v20_passthru_wifi_modified.v
endif
TBSRCS := $(sort $(shell find $(TB_DIR) -name '*.sv' -or -name '*.v'))
GAMMA_MEMS := $(sort $(shell find $(VINCLUDE_MEM_DIR) -maxdepth 1 -name '*.mem'))
GAMMA_INCLUDES := $(patsubst $(VINCLUDE_MEM_DIR)/%.mem,$(VINCLUDE_MEM_DIR)/%.svh,$(GAMMA_MEMS))
INCLUDESRCS := $(sort $(shell find $(VINCLUDE_DIR) -maxdepth 1 -name '*.vh' -or -name '*.svh')) $(GAMMA_INCLUDES)
SIMBINS:=$(subst tb_,, $(subst $(TB_DIR), $(SIM_BIN_DIR), $(TBSRCS:%.sv=%)))
FSTOBJS:=$(subst tb_,, $(subst $(TB_DIR), $(SIMULATION_DIR), $(TBSRCS:%.sv=%.fst)))
TB_ARGS_FILES := $(wildcard $(TB_DIR)/tb_*.args)

ifneq ($(findstring -DUSE_WATCHDOG,$(BUILD_FLAGS)), -DUSE_WATCHDOG)
VSOURCES := $(filter-out $(SRC_DIR)/control_cmd_watchdog.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_control_cmd_watchdog.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/control_cmd_watchdog, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/control_cmd_watchdog.fst, $(FSTOBJS))
endif

ifneq ($(findstring -DUSE_FM6126A,$(BUILD_FLAGS)), -DUSE_FM6126A)
VSOURCES := $(filter-out $(SRC_DIR)/fm6126init.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_fm6126init.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/fm6126init, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/fm6126init.fst, $(FSTOBJS))
endif

ifneq ($(findstring -DDEBUGGER,$(BUILD_FLAGS)), -DDEBUGGER)
VSOURCES := $(filter-out $(SRC_DIR)/debugger.sv, $(VSOURCES))
TBSRCS := $(filter-out $(TB_DIR)/tb_debugger.sv, $(TBSRCS))
SIMBINS := $(filter-out $(SIM_BIN_DIR)/debugger, $(SIMBINS))
FSTOBJS := $(filter-out $(SIMULATION_DIR)/debugger.fst, $(FSTOBJS))
endif
