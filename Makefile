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


include mk/housekeeping.mk


include mk/yosys.mk


include mk/diagram.mk


include mk/ecp5.mk



include mk/restore.mk


include mk/gamma.mk

