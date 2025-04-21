#!/bin/sh

# Alpine-friendly setup script (no Bash-only features)

set -Ee
set -o pipefail

# Remove this line (Bash-only):
# trap 'LAST_COMMAND=$CURRENT_COMMAND; CURRENT_COMMAND=$BASH_COMMAND' DEBUG

# Replace this line (Bash-only):
# trap 'ERROR_CODE=$?; echo "ERROR: \"$LAST_COMMAND\" failed with exit code $ERROR_CODE"' ERR INT TERM

# With simpler POSIX-compliant trap:
trap 'echo "ERROR: setup failed with exit code $?."' ERR INT TERM

run() {
  echo "[RUNNING] $@"
  "$@" || { echo "[ERROR] Command failed: $@"; exit 1; }
}

# common variables
root_dir=$(cd "$(dirname "$0")" && pwd)
green="\033[0;32m"
red="\033[0;31m"
nc='\033[0m' # No Color

nvm_version=v0.40.2

package-manager-setup() {
  # Ensure sudo exists or use root
  if ! command -v sudo >/dev/null 2>&1; then
    if [ "$(id -u)" -ne 0 ]; then
      echo -e "${red}sudo is not installed and you are not root. Run once: apk add sudo${nc}"
      exit 1
    fi
    echo -e "${green}Running as root${nc}"
    alias sudo=""
  fi

  run sudo apk update
  run sudo apk add --no-cache curl wget bash git
}

package-manager-cleanup() {
  # Clean up (apk doesn't keep cache with --no-cache)
  echo -e "${green}Alpine doesn't keep package caches with --no-cache, nothing to clean.${nc}"
}

install-github-cli() {
  # GitHub CLI not available in Alpine's core repos, install from GitHub
  # run sudo apk add --no-cache git curl
  # run sudo apk add --no-cache openssh
  # run curl -fsSL https://github.com/cli/cli/releases/latest/download/gh_2.49.0_linux_amd64.tar.gz | tar -xz
  # run sudo mv gh_*/bin/gh /usr/local/bin/
  # run rm -rf gh_*
  run sudo apk add --no-cache github-cli
}

install-dev-tools() {
  run sudo apk add --no-cache \
    git tig vim tree \
    python3 py3-pip py3-setuptools py3-virtualenv py3-wheel \
    clang llvm gdb

  install-github-cli
}

install-build-dependencies() {
  run sudo apk add --no-cache \
    curl build-base bash

  # install uv (Python packaging tool)
  UV_INSTALL_DIR=$HOME/.local/bin
  export PATH="$UV_INSTALL_DIR:$PATH"
  run curl -LsSf https://astral.sh/uv/install.sh | sh

  # install NVM and Node
  if ! command -v nvm >/dev/null 2>&1; then
    run curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
  fi

  run nvm install node
}

install-vscode-extensions-dependencies() {
  # run curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
  # run chmod +x ./dotnet-install.sh
  # run ./dotnet-install.sh --version latest --runtime aspnetcore
}

# Run the setup
package-manager-setup
install-dev-tools
install-build-dependencies
install-vscode-extensions-dependencies
package-manager-cleanup

# Mark setup as done
touch "$root_dir/.env"
echo -e "${green}Setup completed successfully${nc}"
