#!/bin/bash

source ./env/scripts/private/_build_env_vars.sh "$@" || exit $?
echo Profile: $profile
echo Build: $build_type
echo Build Folder: $build_folder

if [[ "$clean" == "true" ]]; then
  rm -rf $build_folder/*
fi
if [ ! -f "$build_folder/CMakeCache.txt" ]; then
  conan build . --build=missing -pr:b ./env/profiles/native.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type
else
  cmake --build $build_folder
fi
