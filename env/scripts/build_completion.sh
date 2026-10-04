#!/bin/bash

# Bash completion for build.sh; sourced by env/scripts/shell_completion.sh

_build_completion_bash() {
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD - 1]}"
  opts="--state --release --debug --released --released-light --native --clang --clang-tidy --wasm --profile --clean --package --deps-force-build --deps-graph --create-conan-lock --use-conan-lock --no-use-conan-lock --version --next-semver-w-version --next-semver-z-version --production-version --nightly-version --production-build --no-production-build --build-tests --no-build-tests --help"

  if [[ $prev == "--profile" ]]; then
    COMPREPLY=($(compgen -W "native clang clang-tidy wasm" -- "$cur"))
    return 0
  fi

  COMPREPLY=($(compgen -W "${opts}" -- "$cur"))
  return 0
}

complete -F _build_completion_bash ./build.sh
complete -F _build_completion_bash bu
