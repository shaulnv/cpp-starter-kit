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
  set(LIBCXX_DIR
      "${CLANG_INSTALL_DIR}/include/c++/v1"
      PARENT_SCOPE)
endfunction()

if(USE_CLANG_TIDY)
  notice_message("Running clang-tidy as part of build - WILL SLOW DOWN BUILD")
  get_libcxx_dir()
  # Module flags keep clang-tidy off C++ modules, which fail to build under it.
  set(CMAKE_CXX_CLANG_TIDY
      clang-tidy
      -p
      ${CMAKE_BINARY_DIR} # compilation database from the build directory
      --fix # apply automatic fixes where possible
      --fix-errors # best effort: keep fixing past errors
      --fix-notes # best effort: apply fixes attached to notes
      -extra-arg=-I${LIBCXX_DIR}
      -extra-arg=-fno-modules
      -extra-arg=-fno-module-maps
      -extra-arg=--driver-mode=g++
      CACHE STRING "clang-tidy cmd")
endif()
