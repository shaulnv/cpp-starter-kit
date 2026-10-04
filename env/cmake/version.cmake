# Project version resolution. Include before project() and call set_project_version().
#
# Precedence (first hit wins): 1. STARTERKIT_VERSION environment variable (build.sh --version exports it) 2.
# -DSTARTERKIT_VERSION=... 3. latest reachable git tag 'vX.Y.Z[.W]' 4. 0.0.1
#
# Outputs (parent scope): STARTERKIT_VERSION_SEMANTIC; cache bools STARTERKIT_IS_PRODUCTION_VERSION /
# STARTERKIT_IS_NIGHTLY_VERSION, consumed by cpack.cmake.

function(set_project_version)
  set(STARTERKIT_VERSION
      ""
      CACHE STRING "Project version; empty means derive from the latest git tag")
  set(STARTERKIT_IS_PRODUCTION_VERSION
      OFF
      CACHE BOOL "Package version is exactly STARTERKIT_VERSION, without git build metadata")
  set(STARTERKIT_IS_NIGHTLY_VERSION
      OFF
      CACHE BOOL "Package revision is date.commit-count.sha, sortable across nightly builds")

  # Only override the cache when the env var is set, so an unset env never clobbers a -D value.
  foreach(_var STARTERKIT_VERSION STARTERKIT_IS_PRODUCTION_VERSION STARTERKIT_IS_NIGHTLY_VERSION)
    if(DEFINED ENV{${_var}} AND NOT "$ENV{${_var}}" STREQUAL "")
      set(${_var}
          "$ENV{${_var}}"
          CACHE STRING "" FORCE)
    endif()
  endforeach()

  set(_version "${STARTERKIT_VERSION}")
  if(_version STREQUAL "")
    find_package(Git QUIET)
    if(GIT_FOUND)
      execute_process(
        COMMAND ${GIT_EXECUTABLE} describe --tags --match "v*" --abbrev=0
        WORKING_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}
        OUTPUT_VARIABLE _tag
        OUTPUT_STRIP_TRAILING_WHITESPACE ERROR_QUIET)
      if(_tag MATCHES "^v([0-9]+\\.[0-9]+\\.[0-9]+(\\.[0-9]+)?)$")
        set(_version "${CMAKE_MATCH_1}")
      endif()
    endif()
  endif()
  if(_version STREQUAL "")
    set(_version "0.0.1")
  endif()

  # Production wins, so an explicit production request is never silently downgraded.
  if(STARTERKIT_IS_PRODUCTION_VERSION AND STARTERKIT_IS_NIGHTLY_VERSION)
    message(WARNING "Both production and nightly version requested; using production.")
    set(STARTERKIT_IS_NIGHTLY_VERSION
        OFF
        CACHE BOOL "" FORCE)
  endif()

  message(STATUS "starterkit version: ${_version}")
  if(STARTERKIT_IS_PRODUCTION_VERSION)
    message(STATUS "Creating production version")
  elseif(STARTERKIT_IS_NIGHTLY_VERSION)
    message(STATUS "Creating nightly version")
  endif()

  set(STARTERKIT_VERSION_SEMANTIC
      "${_version}"
      PARENT_SCOPE)
endfunction()
