# SPDX-FileCopyrightText: 2026 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

# Version -D flags from the semantic-release git tag, recomputed each make (no file)
# and injected only into synthesis (mk/yosys.mk); reg_version.sv packs them into
# READSTATUS. See gen_version_defines.sh for the field encoding.
VERSION_GEN     := $(SRC_DIR)/scripts/gen_version_defines.sh
VERSION_DEFINES := $(shell $(VERSION_GEN))

version: ## Print the git-derived version -D flags for this build
	@printf '%s\n' $(VERSION_DEFINES)
.PHONY: version
