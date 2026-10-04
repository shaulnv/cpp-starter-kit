#!/bin/bash

# `reset` is invalid without a controlling terminal
if [[ ${STARTERKIT_DEV_RESET_TERMINAL:-0} == "1" ]] && [[ -t 1 ]]; then reset; fi

# activate python's virtual env
. ./activate.sh --quiet
. .env 2>&1 >/dev/null || true

# check if we already build once
if [ ! -d "$build_folder" ]; then
  echo "ERROR: project is not built. run: './build.sh' and then rerun ./test.sh"
  exit 1
fi

# all arguments pass through to ctest, e.g. ./test.sh -R <regex>
ctest --test-dir "$build_folder" --output-on-failure --parallel "$@"
