# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT

PROJ:=this
SHELL:=/bin/bash

MAKE_DEPS := Makefile $(wildcard mk/*.mk)

include mk/config.mk

# Ensure depfile includes don't override the default goal.
.DEFAULT_GOAL := all

include mk/sources.mk

include mk/litedram.mk

include mk/verilator.mk



.PHONY: all diagram diagram_hier simulation clean compile route lint ilang pack restore restore-build verilator_argfiles memprog gamma_lut help
.DELETE_ON_ERROR:
.SECONDARY: $(SIMBINS)
all: verilator_argfiles simulation lint ## Run simulations and lint
help: ## Show documented make targets
	@awk 'BEGIN { FS = ":.*##"; printf "Targets:\n" } /^[A-Za-z0-9_.-]+:.*##/ { printf "  %-20s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

#$(warning In a command script $(SIMBINS))


include mk/housekeeping.mk


include mk/yosys.mk


include mk/diagram.mk


include mk/ecp5.mk



include mk/restore.mk


include mk/gamma.mk

