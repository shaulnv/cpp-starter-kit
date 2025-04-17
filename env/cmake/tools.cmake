# this file contains a list of tools that can be activated and downloaded on-demand each tool is enabled during
# configuration by passing an additional `-DUSE_<TOOL>=<VALUE>` argument to CMake

# only activate tools for top level project
if(NOT PROJECT_SOURCE_DIR STREQUAL CMAKE_SOURCE_DIR)
  return()
endif()

include(${CMAKE_CURRENT_LIST_DIR}/CPM.cmake)
include(${CMAKE_CURRENT_LIST_DIR}/helpers.cmake)

function(get_libcxx_dir)
  get_filename_component(CLANG_REAL_PATH "${CMAKE_CXX_COMPILER}" REALPATH)
  get_filename_component(CLANG_INSTALL_DIR "${CLANG_REAL_PATH}" DIRECTORY)
  get_filename_component(CLANG_INSTALL_DIR "${CLANG_INSTALL_DIR}" DIRECTORY)
  set(LIBCXX_DIR "${CLANG_INSTALL_DIR}/include/c++/v1" PARENT_SCOPE)
endfunction()

if(USE_CLANG_TIDY)
  notice_message("Running clang-tidy as part of build - WILL SLOW DOWN BUILD")
  get_libcxx_dir()
  set(CMAKE_CXX_CLANG_TIDY
      clang-tidy -p ${CMAKE_BINARY_DIR} --fix -extra-arg=-I${LIBCXX_DIR}
      CACHE STRING "clang-tidy cmd")
endif()

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
