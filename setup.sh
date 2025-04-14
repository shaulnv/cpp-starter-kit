#!/bin/bash

set -Eex
set -o pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
red="\033[0;31m"
green="\033[0;32m"
nc='\033[0m' # No Color

install-github-cli() {
  sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt -y update
  sudo apt -y install gh
}

# Set noninteractive mode for apt
DEBIAN_FRONTEND=noninteractive

# make sure we can install OS packages
# either sudo or root
if ! command -v sudo &>/dev/null; then
  if [ "$EUID" -ne 0 ]; then
    echo -e "${red}sudo is not installed, and you are not root. run once: apt update -y && apt install -y sudo${nc}"
    exit 1
  fi
  echo -e "${green}sudo is not installed, installing...${nc}"
  apt update -y
  apt install -y --no-install-recommends sudo
fi

# install OS packages
sudo apt update -y
sudo apt install -y --no-install-recommends \
  sudo curl wget gnupg tig vim \
  python3 python-is-python3 python3-pip python3-dev python3-venv python3-setuptools \
  git build-essential clang gdb \
  nodejs

install-github-cli
# install uv (the Python's package manager used by the project)
source $root_dir/env/scripts/_install_uv.sh

# Clean up OS packages
sudo apt clean -y
sudo rm -rf /var/lib/apt/lists/*

# install uv (a Python's package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh

# mark setup as done
touch $root_dir/.env
