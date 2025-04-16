#!/bin/bash

# Get the build flags & activate the environment
source ./env/scripts/private/_build_env_vars.sh "$@" || exit $?

# What we're building
echo Profile: $profile
echo Build: $build_type
echo Build Folder: $build_folder

# Clean build if requested
if [[ "$clean" == "true" ]]; then
  rm -rf $build_folder
fi

# Build
if [ ! -f "$build_folder/CMakeCache.txt" ]; then
  # First time build: install dependencies & build (Conan does this)
  conan build . --build=missing -pr:b ./env/profiles/native.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type
else
  # Subsequent builds: regular CMake build
  cmake --build $build_folder
fi
