#!/bin/bash

set -Eex
set -o pipefail

install-github-cli() {
  sudo curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  sudo chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  sudo apt -y update
  sudo apt -y install gh
}

# Set noninteractive mode for apt
DEBIAN_FRONTEND=noninteractive

# Update package list, install packages, and clean up
sudo apt update -y
sudo apt install -y --no-install-recommends \
  sudo curl wget gnupg tig vim \
  python3 python-is-python3 python3-pip python3-dev python3-venv python3-setuptools \
  git build-essential clang ninja-build gdb \
  nodejs

install-github-cli

# Clean up OS packages
sudo apt clean -y
sudo rm -rf /var/lib/apt/lists/*

# install uv (a Python's package manager)
curl -LsSf https://astral.sh/uv/install.sh | sh
uv python install 3.12
