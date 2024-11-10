#!/bin/bash

source ./env/env_vars.sh
exec "$build_folder/cli/starterkit" "$@"
