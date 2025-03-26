#!/bin/bash

# activate python's virtual env
. ./activate.sh --quiet

# Check if prefix parameter is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <install-prefix>"
    echo "Example: $0 /usr/local"
    exit 1
fi

# build the project
./build.sh
. .env >/dev/null 2>&1 || true

# Perform the installation
cmake --install "$build_folder" --prefix "$1" 