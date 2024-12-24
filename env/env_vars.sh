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

#!/bin/bash

# Function to display usage information
usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --release              Set build_type to Release"
  echo "  --debug                Set build_type to Debug"
  echo "  --profile <value>      Set profile to the specified value"
  exit 0
}

# Function to parse command-line arguments and export environment variables
parse_and_export() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --release)
      build_type=Release
      ;;
    --debug)
      build_type=Debug
      ;;
    --profile)
      shift
      if [[ -z "$1" || "$1" == --* ]]; then
        echo "Error: Missing value for --profile"
        exit 1
      fi
      profile="$1"
      ;;
    --*=*)
      # Handle arbitrary --option=value
      option="${1%%=*}"     # Extract option name
      value="${1#*=}"       # Extract value
      varname="${option:2}" # Strip leading --
      "$varname"="$value"
      ;;
    --*)
      # Handle arbitrary --option value
      option="$1"
      shift
      if [[ -z "$1" || "$1" == --* ]]; then
        echo "Error: Missing value for $option"
        exit 1
      fi
      varname="${option:2}" # Strip leading --
      "$varname"="$1"
      ;;
    -h | --help)
      usage
      ;;
    *)
      echo "Error: Invalid argument $1"
      exit 1
      ;;
    esac
    shift
  done
}

# start
ensure_sourced

# activate python's virtual env
source $root_dir/activate.sh --quiet
# env vars
# default values --> read from .env file --> take from command line 
build_type=Debug 
profile=cpp
source $root_dir/.env >/dev/null 2>&1 || true # read build_type env var
parse_and_export "$@"

# make the env vars persistent, so next time, we won't need to pass the command line flags
update_env_file $root_dir/.env build_type $build_type
update_env_file $root_dir/.env profile $profile

# build folder (for cmake --build)
build_folder=$root_dir/build/$build_type
