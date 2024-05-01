#!/bin/bash

set -e # Errors are fatal

# Configure
conda/psi4-path-advisor.py cmake --objdir build --insist
cmake -S. -B build

# Build
cd build
cmake --build . -j4
