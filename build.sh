#!/bin/bash

source ./env/env_vars.sh "$@"
echo Profile: $profile
echo Build: $build_type
echo Build Folder: $build_folder

if [ ! -d "$build_folder" ]; then
  conan build . --build=missing -pr:b ./env/profiles/cpp.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type
else
  cmake --build $build_folder
fi
