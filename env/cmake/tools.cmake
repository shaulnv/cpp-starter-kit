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
