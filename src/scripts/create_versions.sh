#!/bin/bash
# SPDX-FileCopyrightText: 2025 Aaron White <w531t4@gmail.com>
# SPDX-License-Identifier: MIT
# This routine helped when troubleshooting why the presence of the debugger caused chaos (in conjunction with git bisect).
make clean
rm -rf build_good
make BUILD_FLAGS= && make pack BUILD_FLAGS=
mv build build_good
make BUILD_FLAGS=-DDEBUGGER && make pack BUILD_FLAGS=-DDEBUGGER
