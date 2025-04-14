# This library script is meant to be sourced

red="\033[0;31m"
green="\033[0;32m"
yellow="\033[0;33m"
nc='\033[0m' # No Color

# function to check if the script is sourced
_ensure_sourced() {
    if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
        echo "Error: This script must be sourced, not executed."
        echo "Please run: source ${BASH_SOURCE[0]}"
        exit 1
    fi
}

_ensure_sourced

install-uv() {
    # install uv if not installed
    if ! command -v uv &>/dev/null; then
        if [[ -z "${UV_INSTALL_DIR}" ]]; then
            UV_INSTALL_DIR=$HOME/.local/bin
            export PATH="$UV_INSTALL_DIR:$PATH"
            echo -e "${yellow}WARNING: We need 'uv' to be in the path."
            echo -e "${yellow}  Please add '$UV_INSTALL_DIR' to your PATH (in ~/.bashrc)${nc}"
        fi
        # verify curl is installed
        if ! command -v curl &>/dev/null; then
            # check if sudo is installed, if not, check if root, if not root, report error and exit
            if ! command -v sudo &>/dev/null; then
                if [ "$EUID" -ne 0 ]; then
                    echo -e "${red}ERROR: 'sudo' is not installed, and you are not root. run once: apt update -y && apt install -y sudo${nc}"
                    return 1
                else
                    echo -e "${green}Installing 'sudo'${nc}"
                    apt update -y
                    apt install -y sudo
                fi
            fi
            echo -e "${green}Installing 'curl'${nc}"
            sudo apt update -y
            sudo apt install -y curl
        fi
        curl -LsSf https://astral.sh/uv/install.sh | sh
    fi
}

install-uv
