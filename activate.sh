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
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "Error: This script must be sourced, not executed."
        echo "Please run: source ${BASH_SOURCE[0]}"
        exit 1
    fi
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

if [[ "$1" == "--quiet" || "$1" == "-q" ]]; then
    quiet=true
fi

# verify ./setup.sh was run
if ! command -v uv &>/dev/null && [[ ! -d $venv_dir ]] && [[ ! -f $root_dir/.env ]]; then
    echo -e "${yellow}WARNING: 'uv' not found. Please make sure you ran ./setup.sh to install build dependencies.${nc}"
fi

# add uv into the path, if not already there
source $root_dir/env/scripts/install_uv.sh

# install virtual env
(
    # exit on command failure
    set -eE
    set -o pipefail
    trap 'deactivate &> /dev/null; rm -rf $venv_dir' ERR
    # install the venv only once
    if [[ ! -d $venv_dir ]]; then
        echo -e "${green}Creating a Python's Virtual Env...${nc}"
        echo "Running uv sync ..."
        uv sync || {
            echo -e "${red}uv sync failed${nc}"
            exit 10
        }

        source $venv_dir/bin/activate

        echo "Installing pre-commit hooks ..."
        pre-commit install || {
            echo -e "${red}pre-commit install failed${nc}"
            exit 10
        }

        # conan setup
        echo "Detecting conan profile ..."
        conan profile detect -e || {
            echo -e "${red}conan profile detect failed${nc}"
            exit 12
        }
    fi
) || {
    exit_code=$?
    echo -e "${red}ERROR: Failed creating a Python's Virtual Env. error code: $exit_code.${nc}"
    return $exit_code
}

# activate vitural env (if not activated already)
if [[ ! -n "$VIRTUAL_ENV" ]]; then
    source $venv_dir/bin/activate || {
        echo -e "${red}Failed to activate virtual environment${nc}"
        exit 13
    }
fi

# cache 3rd parties CMake projects, imported by CPM
# you can set this env var in your .bashrc to a more persistent place like $HOME/.cache/CPM
if [[ ! -n "$CPM_SOURCE_CACHE" ]]; then
    export CPM_SOURCE_CACHE=$root_dir/.cache/CPM
fi

[ ! -n "$quiet" ] && echo "Virtual Env was loaded"
[ ! -n "$quiet" ] && activate_usage
