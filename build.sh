#!/bin/bash

set -eEo pipefail

function on_error() {
  set +eEo pipefail
  echo "ERROR: an error occurred at line ${BASH_LINENO[0]}"
  echo "       Failed command: ${BASH_COMMAND}"
  exit 1
}

trap on_error ERR INT TERM

# `reset` is invalid without a controlling terminal, and would abort the build when piped.
if [[ ${STARTERKIT_DEV_RESET_TERMINAL:-0} == "1" ]] && [[ -t 1 ]]; then reset; fi

build_start_time=$(date +%s)

# Get the build flags & activate the environment
source ./env/scripts/private/_build_env_vars.sh "$@" || exit $?
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${root_dir:?root_dir must be set by env/scripts/private/_build_env_vars.sh}"

# Kill the processes of $root that match $executables, so the build can replace their binaries.
# Matches the process NAME (-x), not the command line: a compile of .../starterkit.dir/... carries
# the name in its argv. Scoped to $root so a build never touches another worktree's processes.
kill_running_build_artifacts() {
  local root=$1        # only kill binaries living under this folder
  local executables=$2 # pgrep -x pattern, e.g. 'foo|bar'

  local pid exe
  while read -r pid; do
    exe=$(readlink -f "/proc/$pid/exe" 2>/dev/null) || continue
    if [[ $exe == "$root"/* ]]; then
      echo -e "Killing leftover $exe (pid $pid)"
      # Exiting between the scan and the kill is the expected race; still being there afterwards is not
      if ! kill "$pid" 2>/dev/null && [[ -e /proc/$pid ]]; then
        echo -e "Failed to kill leftover $exe (pid $pid)"
      fi
    fi
  done < <(pgrep -x "$executables" || true) # MASK-OK: pgrep exits 1 when nothing matches
}

# Print (execute=false) or run the Conan command that resolves the dependencies graph.
run_conan() {
  local profile=$1
  local build_type=$2
  local build_folder=${3:-$script_dir} # Conan's output folder; cmake_layout adds build/<build_type>
  local execute=${4:-true}
  local distro_specific_options=""
  local conan_build_mode=$([[ ${deps_force_build:-false} == "true" ]] && echo "*" || echo "missing")

  # os.id / os.glibc_version are part of every package_id so distros don't share a cached binary.
  # /etc/os-release is absent on macOS, and a failed source would abort cross-builds (WASM) under set -e.
  if [[ -r /etc/os-release ]]; then
    # shellcheck source=/dev/null
    . /etc/os-release
    local glibc_version
    glibc_version=$(getconf GNU_LIBC_VERSION 2>/dev/null | awk '{print $2}' || echo "unknown")
    if [[ -n ${ID:-} && -f $root_dir/env/profiles/settings_user.yml ]]; then
      distro_specific_options="-s:a os.id=$ID -s:a os.glibc_version=$glibc_version"
    fi
  fi

  local version_option=${package_version:+"--version=$package_version"}

  # Dependencies are built Release even when we build RelWithDebInfo: it is the same code at the same
  # optimization level, without the debug-info cost of rebuilding every dependency.
  local build_type_our_project=$build_type
  local build_type_dependencies=$([[ $build_type == "RelWithDebInfo" ]] && echo "Release" || echo "$build_type")

  local lockfile_option=''
  if [[ ${create_conan_lock:-false} == "true" ]]; then
    lockfile_option="--lockfile='' --lockfile-out=$root_dir/conan.lock --lockfile-clean"
  elif [[ ${use_conan_lock:-true} == "true" && -f $root_dir/conan.lock ]]; then
    lockfile_option="--lockfile=$root_dir/conan.lock"
  fi

  local conan_graph="conan graph info . --format=html ${lockfile_option}"
  local conan_create_lock_file="conan lock create . ${lockfile_option}"
  local conan_build="conan install . --build='${conan_build_mode}' -of=$build_folder ${version_option} ${lockfile_option}"

  local skip_test_option=$([[ -z ${build_tests+x} || $build_tests == "true" ]] && echo "False" || echo "True")

  local profile_options="-pr:b ./env/profiles/native.profile \
  -pr:h ./env/profiles/$profile.profile \
  -s:b build_type=Release \
  -s:h build_type=$build_type_dependencies \
  -s:h '&:build_type=${build_type_our_project}' \
  -c tools.build:skip_test=$skip_test_option \
  ${distro_specific_options}"

  local extra_options=""
  local conan_cmd
  if [[ ${create_conan_lock:-false} == "true" ]]; then
    conan_cmd=$conan_create_lock_file
  elif [[ ${deps_graph:-false} == "true" ]]; then
    conan_cmd=$conan_graph
    extra_options="> $build_folder/graph.html"
  else
    conan_cmd=$conan_build
  fi

  local cmd="${conan_cmd} ${profile_options} ${extra_options}"
  cmd="$(echo "$cmd" | tr -s ' ')"

  if [[ $execute == true ]]; then
    eval "$cmd"
  else
    echo "$cmd"
  fi
}

if [[ ${create_conan_lock:-false} == "true" ]]; then
  run_conan "native" "Release"
  exit 0
fi

# Clean first: the "built before?" checks below depend on it
should_clean=$([[ ${clean:-false} == "true" || ! -f "$build_folder/build.ninja" ]] && echo "true" || echo "false")
if [[ $should_clean == "true" ]]; then
  # `rm -rf $build_folder/*` skips hidden files, and a symlinked build_folder needs the trailing slash
  find "$build_folder/" -mindepth 1 -delete 2>/dev/null || true # MASK-OK: nothing to delete on a first build
  rm -rf "$root_dir"/dist/* 2>/dev/null || true                 # MASK-OK: dist/ may not exist
fi
first_time_build=$([[ ! -f "$build_folder/CMakeCache.txt" ]] && echo "true" || echo "false")

cmake_options=()

# Mirror version flags into the CMake cache when they differ, so a changed --version reconfigures
current_version=$(grep '^STARTERKIT_VERSION:' "$build_folder/CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 || true)
current_is_production_version=$(grep '^STARTERKIT_IS_PRODUCTION_VERSION:' "$build_folder/CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 || true)
current_is_nightly_version=$(grep '^STARTERKIT_IS_NIGHTLY_VERSION:' "$build_folder/CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 || true)
if [[ -n ${package_version:-} && $package_version != "$current_version" ]]; then
  cmake_options+=("-DSTARTERKIT_VERSION=$package_version")
fi
if [[ -n ${STARTERKIT_IS_PRODUCTION_VERSION:-} && $STARTERKIT_IS_PRODUCTION_VERSION != "$current_is_production_version" ]]; then
  cmake_options+=("-DSTARTERKIT_IS_PRODUCTION_VERSION:BOOL=$STARTERKIT_IS_PRODUCTION_VERSION")
fi
if [[ -n ${STARTERKIT_IS_NIGHTLY_VERSION:-} && $STARTERKIT_IS_NIGHTLY_VERSION != "$current_is_nightly_version" ]]; then
  cmake_options+=("-DSTARTERKIT_IS_NIGHTLY_VERSION:BOOL=$STARTERKIT_IS_NIGHTLY_VERSION")
fi

current_production_build=$(grep '^PRODUCTION_BUILD:' "$build_folder/CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 || true)
if [[ ${production_build:-} == "true" && $current_production_build != "ON" ]]; then
  cmake_options+=("-DPRODUCTION_BUILD:BOOL=ON")
fi
if [[ ${production_build:-} == "false" && $current_production_build != "OFF" ]]; then
  cmake_options+=("-DPRODUCTION_BUILD:BOOL=OFF")
fi

current_reduced_debug=$(grep '^STARTERKIT_REDUCED_DEBUG:' "$build_folder/CMakeCache.txt" 2>/dev/null | cut -d'=' -f2 || true)
# Mirror --released-light into the CMake cache when it differs; any other build type clears it.
if [[ ${reduced_debug:-} == "true" && $current_reduced_debug != "ON" ]]; then
  cmake_options+=("-DSTARTERKIT_REDUCED_DEBUG:BOOL=ON")
fi
if [[ (${reduced_debug:-} == "false" && $current_reduced_debug != "OFF") || (-z ${reduced_debug:-} && $first_time_build == "true") ]]; then
  cmake_options+=("-DSTARTERKIT_REDUCED_DEBUG:BOOL=OFF")
fi

if [[ -n ${build_tests+x} ]]; then
  cmake_options+=("-DBUILD_TESTING=$([[ $build_tests == "true" ]] && echo 1 || echo 0)")
fi

if [[ ${deps_graph:-false} == "true" ]]; then
  run_conan "$profile" "$build_type" "$build_folder"
  echo -e "\n${green}Dependencies graph created: ${nc} ./build/current/graph.html"
  exit 0
fi

echo -e "Profile: ${green}$profile${nc}"
echo -e "Build: ${green}$build_type${nc}"
echo -e "Reduced debug: ${green}${reduced_debug:-false}${nc}"
echo -e "Build Folder: $build_folder"

if [[ ${print_build_state:-false} == "true" ]]; then
  exit 0
fi

kill_running_build_artifacts "$script_dir" "${cli_name:-starterkit}"

if [[ $first_time_build == "true" ]]; then
  # 1. Install dependencies
  run_conan "$profile" "$build_type" || exit 1
  # 2. Configure CMake with the preset Conan generated
  preset="conan-${build_type,,}"
  cmake --preset "${preset}" "${cmake_options[@]}" || exit 1
elif [[ ${#cmake_options[@]} -gt 0 ]]; then
  # Subsequent builds reconfigure only when an option changed
  cmake -S "$root_dir" -B "$build_folder" "${cmake_options[@]}" || exit 1
fi

cmake --build "$build_folder"

if [[ ${package:-false} == "true" ]]; then
  echo -e "Packaging to $root_dir/dist ..."
  # Remove only stale packages so re-running --package leaves other files in dist/ alone
  rm -f "$root_dir"/dist/*.deb "$root_dir"/dist/*.ddeb "$root_dir"/dist/*.rpm
  cmake --build "$build_folder" --target package
fi

build_duration=$(($(date +%s) - build_start_time))
echo "Build succeeded, took $((build_duration / 60))m $((build_duration % 60))s"
