#!/bin/bash

source ./env/env_vars.sh "$@"
echo Profile: $profile
echo Build: $build_type
echo Build Folder: $build_folder

if [ ! -d "$build_folder" ]; then
  mkdir -p "$build_folder" 
  conan build . --build=missing -pr:b ./env/profiles/cpp.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type 2>&1 | tee $build_folder/build.log
else
  cmake --build $build_folder 2>&1 | tee $build_folder/build.log
fi
