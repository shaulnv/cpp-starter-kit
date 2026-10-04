#!/bin/bash
# Development-environment CLI. Meant to be sourced (activate.sh does it): defines `dev-env` and its aliases.

# The repo-root dev-env.sh is a symlink to this file, so resolve it before deriving paths.
script_dir=$(dirname "$(realpath "${BASH_SOURCE[0]}")")
root_dir=$(realpath "$script_dir/../..")
export root_dir

red='\033[0;31m'
green='\033[0;32m'
rc='\033[0m' # Reset color

_show_usage() {
  echo "Usage: dev-env [OPTION]"
  echo ""
  echo "Options:"
  echo "  --run-dev-container [name]  Run (or attach to) the dev-env docker container"
  echo "  --build-dev-env-docker-image"
  echo "                              Build the dev-env docker image"
  echo "  -h, --help                  Show this help"
  return 1
}

# Start the dev container if it is not running yet, then open a shell in it.
# The container's home lives on the host so shell history, ssh keys and caches survive --rm.
_run_dev_env_container() {
  local container_instance_name="dev-env${1:+-$1}"
  local linux_home=/home/$(whoami)
  local container_home="$HOME/.starterkit-dev-env-home"
  local uv_cache="$HOME/.local/share/uv"
  local is_mac=$([[ "$(uname)" == "Darwin" ]] && echo 1 || echo 0)
  local conan_cache=${CONAN_USER_HOME:-$container_home/.conan2}
  local work="${STARTERKIT_DEV_WORK_DIR:-$(realpath "$root_dir/../")}"

  mkdir -p "$container_home" "$uv_cache" "$conan_cache" "$container_home/work" "$container_home/.ssh"

  if ! docker ps --format '{{.Names}}' | grep -q "^$container_instance_name$"; then
    docker run -it --rm -d \
      --privileged \
      --cap-add=SYS_PTRACE \
      --security-opt seccomp=unconfined \
      -e "GH_TOKEN=${GH_TOKEN:-}" \
      -e "STARTERKIT_DEV_IS_MAC=$is_mac" \
      -v "$HOME/.ssh:$linux_home/.ssh" \
      -v "$container_home:$linux_home" \
      -v "$uv_cache:$linux_home/.local/share/uv" \
      -v "$conan_cache:$linux_home/.conan2" \
      -v "$work:$linux_home/work" \
      -w "$linux_home/work/$(basename "$root_dir")" \
      --name "$container_instance_name" \
      --hostname "$container_instance_name" \
      starterkit-dev-env
  fi
  docker exec -it "$container_instance_name" bash
}

_dev_env_completions_bash() {
  local cur="${COMP_WORDS[COMP_CWORD]}"
  local opts="--run-dev-container --build-dev-env-docker-image --help"
  COMPREPLY=($(compgen -W "${opts}" -- "${cur}"))
  return 0
}

dev-env() {
  local action=""
  local param1=""

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --run-dev-container)
        action="run-dev-container"
        shift
        if [[ -n ${1:-} && $1 != -* ]]; then
          param1="$1"
          shift
        fi
        ;;
      --build-dev-env-docker-image)
        action="build-dev-env-docker-image"
        shift
        ;;
      *)
        _show_usage
        return 1
        ;;
    esac
  done

  case "$action" in
    "run-dev-container")
      _run_dev_env_container "$param1"
      return $?
      ;;
    "build-dev-env-docker-image")
      docker build -t starterkit-dev-env \
        --build-arg "USERNAME=$(whoami)" --build-arg "USER_UID=$(id -u)" --build-arg "USER_GID=$(id -g)" \
        -f "$root_dir/.devcontainer/Dockerfile" "$root_dir"
      return $?
      ;;
    *)
      _show_usage
      return 1
      ;;
  esac
}

alias de=dev-env
alias bu=./build.sh
alias der='dev-env --run-dev-container'

complete -F _dev_env_completions_bash dev-env
complete -F _dev_env_completions_bash de

source "$script_dir/shell_completion.sh"

if [ "${1:-}" != "--quiet" ]; then
  echo "Development Environment CLI was loaded"
  echo "Run 'dev-env --help' to see available commands"
fi
