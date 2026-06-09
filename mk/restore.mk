# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

restore: restore-build ## Build and program passthru bitstream
	$(TOOLPATH)/fujprog $(ARTIFACT_DIR)/passthru/ulx3s_passthru_wifi.bit

restore-build: ## Build passthru bitstream
	$(MAKE) -f $(SRC_DIR)/passthru/Makefile all
