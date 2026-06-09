# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

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
