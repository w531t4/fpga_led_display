# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

gamma_lut: $(GAMMA_INCLUDES)

$(VINCLUDE_DIR)/memory/%.svh: $(VINCLUDE_DIR)/memory/%.mem $(SRC_DIR)/scripts/gen_gamma_svh.py
	python3 $(SRC_DIR)/scripts/gen_gamma_svh.py "$<" "$@"
