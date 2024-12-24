#!/bin/bash

source ./env/env_vars.sh
if [[ "$profile" == "emscripten" ]]; then driver=node; fi

exec $driver "$build_folder/cli/starterkit" "$@"
