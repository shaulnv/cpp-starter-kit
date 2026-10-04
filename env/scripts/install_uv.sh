# This library script is meant to be sourced

red="\033[0;31m"
green="\033[0;32m"
yellow="\033[0;33m"
cyan="\033[1;36m"
nc='\033[0m' # No Color

# function to check if the script is sourced
_ensure_sourced() {
  if [[ ${BASH_SOURCE[0]} == "${0}" ]]; then
    echo "Error: This script must be sourced, not executed."
    echo "Please run: source ${BASH_SOURCE[0]}"
    exit 1
  fi
}

_ensure_sourced

# Detect package manager at load time (Ubuntu/Debian vs RHEL/Amazon Linux)
if command -v apt-get &>/dev/null; then
  PKG_MGR=apt
  CA_CERT_PATH=/etc/ssl/certs/ca-certificates.crt
elif command -v dnf &>/dev/null; then
  PKG_MGR=dnf
  CA_CERT_PATH=/etc/pki/tls/certs/ca-bundle.crt
else
  PKG_MGR=
  CA_CERT_PATH=
fi

_install_sudo_if_needed() {
  if command -v sudo &>/dev/null; then
    return 0
  fi
  if [ "$EUID" -eq 0 ]; then
    echo -e "${green}Installing 'sudo'${nc}"
    case $PKG_MGR in
      apt) apt update -y && apt install -y sudo ;;
      dnf) dnf install -y sudo ;;
      *)
        echo -e "${red}ERROR: Cannot install sudo (unknown package manager)${nc}"
        return 1
        ;;
    esac
  else
    case $PKG_MGR in
      apt) echo -e "${red}ERROR: 'sudo' is not installed, and you are not root. Run once: apt update -y && apt install -y sudo${nc}" ;;
      dnf) echo -e "${red}ERROR: 'sudo' is not installed, and you are not root. Run once: dnf install -y sudo${nc}" ;;
      *) echo -e "${red}ERROR: 'sudo' is not installed, you are not root, and no supported package manager (apt/dnf) found.${nc}" ;;
    esac
    return 1
  fi
}

_install_curl_and_ca_certs() {
  echo -e "${green}Installing 'curl' and 'ca-certificates'${nc}"
  case $PKG_MGR in
    apt) sudo apt update -y && sudo apt install -y ca-certificates curl ;;
    dnf) sudo dnf install -y ca-certificates curl ;;
    *)
      echo -e "${red}ERROR: No supported package manager (apt/dnf)${nc}"
      return 1
      ;;
  esac
}

_ensure_ca_certs() {
  [[ -n $CA_CERT_PATH ]] && [[ -f $CA_CERT_PATH ]] && return 0
  if ! command -v sudo &>/dev/null; then
    return 0
  fi
  echo -e "${green}Installing 'ca-certificates' for HTTPS${nc}"
  case $PKG_MGR in
    apt) sudo apt install -y ca-certificates ;;
    dnf) sudo dnf install -y ca-certificates ;;
    *) ;;
  esac
}

install-uv() {
  if [[ -z $PKG_MGR ]]; then
    echo -e "${red}ERROR: Unsupported system. This script requires apt (Ubuntu/Debian) or dnf (RHEL/Amazon Linux).${nc}"
    return 1
  fi

  # install uv if not installed
  if ! command -v uv &>/dev/null; then
    # uv's default install dir
    if [[ -z ${UV_INSTALL_DIR} ]]; then
      UV_INSTALL_DIR=$HOME/.local/bin
    fi
    # Check if uv exists in the default install location
    if [[ -f "$UV_INSTALL_DIR/uv" ]]; then
      # uv is installed but not in PATH - add it temporarily and warn
      export PATH+=":$UV_INSTALL_DIR"
      echo -e "${yellow}INFO: Found 'uv' in $UV_INSTALL_DIR, temporarily added to PATH."
      echo -e "${yellow}  For permanent access, add this to your shell config (e.g. ~/.bashrc):${nc}"
      echo -e "${yellow}  export PATH=\"$UV_INSTALL_DIR:\$PATH\"${nc}"
      return 0
    fi
    # install uv
    #   verify curl is installed
    if ! command -v curl &>/dev/null; then
      _install_sudo_if_needed || return 1
      _install_curl_and_ca_certs || return 1
    fi
    _ensure_ca_certs
    curl -LsSf https://astral.sh/uv/install.sh | sh
    echo -e "${cyan}uv was installed to '$UV_INSTALL_DIR'${nc}"
    echo -e "${cyan}  Please add '$UV_INSTALL_DIR' to your PATH (in ~/.bashrc)${nc}"
    export PATH+=":$UV_INSTALL_DIR"
  fi
}

install-uv
