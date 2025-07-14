#!/bin/bash
make clean
rm -rf build_good
make BUILD_FLAGS= && make pack BUILD_FLAGS=
mv build build_good
make BUILD_FLAGS=-DDEBUGGER && make pack BUILD_FLAGS=-DDEBUGGER
