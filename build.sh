#!/bin/bash

# Function to add or replace a key=value pair in an .env file
update_env_file() {
  local file=$1
  local key=$2
  local value=$3

  # Check if key already exists in the file
  if grep -q "^$key=" "$file"; then
    # If key exists, replace the value
    sed -i "s/^$key=.*/$key=$value/" "$file"
  else
    # If key does not exist, add it to the end of the file
    echo "$key=$value" >>"$file"
  fi
}

conan_build() {
  conan build . --build=missing -pr:a ./env/profiles/cpp20.profile $@
}

# activate python's virtual env
. ./activate.sh --quiet

# determent build type: debug/release
build_type=Debug               # default
. .env 2>&1 >/dev/null || true # read build_type env var
# command line param
if [ "$1" == '--debug' ]; then build_type=Debug; fi
if [ "$1" == '--release' ]; then build_type=Release; fi
# make the build_type persistent, so we don't need to pass --release/--debug
update_env_file .env build_type $build_type
echo Build: $build_type

# check if we already build once, and get the build folder (for cmake --build)
build_folder=$(realpath "./build/$build_type")
if [ ! -d "$build_folder" ]; then
  conan_build -s:a build_type=$build_type
else
  cmake --build $build_folder
fi
