# This library script is meant to be sourced

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $script_dir/_utils.sh
source $script_dir/_env_vars_file.sh

# Function to display usage information
_build_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --release               Build Release"
  echo "  --debug                 Build Debug"
  echo "  --profile <native|wasm> Build to a specific architecture"
  echo "  --clean                 Clean the build folder"
  exit 0
}

# Function to parse command-line arguments and export environment variables
_parse_command_line() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -h | --help)
      _build_usage
      ;;
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
    --clean)
      clean=true
      ;;
    --*=*)
      # Handle arbitrary --option=value
      option="${1%%=*}"     # Extract option name
      value="${1#*=}"       # Extract value
      varname="${option:2}" # Strip leading --
      export "$varname=$value"
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
      export "$varname=$1"
      ;;
    *)
      echo "Error: Invalid argument $1"
      exit 1
      ;;
    esac
    shift
  done
}

function _create_env_vars_file() {
  # env vars
  # default values --> read from .env file --> take from command line
  local build_type=Debug
  local profile=native
  source $script_dir/_env_vars_file.sh
  local stored_profile=$profile
  _parse_command_line "$@"

  # if the profile has changed, we need a clean build
  if [[ -n "$stored_profile" && "$stored_profile" != "$profile" ]]; then
    echo -e "${green}Profile changed, will do a clean build${no_color}"
    clean=true
  fi

  # set the cli name and driver based on the profile
  if [[ "$profile" == "wasm" ]]; then
    local cli_name="starterkit.js"
    local driver=node
  else
    local cli_name="starterkit"
    local driver=
  fi

  local build_folder=$root_dir/build/$build_type
  local cli_path="$build_folder/cli/$cli_name"

  # make the env vars persistent, so next time, we won't need to pass the command line flags
  for var in build_type profile build_folder cli_name cli_path driver; do
    update_env_vars_file $root_dir/.env $var ${!var}
  done
}

# start
ensure_sourced

activate_venv || return $?
_create_env_vars_file "$@"
load_env_vars
