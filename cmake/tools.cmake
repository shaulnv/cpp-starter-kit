# this file contains a list of tools that can be activated and downloaded on-demand each tool is enabled during
# configuration by passing an additional `-DUSE_<TOOL>=<VALUE>` argument to CMake

# only activate tools for top level project
if(NOT PROJECT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  return()
endif()

include(${CMAKE_CURRENT_LIST_DIR}/CPM.cmake)

# enables sanitizers support using the the `USE_SANITIZER` flag available values are: Address, Memory,
# MemoryWithOrigins, Undefined, Thread, Leak, 'Address;Undefined'
if(USE_SANITIZER OR USE_STATIC_ANALYZER)
  CPMAddPackage("gh:StableCoder/cmake-scripts#24.04")

  if(USE_SANITIZER)
    include(${cmake-scripts_SOURCE_DIR}/sanitizers.cmake)
  endif()

  if(USE_STATIC_ANALYZER)
    if("clang-tidy" IN_LIST USE_STATIC_ANALYZER)
      set(CLANG_TIDY
          ON
          CACHE INTERNAL "")
    else()
      set(CLANG_TIDY
          OFF
          CACHE INTERNAL "")
    endif()
    if("iwyu" IN_LIST USE_STATIC_ANALYZER)
      set(IWYU
          ON
          CACHE INTERNAL "")
    else()
      set(IWYU
          OFF
          CACHE INTERNAL "")
    endif()
    if("cppcheck" IN_LIST USE_STATIC_ANALYZER)
      set(CPPCHECK
          ON
          CACHE INTERNAL "")
    else()
      set(CPPCHECK
          OFF
          CACHE INTERNAL "")
    endif()

    include(${cmake-scripts_SOURCE_DIR}/tools.cmake)

    if(${CLANG_TIDY})
      clang_tidy(${CLANG_TIDY_ARGS})
    endif()

    if(${IWYU})
      include_what_you_use(${IWYU_ARGS})
    endif()

    if(${CPPCHECK})
      cppcheck(${CPPCHECK_ARGS})
    endif()
  endif()
endif()

# enables CCACHE support through the USE_CCACHE flag possible values are: YES, NO or equivalent
if(USE_CCACHE)
  CPMAddPackage("gh:TheLartians/Ccache.cmake@1.2.4")
endif()

if(DEFINED CMAKE_CXX_INCLUDE_WHAT_YOU_USE AND CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
  # Path to fix_includes.py
  set(FIX_INCLUDES_PY ${CMAKE_SOURCE_DIR}/env/tools/fix_includes.py)

  if(EXISTS ${FIX_INCLUDES_PY})
    # Output file for IWYU suggestions (ensure it exists before fixing includes)
    set(IWYU_OUTPUT ${CMAKE_BINARY_DIR}/build.log)

    if(EXISTS ${IWYU_OUTPUT})
      # Find Python executable
      find_program(PYTHON_EXECUTABLE NAMES python3 REQUIRED)

      # Add a custom target to fix includes based on IWYU output
      add_custom_target(
        fix-includes
        COMMAND ${PYTHON_EXECUTABLE} ${FIX_INCLUDES_PY} < ${IWYU_OUTPUT}
        COMMENT "Fixing includes based on IWYU suggestions"
        VERBATIM)
    else()
      message(WARNING "IWYU output file (${IWYU_OUTPUT}) not found. Skipping the fix-includes target.")
    endif()
  else()
    message(WARNING "fix_includes.py not found. Skipping the fix-includes target.")
  endif()
endif()

