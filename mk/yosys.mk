# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

# This plugin is necessary to infer OUTREG in blockram correctly in yosys.
depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so:
	YOSYS_PATH=$(abspath oss-cad-suite) $(MAKE) -C depends/yosys_ecp5_infer_bram_outreg

YOSYS_DEBUG ?= false
YOSYS_INCLUDE_EXTRA ?= false

YOSYS_TARGETS:=$(ARTIFACT_DIR)/mydesign.json \
			   $(ARTIFACT_DIR)/mydesign.il
YOSYS_EXTRA:=hierarchy -check -top $(TOP);
ifeq ($(YOSYS_INCLUDE_EXTRA),true)
	YOSYS_EXTRA += ls;
	YOSYS_EXTRA += proc -noopt;
	YOSYS_EXTRA += write_rtlil $(ARTIFACT_DIR)/mydesign_pre.il;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/mydesign_pre.il
	YOSYS_EXTRA += write_json $(ARTIFACT_DIR)/mydesign_pre.json;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/mydesign_pre.json
	YOSYS_EXTRA += write_verilog $(ARTIFACT_DIR)/code_preopt.sv;
	YOSYS_TARGETS +=  $(ARTIFACT_DIR)/code_preopt.sv
	YOSYS_EXTRA += write_verilog -selected $(ARTIFACT_DIR)/code_preopt_selected.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_preopt_selected.sv
	YOSYS_EXTRA += opt_expr -full;
	YOSYS_EXTRA += write_verilog $(ARTIFACT_DIR)/code_postopt.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_postopt.sv
	YOSYS_EXTRA += write_verilog -selected $(ARTIFACT_DIR)/code_postopt_selected.sv;
	YOSYS_TARGETS += $(ARTIFACT_DIR)/code_postopt_selected.sv
endif

YOSYS_READSLANG_ARGS:=$(BUILD_FLAGS) -I$(VINCLUDE_DIR) -I$(VINCLUDE_MEM_DIR) ${VSOURCES}
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_READSLANG_ARGS:=--diag-source --diag-location --diag-include-stack $(YOSYS_READSLANG_ARGS)
endif
YOSYS_READSLANG_CMD:=read_slang $(YOSYS_READSLANG_ARGS)

YOSYS_SYNTHECP5_CMD:=synth_ecp5 -top $(TOP)

YOSYS_SCRIPT:=
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_SCRIPT +=echo on;
endif
YOSYS_SCRIPT +=$(YOSYS_READSLANG_CMD);
YOSYS_SCRIPT +=$(YOSYS_EXTRA);
YOSYS_SCRIPT +=$(YOSYS_SYNTHECP5_CMD);
ifeq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)), -DUSE_INFER_BRAM_PLUGIN)
	# YOSYS_SCRIPT +=write_verilog -noattr -noexpr $(ARTIFACT_DIR)/code_preblah.sv;
	YOSYS_SCRIPT +=ecp5_infer_bram_outreg;
	# YOSYS_SCRIPT +=write_verilog -noattr -noexpr $(ARTIFACT_DIR)/code_postblah.sv;
endif
# Write JSON after optional BRAM outreg packing so nextpnr sees OUTREG.
YOSYS_SCRIPT +=write_json $(ARTIFACT_DIR)/mydesign.json;
YOSYS_SCRIPT +=write_rtlil $(ARTIFACT_DIR)/mydesign.il;
YOSYS_SCRIPT +=write_verilog -selected $(ARTIFACT_DIR)/mydesign_final.sv;

YOSYS_CMD_ARGS:=-L $(ARTIFACT_DIR)/yosys.log -p "$(YOSYS_SCRIPT)"
YOSYS_CMD_ARGS += -m slang
ifeq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)), -DUSE_INFER_BRAM_PLUGIN)
YOSYS_CMD_ARGS += -m depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so
endif
ifeq ($(YOSYS_DEBUG), true)
	YOSYS_CMD_ARGS :=-d -v9 -g $(YOSYS_CMD_ARGS)
endif

YOSYS_HIER_SCRIPT:=read_slang --best-effort-hierarchy $(YOSYS_READSLANG_ARGS);
YOSYS_HIER_SCRIPT +=hierarchy -check -top $(TOP);
YOSYS_HIER_SCRIPT +=write_json $(ARTIFACT_DIR)/mydesign_hier.json;

$(ARTIFACT_DIR)/mydesign_hier.json: $(VSOURCES) $(INCLUDESRCS) $(MAKE_DEPS) | $(ARTIFACT_DIR)
	$(TOOLPATH)/yosys -q -L $(ARTIFACT_DIR)/yosys_hier.log -p "$(YOSYS_HIER_SCRIPT)" -m slang

compile: lint gamma_lut $(ARTIFACT_DIR)/mydesign.json ## Run lint and synthesize the design
$(YOSYS_TARGETS): ${VSOURCES} $(INCLUDESRCS) $(MAKE_DEPS)  $(if $(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)),depends/yosys_ecp5_infer_bram_outreg/ecp5_infer_bram_outreg.so) | $(ARTIFACT_DIR)
	echo "$(YOSYS_SCRIPT)" > $(ARTIFACT_DIR)/mydesign.ys
	$(TOOLPATH)/yosys $(YOSYS_CMD_ARGS)
