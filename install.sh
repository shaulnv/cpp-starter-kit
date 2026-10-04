#!/bin/bash

# `reset` is invalid without a controlling terminal
if [[ ${STARTERKIT_DEV_RESET_TERMINAL:-0} == "1" ]] && [[ -t 1 ]]; then reset; fi

source env/scripts/private/_env_vars_file.sh
# if we got an install prefix from the command line, use it
install_prefix=${1:-$install_prefix}
if [ -z "$install_prefix" ]; then
  echo "Usage: $0 <install-prefix>"
  echo "Example: $0 /usr/local"
  exit 1
fi
# remember the prefix in .env for the next run
update_env_vars_file "$root_dir/.env" install_prefix "$install_prefix"
./build.sh
# build.sh may have changed the build folder
load_env_vars
source ./activate.sh --quiet
cmake --install "$build_folder" --prefix "$install_prefix"
