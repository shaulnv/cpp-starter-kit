# This library script is meant to be sourced

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
source $script_dir/_utils.sh
source $script_dir/_env_vars_file.sh

# Function to calculate next version from git tags
_calculate_next_version() {
  local calc_type=$1 # "semver-w" or "semver-z"

  # Get latest tag reachable from current branch
  local latest_tag=$(git describe --tags --match "v*" --abbrev=0 2>/dev/null || echo "v0.0.0")

  # Remove 'v' prefix
  local version_num="${latest_tag#v}"

  if [[ $calc_type == "semver-w" ]]; then
    # Check if version has 4 components (X.Y.Z.W)
    if [[ $version_num =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      # Has W component, increment it
      local x="${BASH_REMATCH[1]}"
      local y="${BASH_REMATCH[2]}"
      local z="${BASH_REMATCH[3]}"
      local w="${BASH_REMATCH[4]}"
      local new_w=$((w + 1))
      echo "$x.$y.$z.$new_w"
    elif [[ $version_num =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
      # Only X.Y.Z, add .1
      local x="${BASH_REMATCH[1]}"
      local y="${BASH_REMATCH[2]}"
      local z="${BASH_REMATCH[3]}"
      echo "$x.$y.$z.1"
    else
      echo "Error: Invalid tag format: $latest_tag" >&2
      return 1
    fi
  elif [[ $calc_type == "semver-z" ]]; then
    # Increment Z, ignore W
    if [[ $version_num =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(\.([0-9]+))?$ ]]; then
      local x="${BASH_REMATCH[1]}"
      local y="${BASH_REMATCH[2]}"
      local z="${BASH_REMATCH[3]}"
      local new_z=$((z + 1))
      echo "$x.$y.$new_z"
    else
      echo "Error: Invalid tag format: $latest_tag" >&2
      return 1
    fi
  fi
}

# Function to display usage information
_build_usage() {
  echo "Usage: $0 [OPTIONS]"
  echo "Options:"
  echo "  --state                 Print the build state (profile, build type, etc.) and exit"
  echo "  --release               Build Release"
  echo "  --debug                 Build Debug. default"
  echo "  --released              Build Release with Debug Info"
  echo "  --released-light        Build Release with Debug Info, reduced debug (-g1 + split-DWARF, no LTO) for fast local iteration"
  echo "  --native                Build with the native compiler (GCC). default"
  echo "  --clang                 Build with Clang"
  echo "  --clang-tidy            Build with Clang-Tidy"
  echo "  --wasm                  Build to WebAssembly"
  echo "  --profile <native|clang|clang-tidy|wasm> long version of the above"
  echo "  --clean                 Clean the build folder (for the current build state only)"
  echo "  --package               Package the build"
  echo "  --deps-force-build      Force build dependencies"
  echo "  --deps-graph            Create graph.html, the dependencies graph"
  echo "  --create-conan-lock     Create ./conan.lock"
  echo "  --use-conan-lock        Use ./conan.lock if present (default)"
  echo "  --no-use-conan-lock     Do not use any Conan lock file"
  echo "  --version <version>     Set the version. default: latest vX.Y.Z git tag"
  echo "  --next-semver-w-version Print the next version, incrementing 'build'(W) of the latest tag (X.Y.Z.W+1 or X.Y.Z.1) and exit"
  echo "  --next-semver-z-version Print the next version, incrementing 'patch'(Z) of the latest tag (X.Y.Z+1, ignoring W) and exit"
  echo "  --production-version    Use the --version value exactly as the package version (no git hash, date, etc. added)"
  echo "  --nightly-version       Mark the version as a nightly build (package revision is the YYYY.MM.DD.<commit count>.<sha>)"
  echo "  --production-build      Build in production mode (all optimizations enabled)"
  echo "  --no-production-build   Build in development mode (all optimizations disabled)"
  echo "  --build-tests           Build tests (default)"
  echo "  --no-build-tests        Skip building tests"
  exit 0
}

# Function to parse command-line arguments and export environment variables
_parse_command_line() {
  package_version=$STARTERKIT_VERSION

  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        _build_usage
        ;;
      --release)
        build_type=Release
        reduced_debug=false
        ;;
      --debug)
        build_type=Debug
        reduced_debug=false
        ;;
      --released)
        build_type=RelWithDebInfo
        reduced_debug=false
        ;;
      --released-light)
        build_type=RelWithDebInfo
        production_build=false
        reduced_debug=true
        ;;
      --production-build)
        production_build=true
        ;;
      --no-production-build)
        production_build=false
        ;;
      --build-tests)
        build_tests=true
        ;;
      --no-build-tests)
        build_tests=false
        ;;
      --clean)
        clean=true
        ;;
      --package)
        package=true
        ;;
      --state)
        print_build_state=true
        ;;
      --native)
        profile=native
        ;;
      --clang)
        profile=clang
        ;;
      --clang-tidy)
        profile=clang-tidy
        ;;
      --wasm)
        profile=wasm
        ;;
      --profile)
        shift
        if [[ -z $1 || $1 == --* ]]; then
          echo "Error: Missing value for --profile"
          exit 1
        fi
        profile="$1"
        ;;
      --deps-force-build)
        deps_force_build=true
        ;;
      --deps-graph)
        deps_graph=true
        ;;
      --create-conan-lock)
        create_conan_lock=true
        ;;
      --use-conan-lock)
        use_conan_lock=true
        ;;
      --no-use-conan-lock)
        use_conan_lock=false
        ;;
      --production-version)
        export STARTERKIT_IS_PRODUCTION_VERSION=1
        ;;
      --nightly-version)
        export STARTERKIT_IS_NIGHTLY_VERSION=1
        ;;
      --version)
        package_version=$2
        shift
        ;;
      --next-semver-w-version)
        _calculate_next_version "semver-w"
        exit $?
        ;;
      --next-semver-z-version)
        _calculate_next_version "semver-z"
        exit $?
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
        if [[ -z $1 || $1 == --* ]]; then
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
  load_env_vars
  local build_type=${build_type:-Debug}
  local profile=${profile:-native}
  local reduced_debug=${reduced_debug:-false}
  local use_conan_lock=${use_conan_lock:-true}
  _parse_command_line "$@"

  # set the cli name and driver based on the profile
  if [[ $profile == "wasm" ]]; then
    local cli_name="starterkit.js"
    local driver=node
  else
    local cli_name="starterkit"
    local driver=
  fi

  # --released-light keeps build_type=RelWithDebInfo (Conan's cmake_layout + preset name are derived
  # from build_type and always write to build/$build_type), but points that folder at its own
  # per-profile real dir so it doesn't share/overwrite the full-debug --released build.
  local build_dir=$build_type
  if [[ $reduced_debug == "true" ]]; then
    build_dir="${build_type}-light"
  fi

  local build_folder=$root_dir/build/$build_type
  local build_folder_full=$root_dir/build/$profile/$build_dir
  local cli_path="$build_folder/cli/$cli_name"

  # make the env vars persistent, so next time, we won't need to pass the command line flags
  for var in build_type profile reduced_debug use_conan_lock build_folder build_folder_full cli_name cli_path driver; do
    update_env_vars_file $root_dir/.env $var ${!var}
  done
}

function _create_build_folder() {
  local build_folder=$1
  local build_folder_full=$2
  local compile_commands_json=$root_dir/build/compile_commands.json

  # Links can't be created in non-existing directories
  mkdir -p ${build_folder%/*}
  mkdir -p $build_folder_full

  # CMake's standard path to the build folder: build/<Debug|Release|...> -> <profile>/<Debug|Release|...>
  ln -srfn $build_folder_full $build_folder
  # A static, known location of the current build folder for scripts
  ln -srfn $build_folder $root_dir/build/current
  # clangd expects compile_commands.json in the root build folder
  ln -srf $build_folder/compile_commands.json $compile_commands_json
}

# start
ensure_sourced

activate_venv || return $?
_create_env_vars_file "$@"
load_env_vars
_create_build_folder $build_folder $build_folder_full
