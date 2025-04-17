#!/bin/bash

# to ease debugging of installation issues
set -x

# BASH error handling:
#   exit on command failure
set -Ee
set -o pipefail
#   keep track of the last executed command
trap 'LAST_COMMAND=$CURRENT_COMMAND; CURRENT_COMMAND=$BASH_COMMAND' DEBUG
#   on error: print the failed command
trap 'ERROR_CODE=$?; FAILED_COMMAND=$LAST_COMMAND; tput setaf 1; echo "ERROR: command \"$FAILED_COMMAND\" failed with exit code $ERROR_CODE"; tput sgr0;' ERR INT TERM

# common variables
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
red="\033[0;31m"
green="\033[0;32m"
nc='\033[0m' # No Color

package-manager-setup() {
  # Set noninteractive mode for apt
  DEBIAN_FRONTEND=noninteractive
  # make sure we can install OS packages
  # either sudo or root
  if ! command -v sudo &>/dev/null; then
    if [ "$EUID" -ne 0 ]; then
      echo -e "${red}sudo is not installed, and you are not root. run once: apt -y update && apt -y install sudo${nc}"
      exit 1
    fi
    echo -e "${green}sudo is not installed, installing...${nc}"
    apt -y update
    apt -y install --no-install-recommends sudo
  fi
  sudo apt -y update
  # packages for installing other packages from the internet
  sudo apt -y install --no-install-recommends curl wget gnupg
}

package-manager-cleanup() {
  # Clean up OS packages
  sudo apt -y clean
  sudo rm -rf /var/lib/apt/lists/*
}

install-github-cli() {
  sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt -y update
  sudo apt -y install gh
}

install-dev-tools() {
  # Tools for development, not a pre-requisite for building the project
  # clang packages are needed for clang-tidy build
  sudo apt -y install --no-install-recommends \
    git tig vim tree \
    python3 python-is-python3 python3-pip python3-dev python3-venv python3-setuptools \
    clang libc++-dev libc++abi-dev llvm \
    gdb \
    nodejs
  install-github-cli
}

install-build-dependencies() {
  # build dependencies
  # curl is needed to install uv
  sudo apt -y install --no-install-recommends \
    curl build-essential
  # install uv (the Python's package manager used by the project)
  source $root_dir/env/scripts/install_uv.sh
}

install-vscode-extensions-dependencies() {
  # .NET is needed by VSCode's CMake language extension
  curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
  chmod +x ./dotnet-install.sh
  sudo ./dotnet-install.sh --version latest --runtime aspnetcore
}

# setup the environment
package-manager-setup
install-dev-tools
install-build-dependencies
install-vscode-extensions-dependencies
package-manager-cleanup

# mark setup as done
touch $root_dir/.env
echo -e "${green}Setup completed successfully${nc}"
