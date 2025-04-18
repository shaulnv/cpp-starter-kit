cmake_minimum_required(VERSION 3.24...3.30)

project(
  starterkit
  VERSION 0.0.1
  DESCRIPTION "C++ starter kit"
  HOMEPAGE_URL "https://github.com/shaulnv/cpp-starter-kit"
  LANGUAGES CXX C)

# project options
option(BUILD_SHARED_LIBS "Build using shared libraries" OFF)
option(ENABLE_TEST_COVERAGE "Enable test coverage" OFF)
option(CTEST_OUTPUT_ON_FAILURE "On test failure, print out its full output" ON)
option(USE_CLANG_TIDY "Use clang-tidy" OFF)

# unfortunately, it is not always worked from here
# so this is set at env/profiles/base.profile
# option(CMAKE_EXPORT_COMPILE_COMMANDS "Export compile commands" ON)

# set(CMAKE_CXX_STANDARD 17) # this is set at env/profiles/base.profile
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)

# cmake modules
include(CTest)
include(env/cmake/CPM.cmake)
include(env/cmake/PreventInSourceBuilds.cmake)
include(env/cmake/tools.cmake)
include(env/cmake/helpers.cmake)

# Prefer using conanfile.py('requires' clause) for import of 3rd party projects
# If you only have a CMake based dependency, you can use CPM to import it
# Example:
# CPMAddPackage(
#   NAME ibis
#   GITHUB_REPOSITORY mellanox/ibis_tools
#   GIT_TAG release.v16.0.0
# )

# Create config.h from config.h.in
configure_file(./src/config.h.in ${PROJECT_BINARY_DIR}/starterkit/config.h)

# Configure version.h
configure_file(./src/version.h.in ${PROJECT_BINARY_DIR}/starterkit/version.h)

add_subdirectory(src)
add_subdirectory(cli)
add_subdirectory(tests)
