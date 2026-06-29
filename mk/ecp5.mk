# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

route: $(ARTIFACT_DIR)/ulx3s_out.config ## Run nextpnr place and route
$(ARTIFACT_DIR)/ulx3s_out.config: $(ARTIFACT_DIR)/mydesign.json | $(ARTIFACT_DIR)
	$(TOOLPATH)/nextpnr-ecp5 --85k --json $< \
		--lpf $(LPF) \
		--log $(ARTIFACT_DIR)/nextpnr.log \
		--package CABGA381 \
		--randomize-seed \
		--speed 8 \
		--report $(ARTIFACT_DIR)/nextpnr-report.json \
		--placer-heap-critexp 3 --placer-heap-timingweight 20 \
		--detailed-timing-report \
		--textcfg $@
	python3 -m json.tool $(ARTIFACT_DIR)/nextpnr-report.json > $(ARTIFACT_DIR)/nextpnr-report.pretty.json
pack: $(ARTIFACT_DIR)/ulx3s.bit | $(ARTIFACT_DIR) ## Pack routed design into bitstream
$(ARTIFACT_DIR)/ulx3s.bit: $(ARTIFACT_DIR)/ulx3s_out.config | $(ARTIFACT_DIR)
	$(TOOLPATH)/ecppack $< $@

memprog: $(ARTIFACT_DIR)/ulx3s.bit ## Program bitstream to FPGA SRAM
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
