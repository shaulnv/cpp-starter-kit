#!/usr/bin/env bash
# Run pre-commit checks on staged files (default) or all files.
#
# Usage:
#   ./env/scripts/run-precommit.sh          Run on staged files
#   ./env/scripts/run-precommit.sh --all    Run on all files

set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: command failed (exit $?)" >&2' ERR

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[pre-commit]${NC} $1"; }
error() {
  echo -e "${RED}[pre-commit ERROR]${NC} $1" >&2
  exit 1
}
success() { echo -e "${GREEN}[pre-commit]${NC} $1"; }

usage() {
  cat <<EOT
Usage: $0 [OPTIONS]

Run pre-commit hooks on files.

OPTIONS:
    -a, --all      Run on all files (not just staged)
    -h, --help     Show this help message
EOT
}

args=()
while [[ $# -gt 0 ]]; do
  case $1 in
    -a | --all)
      args+=(--all-files)
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      error "Unknown option: $1"
      ;;
  esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
cd "$PROJECT_ROOT"

if ! command -v pre-commit &>/dev/null; then
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/activate.sh" --quiet ||
    error "pre-commit not found and the dev environment could not be activated."
fi

log "Running pre-commit on ${args[*]:-staged files}..."
if pre-commit run "${args[@]}"; then
  success "All pre-commit checks passed!"
else
  error "Some pre-commit checks failed. Please fix the issues above."
fi
