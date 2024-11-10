#!/bin/bash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(realpath "$script_dir/..")

# function to check if the script is sourced
ensure_sourced() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Please run: source ${BASH_SOURCE[0]}"
    exit 1
  fi
}

# Function to add or replace a key=value pair in an .env file
update_env_file() {
  local file=$1
  local key=$2
  local value=$3

  # Check if key already exists in the file
  if grep -q "^$key=" "$file" >/dev/null 2>&1; then
    # If key exists, replace the value
    sed -i "s/^$key=.*/$key=$value/" "$file"
  else
    # If key does not exist, add it to the end of the file
    echo "$key=$value" >>"$file"
  fi
}

# start
ensure_sourced

# activate python's virtual env
source $root_dir/activate.sh --quiet
# determent build type: debug/release
build_type=Debug                         # default
source $root_dir/.env >/dev/null 2>&1 || true # read build_type env var
# apply command line params
if [ "$1" == '--debug' ]; then build_type=Debug; fi
if [ "$1" == '--release' ]; then build_type=Release; fi
# make the build_type persistent, so next time, we won't need to pass --release/--debug
update_env_file $root_dir/.env build_type $build_type
# check if we already build once, and get the build folder (for cmake --build)
build_folder=$root_dir/build/$build_type

