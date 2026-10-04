#
# Script to install & activate python virtual env with all the deps needed
# run at each bash-login: source ./activate-local-env.sh
# after script runs to complete, see usage()
#

activate_usage() {
  echo "Usage:"
  echo "  all your dev env tools are in the path (cmake, conan, etc.)."
  echo "  if you need to call 'sudo ...' use 'venv-sudo ...' instead."
}

# function to check if the script is sourced
_ensure_sourced() {
  if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Please run: source ${BASH_SOURCE[0]}"
    exit 1
  fi
}

is_tool_exits() {
  local cmd=$1
  local name=$2
  if ! hash "$cmd" 2>/dev/null; then
    echo -e "${red}ERROR: $name ($cmd) not found.${nc}"
    return 1
  fi
  return 0
}

verify_prerequisites() {
  (
    set -eE
    set -o pipefail

    is_tool_exits curl "curl"
    is_tool_exits g++ "g++" || is_tool_exits clang "clang"
  ) || {
    exit_code=$?
    echo -e "${red}ERROR: Pre-requisites are not met.\n\tDependencies are: curl, C++ compiler.\n\tBest: run ./setup.sh${nc}"
    return $exit_code
  }
}

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
venv_dir=$root_dir/.venv
red="\033[0;31m"
green="\033[0;32m"
yellow="\033[0;33m"
nc='\033[0m' # No Color

# function to run any program as sudo, inside the virtual env
#   e.g. if you have a test which need sudo, use venv-sudo ./regression.py ...
alias venv-sudo='sudo -E env "PATH=$PATH" "VIRTUAL_ENV=$VIRTUAL_ENV"'

# we need this script sourced, as it activate python venv, which itself need to be sourced
_ensure_sourced

quiet=""
if [[ ${1:-} == "--quiet" || ${1:-} == "-q" ]]; then
  quiet=true
fi

# add uv into the path, if not already there
source $root_dir/env/scripts/install_uv.sh

verify_prerequisites || return $?

# An inherited VIRTUAL_ENV may point at a stale or broken venv; it must be cleared in this (sourced) shell.
unset VIRTUAL_ENV 2>/dev/null || true

# install virtual env
(
  # exit on command failure
  set -eE
  set -o pipefail
  trap 'deactivate &> /dev/null; rm -rf $venv_dir' ERR
  is_venv_exists=$([[ -d $venv_dir ]] && echo "true" || echo "false")

  # Run on every activation, so pyproject.toml / uv.lock changes reach existing venvs.
  echo "Running uv sync ..."
  if ! uv sync; then
    echo -e "${yellow}uv sync failed; removing the venv and retrying...${nc}"
    rm -rf "$venv_dir"
    is_venv_exists="false"
    uv sync
  fi

  # Keep uv from discovering some other, possibly broken, venv
  export VIRTUAL_ENV="$venv_dir"

  # one-time setup
  if [[ $is_venv_exists != "true" ]]; then
    echo -e "${green}Creating a Python's Virtual Env...${nc}"
    source $venv_dir/bin/activate

    # pre-commit is used only in dev.
    # if git is not installed, the context is only building.
    if command -v git >/dev/null 2>&1; then
      if [ "$(id -u)" -eq 0 ]; then
        # containers run as root on a checkout owned by someone else
        git config --global --add safe.directory "$root_dir"
      fi
      echo "Installing pre-commit hooks ..."
      pre-commit install || {
        echo -e "${red}pre-commit install failed${nc}"
        exit 10
      }
    fi

    # conan setup
    echo "Detecting conan profile ..."
    conan profile detect -e || {
      echo -e "${red}conan profile detect failed${nc}"
      exit 12
    }
    if [[ -f $root_dir/env/profiles/settings_user.yml ]]; then
      echo "Installing Conan's user settings (OS distro & glibc version) ..."
      conan config install "$root_dir/env/profiles/settings_user.yml"
    fi

    echo "Installing cmake bash completion file"
    mkdir -p "$venv_dir/share"
    curl -fsSL -o "$venv_dir/share/cmake-bash-completion.sh" https://raw.githubusercontent.com/Kitware/CMake/master/Auxiliary/bash-completion/cmake ||
      echo -e "${yellow}cmake bash completion download failed; continuing${nc}"
  fi
) || {
  exit_code=$?
  echo -e "${red}ERROR: Failed creating a Python's Virtual Env. error code: $exit_code.${nc}"
  return $exit_code
}

# activate virtual env (if not activated already)
if [[ -z ${VIRTUAL_ENV:-} ]]; then
  source $venv_dir/bin/activate || {
    echo -e "${red}Failed to activate virtual environment${nc}"
    return 13
  }
fi

# cache 3rd parties CMake projects, imported by CPM
# you can set this env var in your .bashrc to a more persistent place like $HOME/.cache/CPM
if [[ -z ${CPM_SOURCE_CACHE:-} ]]; then
  export CPM_SOURCE_CACHE=$root_dir/.cache/CPM
fi

[ ! -n "$quiet" ] && echo "Virtual Env was loaded" || true
[ ! -n "$quiet" ] && activate_usage || true

# dev-env CLI, aliases and bash completions
source $root_dir/dev-env.sh --quiet
source "$venv_dir/share/cmake-bash-completion.sh" >/dev/null 2>&1 || true
