#!/bin/bash

# take the install prefix from the command line / env vars file
install_prefix=$1
source env/_env_vars_file.sh

# Check if prefix parameter is provided
if [ $# -ne 1 ] && [ "$install_prefix" = "" ]; then
  echo "Usage: $0 <install-prefix>"
  echo "Example: $0 /usr/local"
  exit 1
fi
update_env_vars_file $root_dir/.env install_prefix $install_prefix

# build the project
./build.sh
# update the env vars if changed
source _env_vars_file.sh

# activate python's virtual env
source ./activate.sh --quiet
cmake --install "$build_folder" --prefix "$install_prefix"
