# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

MAKE_DEPS := Makefile $(wildcard mk/*.mk)

include mk/config.mk

# Ensure depfile includes don't override the default goal.
.DEFAULT_GOAL := all

include mk/sources.mk

include mk/verilator.mk



.PHONY: all diagram simulation clean compile loopviz route lint loopviz_pre ilang pack restore restore-build verilator_argfiles
.DELETE_ON_ERROR:
.SECONDARY: $(SIMBINS)
all: verilator_argfiles simulation lint
#$(warning In a command script $(SIMBINS))


$(ARTIFACT_DIR):
	mkdir -p $(ARTIFACT_DIR)
	mkdir -p $(INTERFACE_DIR)

$(SIMULATION_DIR):
	mkdir -p $(SIMULATION_DIR)

$(SIM_BIN_DIR):
	mkdir -p $(SIM_BIN_DIR)

$(SIM_OBJ_DIR):
	mkdir -p $(SIM_OBJ_DIR)

$(DEPDIR):
	mkdir -p $(DEPDIR)

clean:
	rm -rf $(ARTIFACT_DIR)
ifneq ($(findstring -DUSE_INFER_BRAM_PLUGIN,$(BUILD_FLAGS)),)
	YOSYS_PATH=$(abspath oss-cad-suite) $(MAKE) -C depends/yosys_ecp5_infer_bram_outreg clean
endif

include mk/yosys.mk


loopviz: $(ARTIFACT_DIR)/mydesign_show.svg
$(ARTIFACT_DIR)/mydesign_show.svg: $(ARTIFACT_DIR)/mydesign_show.dot | $(ARTIFACT_DIR)
	$(TOOLPATH)/dot -Kdot -o $@ -Tsvg $<

loopviz_pre: $(ARTIFACT_DIR)/mydesign_show_pre.svg
$(ARTIFACT_DIR)/mydesign_show_pre.svg: $(ARTIFACT_DIR)/mydesign_show_pre.dot | $(ARTIFACT_DIR)
	$(TOOLPATH)/dot -Kdot -o $@ -Tsvg $<

route: $(ARTIFACT_DIR)/ulx3s_out.config
$(ARTIFACT_DIR)/ulx3s_out.config: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	$(TOOLPATH)/nextpnr-ecp5 --85k --json $< \
		--lpf $(CONSTRAINTS_DIR)/ulx3s_v316.lpf \
		--log $(ARTIFACT_DIR)/nextpnr.log \
		--package CABGA381 \
		--randomize-seed \
		--report $(ARTIFACT_DIR)/nextpnr-report.json \
		--placer-heap-critexp 3 --placer-heap-timingweight 20 \
		--detailed-timing-report \
		--textcfg $@
	python3 -m json.tool $(ARTIFACT_DIR)/nextpnr-report.json > $(ARTIFACT_DIR)/nextpnr-report.pretty.json
pack: $(ARTIFACT_DIR)/ulx3s.bit | $(ARTIFACT_DIR)
$(ARTIFACT_DIR)/ulx3s.bit: $(ARTIFACT_DIR)/ulx3s_out.config | $(ARTIFACT_DIR)
	$(TOOLPATH)/ecppack $< $@

memprog: $(ARTIFACT_DIR)/ulx3s.bit
	@echo ====YOSYS WARNINGS/ERRORS==== | tee $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i -e warning -e error $(ARTIFACT_DIR)/yosys.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====YOSYS Removed Unused Modules==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep "Removing unused module" $(ARTIFACT_DIR)/yosys.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====NEXTPNR WARNINGS/ERRORS==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i -e warning -e error $(ARTIFACT_DIR)/nextpnr.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo ====CLOCKS==== | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@-grep -i "Info: Max frequency for clock" $(ARTIFACT_DIR)/nextpnr.log | tee -a $(ARTIFACT_DIR)/look_at_me.txt
	@echo | tee -a $(ARTIFACT_DIR)/look_at_me.txt


	$(TOOLPATH)/fujprog $<

$(ARTIFACT_DIR)/mydesign_vizclean.json: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@

$(ARTIFACT_DIR)/netlist.svg: $(ARTIFACT_DIR)/mydesign_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@

ifeq ($(YOSYS_INCLUDE_EXTRA),true)
$(ARTIFACT_DIR)/mydesign_pre_vizclean.json: $(ARTIFACT_DIR)/mydesign_pre.json | $(ARTIFACT_DIR)
	jq 'del(.modules.BB, .modules.BBPU, .modules.BBPD, .modules.TRELLIS_IO)' $< > $@

$(ARTIFACT_DIR)/netlist_pre.svg: $(ARTIFACT_DIR)/mydesign_pre_vizclean.json | $(ARTIFACT_DIR)
	$(NETLISTSVG) $< -o $@
endif

DIAGRAM_TARGETS:=$(ARTIFACT_DIR)/netlist.svg
DIAGRAM_TARGETS += $(if $(filter true,$(YOSYS_INCLUDE_EXTRA)),$(ARTIFACT_DIR)/netlist_pre.svg)

diagram: $(DIAGRAM_TARGETS)

restore: restore-build
	$(TOOLPATH)/fujprog $(ARTIFACT_DIR)/passthru/ulx3s_passthru_wifi.bit

restore-build:
	$(MAKE) -f $(SRC_DIR)/passthru/Makefile all

gamma_lut: $(GAMMA_INCLUDES)

$(VINCLUDE_DIR)/memory/%.svh: $(VINCLUDE_DIR)/memory/%.mem $(SRC_DIR)/scripts/gen_gamma_svh.py
	python3 $(SRC_DIR)/scripts/gen_gamma_svh.py "$<" "$@"
