# Source the standard bashrc if it exists
[ -f "${HOME}/.bashrc" ] && source "${HOME}/.bashrc"
# Activate the project virtual environment
[ -f ./activate.sh ] && source ./activate.sh --quiet
