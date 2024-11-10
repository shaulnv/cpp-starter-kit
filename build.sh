#!/bin/bash

source ./env/env_vars.sh $1
echo Build: $build_type
echo Build Folder: $build_folder

if [ ! -d "$build_folder" ]; then
  conan build . --build=missing -pr:a ./env/profiles/cpp.profile -s:h build_type=$build_type
else
  cmake --build $build_folder
fi
