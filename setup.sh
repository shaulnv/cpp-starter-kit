#!/bin/bash

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
yellow="\033[0;33m"
nc='\033[0m' # No Color

# dependencies versions
nvm_version=v0.40.2
llvm_version=22

# Package installs need root: either we are root, or sudo does it.
SUDO=$([ "$EUID" -eq 0 ] && echo "" || echo "sudo")

ensure-root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${red}Error: Please run this script with sudo or as root.${nc}"
    exit 1
  fi
}

package-manager-setup() {
  # Keep apt/tzdata from prompting
  export DEBIAN_FRONTEND=noninteractive
  export TZ=Etc/UTC
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
  $SUDO apt -y update
  # packages for installing other packages from the internet; software-properties-common provides add-apt-repository
  $SUDO apt -y install --no-install-recommends tzdata ca-certificates curl wget gnupg software-properties-common
}

package-manager-cleanup() {
  $SUDO apt -y clean
  $SUDO rm -rf /var/lib/apt/lists/*
}

install-github-cli() {
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  $SUDO chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO apt -y update
  $SUDO apt -y install gh
}

install-clang() {
  # apt.llvm.org's script gives a recent clang/clang-tidy that the distro does not ship
  $SUDO apt -y install --no-install-recommends lsb-release wget software-properties-common gnupg
  wget https://apt.llvm.org/llvm.sh && chmod +x llvm.sh && $SUDO ./llvm.sh $llvm_version
  rm -f llvm.sh
  $SUDO apt -y install clang-$llvm_version libc++-$llvm_version-dev libc++abi-$llvm_version-dev clang-tools-$llvm_version
  # make this clang the default
  $SUDO update-alternatives --install /usr/bin/clang clang /usr/bin/clang-$llvm_version 100
  $SUDO update-alternatives --install /usr/bin/clang++ clang++ /usr/bin/clang++-$llvm_version 100
  $SUDO update-alternatives --install /usr/bin/clang-scan-deps clang-scan-deps /usr/bin/clang-scan-deps-$llvm_version 100
  $SUDO update-alternatives --install /usr/bin/clangd clangd /usr/bin/clangd-$llvm_version 100
}

install-dev-tools() {
  # Tools for development, not a pre-requisite for building the project
  # git-core PPA: latest git (supports push.autoSetupRemote)
  $SUDO add-apt-repository ppa:git-core/ppa -y
  $SUDO apt -y update
  $SUDO apt -y install \
    git tig vim tree ansifilter bash-completion jq time file procps \
    python3 python-is-python3 python3-pip python3-dev python3-venv python3-setuptools \
    gdb shfmt
  install-clang
  install-github-cli
}

install-build-dependencies() {
  # curl is needed to install uv
  $SUDO apt -y install --no-install-recommends \
    ca-certificates curl build-essential pkg-config
  # install uv (the Python's package manager used by the project)
  source $root_dir/env/scripts/install_uv.sh

  # wasm target. remove if not needed
  # see https://github.com/nvm-sh/nvm/releases for the latest version
  # install nvm & node
  if ! command -v nvm &>/dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/$nvm_version/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"                   # This loads nvm
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion" # This loads nvm bash_completion
  fi
  nvm install node
}

install-vscode-extensions-dependencies() {
  # .NET is needed by VSCode's CMake language extension
  curl -L https://dot.net/v1/dotnet-install.sh -o dotnet-install.sh
  chmod +x ./dotnet-install.sh
  $SUDO ./dotnet-install.sh --version latest --runtime aspnetcore
  rm -f dotnet-install.sh
}

configure-git() {
  git config --global push.autoSetupRemote true
}

install-full-dev-env() {
  package-manager-setup
  install-dev-tools
  install-build-dependencies
  install-vscode-extensions-dependencies
  configure-git
  package-manager-cleanup
  # mark setup as done
  touch $root_dir/.env
  echo -e "${green}Setup completed successfully${nc}"
}

install-rhel-minimal-build-dependencies() {
  ensure-root
  dnf install -y gcc tar gzip g++ sudo git procps-ng
  # nice tools
  dnf install -y tig vim tree bash-completion
}

install-debian-minimal-build-dependencies() {
  ensure-root
  export DEBIAN_FRONTEND=noninteractive
  apt -y update
  apt -y install --no-install-recommends \
    sudo ca-certificates curl pkg-config build-essential \
    tig vim tree bash-completion
}

install-minimal-build-env() {
  # RHEL family → dnf; Ubuntu/Debian → apt
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    case "$ID" in
      rhel | amzn | fedora | rocky | almalinux)
        echo -e "${green}Detected $ID${nc}"
        install-rhel-minimal-build-dependencies
        ;;
      ubuntu | debian)
        echo -e "${green}Detected $ID${nc}"
        install-debian-minimal-build-dependencies
        ;;
      *)
        echo -e "${red}Unsupported OS: $ID${nc}"
        exit 1
        ;;
    esac
  else
    echo -e "${red}Cannot detect operating system, /etc/os-release not found.${nc}"
    exit 1
  fi
  # install uv (the Python's package manager used by the project)
  echo -e "${green}Installing uv (the Python's package manager used by the project)${nc}"
  source $root_dir/env/scripts/install_uv.sh
  # mark setup as done
  touch $root_dir/.env
  echo -e "${green}Minimal build environment setup completed successfully${nc}"
}

usage() {
  echo "Usage: $0 [--build-env | --dev-env] [-h|--help]"
  echo
  echo "Options:"
  echo "  --build-env            Install a minimal build environment (Debian/Ubuntu/RHEL family)"
  echo "  --dev-env              Install a full development environment (Ubuntu only). default"
  echo "  -h, --help             Show this help message and exit"
}

main() {
  local mode=dev-env
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -h | --help)
        usage
        exit 0
        ;;
      --build-env) mode=build-env ;;
      --dev-env) mode=dev-env ;;
      *)
        echo -e "${red}Error: Unknown option: $1${nc}"
        echo
        usage
        exit 1
        ;;
    esac
    shift
  done

  if [[ $mode == "build-env" ]]; then
    install-minimal-build-env
  else
    # to ease debugging of installation issues
    set -x
    install-full-dev-env
  fi
}

main "$@"
