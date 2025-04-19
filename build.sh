#!/bin/bash

source ./env/scripts/private/_build_env_vars.sh "$@" || exit $?

# conan_debug_params="-vvv -c tools.build:verbosity=verbose -c user.cmake:trace-expand=true"

echo Profile: $profile
echo Build: $build_type
echo Build Folder: $build_folder

if [[ "$clean" == "true" ]]; then
  rm -rf $build_folder/*
fi
if [ ! -f "$build_folder/CMakeCache.txt" ]; then
  conan build . --build=missing -pr:b ./env/profiles/native.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type
  # conan build . --build=missing -pr:b ./env/profiles/native.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type $conan_debug_params
  # build_type_lower=$(echo $build_type | tr '[:upper:]' '[:lower:]')
  # conan install . --build=missing -pr:b ./env/profiles/native.profile -pr:h ./env/profiles/$profile.profile -s:a build_type=$build_type
  # cmake --preset conan-$build_type_lower
  # cmake --build $build_folder
else
  cmake --build $build_folder
fi


# --debug-output
# Put cmake in a debug mode.
# Print extra information during the cmake run like stack traces with message(send_error ) calls.

# --trace
# Put cmake in trace mode.
# Print a trace of all calls made and from where.

# --trace-expand
# Put cmake in trace mode.
# Like --trace, but with variables expanded.
