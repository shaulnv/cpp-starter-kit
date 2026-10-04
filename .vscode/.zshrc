# Source the standard zshrc if it exists
if [ -f "${HOME}/.zshrc" ]; then
  source "${HOME}/.zshrc"
fi

source ./activate.sh --quiet
