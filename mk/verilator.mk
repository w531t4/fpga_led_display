# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

VERILATOR_BIN:=$(TOOLPATH)/verilator
VERILATOR_SIM_OPTSLOW ?=
VERILATOR_SIM_OBJCACHE ?= ccache
VERILATOR_SIM_MAKEFLAGS :=
VERILATOR_SIM_MAKEFLAGS += $(if $(strip $(VERILATOR_SIM_OPTSLOW)),OPT_SLOW=$(VERILATOR_SIM_OPTSLOW))
VERILATOR_SIM_MAKEFLAGS += $(if $(strip $(VERILATOR_SIM_OBJCACHE)),OBJCACHE=$(VERILATOR_SIM_OBJCACHE))
VERILATOR_ADDITIONAL_ARGS:=-Wall -Wno-fatal -Wno-TIMESCALEMOD -Wno-MULTITOP --timing --quiet-stats

# VERILATOR_FILEPARAM_ARGS
#	- Contents written to $(ARTIFACT_DIR)/verilator_args
#	- full-paths are required by vscode. otherwise vscode assumes they are in /src
VERILATOR_FILEPARAM_ARGS = -I$(VINCLUDE_DIR) \
						   -I$(VINCLUDE_MEM_DIR) \
						   $(SIM_FLAGS) \
						   $(VERILATOR_ADDITIONAL_ARGS)

VERILATOR_SIM_SRC_FILES:=-f $(ARTIFACT_DIR)/verilator_src_args

VERILATOR_SIMONLY_FLAGS:=--binary --trace-fst --trace-structs \
						 -j $(SIM_JOBS) \
					 	 -MAKEFLAGS "-j $(SIM_JOBS) $(VERILATOR_SIM_MAKEFLAGS)"
VERILATOR_LINTONLY_FLAGS:=--lint-only

# -- VERILATOR_SIM_FLAGS: Note: VERILATOR_SIM_SRC_FILES is specified later in the target below. TBSRCS aren't included
#								because the intent is to scope the lint to just that simulation.
VERILATOR_SIM_FLAGS:= $(VERILATOR_SIMONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -f $(ARTIFACT_DIR)/verilator_args

VERILATOR_LINT_FLAGS:=$(VERILATOR_LINTONLY_FLAGS) \
					  -sv \
					  --quiet \
					  -f $(ARTIFACT_DIR)/verilator_args \
					  -f $(ARTIFACT_DIR)/verilator_src_args \
					  -f $(ARTIFACT_DIR)/verilator_tbsrc_args


VERILATOR_SIM_CMD := $(VERILATOR_BIN) $(VERILATOR_SIM_FLAGS)
VERILATOR_LINT_CMD := $(VERILATOR_BIN) $(VERILATOR_LINT_FLAGS)
SIM_RUN_ARGS ?= +verilator+quiet
SIM_JOBS ?= $(shell nproc 2>/dev/null || getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
ifneq ($(filter --jobserver%,$(MAKEFLAGS)),)
SIM_MAKEFLAGS :=
else
SIM_MAKEFLAGS := -j $(SIM_JOBS)
endif
$(SIMULATION_DIR)/%.fst: $(SIM_BIN_DIR)/% $(MAKE_DEPS) | $(SIMULATION_DIR)
	@set -o pipefail; stdbuf -oL -eL $< $(SIM_RUN_ARGS) 2>&1 | sed -u 's/^/[$*] /'

$(SIM_BIN_DIR)/%: $(TB_DIR)/tb_%.sv $(VSOURCES) $(INCLUDESRCS) $(MAKE_DEPS) | $(SIM_BIN_DIR) $(SIM_OBJ_DIR)
	@tb_args_file=$(TB_DIR)/tb_$*.args; \
	tb_args=""; \
	if [ -f $$tb_args_file ]; then \
		tb_args="$$(tr '\n' ' ' < $$tb_args_file)"; \
	fi; \
	$(VERILATOR_SIM_CMD) $$tb_args \
		--top-module tb_$* \
		-Mdir $(SIM_OBJ_DIR)/obj_$* \
		-o $(SIM_BIN_DIR_ABS)/$* \
		-D'DUMP_FILE_NAME="$(SIMULATION_DIR_ABS)/$*.fst"' \
		$(VERILATOR_SIM_SRC_FILES) $<

verilator_argfiles: $(ARTIFACT_DIR)/verilator_args $(ARTIFACT_DIR)/verilator_src_args $(ARTIFACT_DIR)/verilator_tbsrc_args

$(ARTIFACT_DIR)/verilator_args: $(INCLUDESRCS) $(MAKE_DEPS) | $(ARTIFACT_DIR)
	@printf '%s' '$(VERILATOR_FILEPARAM_ARGS)' > $@

$(ARTIFACT_DIR)/verilator_src_args: $(ARTIFACT_DIR) $(VSOURCES) $(MAKE_DEPS) | $(ARTIFACT_DIR)
	@printf '%s' '$(abspath $(VSOURCES))' > $@

$(ARTIFACT_DIR)/verilator_tbsrc_args: $(ARTIFACT_DIR) $(TBSRCS) $(MAKE_DEPS) | $(ARTIFACT_DIR)
	@printf '%s' '$(abspath $(TBSRCS))' > $@

lint: $(ARTIFACT_DIR) verilator_argfiles
	cat $(ARTIFACT_DIR)/verilator_args; printf "\n";
	set -o pipefail; \
	{ \
		$(VERILATOR_LINT_CMD); \
		for tb_args_file in $(TB_ARGS_FILES); do \
			tb_args="$$(tr '\n' ' ' < $$tb_args_file)"; \
			$(VERILATOR_LINT_CMD) $$tb_args; \
		done; \
	} |& python3 $(SRC_DIR)/scripts/parse_lint.py | tee $(ARTIFACT_DIR)/verilator.lint

simulation: $(ARTIFACT_DIR) verilator_argfiles
	@# Capture simulation output so errors can be summarized at the end on failure.
	@set -o pipefail; \
	log="$(ARTIFACT_DIR)/simulation.log"; \
	$(MAKE) --no-print-directory $(SIM_MAKEFLAGS) $(FSTOBJS) 2>&1 | tee $$log; \
	status=$${PIPESTATUS[0]}; \
	if [ $$status -ne 0 ]; then \
		echo; \
		echo "==== SIMULATION ERRORS (summary) ===="; \
		grep -n -E "%Error|%Warning|^make(\\[[0-9]+\\])?: \\*\\*\\*" $$log || true; \
		exit $$status; \
	fi
