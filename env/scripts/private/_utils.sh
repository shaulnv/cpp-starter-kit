#!/bin/bash

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
root_dir=$(realpath "$script_dir/../../../")

green="\033[32m"
no_color="\033[0m"

# Function to check if the script is sourced
ensure_sourced() {
  if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Please run: source ${BASH_SOURCE[0]}"
    exit 1
  fi
}

# Function to activate python virtual environment
activate_venv() {
  source $root_dir/activate.sh --quiet
}

ensure_sourced
