cmake_minimum_required(VERSION 3.24...3.30)

# Version must be resolved before project() so VERSION can come from the environment / command line
include(env/cmake/version.cmake)
set_project_version()

project(
  starterkit
  VERSION ${STARTERKIT_VERSION_SEMANTIC}
  DESCRIPTION "C++ starter kit"
  HOMEPAGE_URL "https://github.com/shaulnv/cpp-starter-kit"
  LANGUAGES CXX C)

# project options
option(BUILD_SHARED_LIBS "Build using shared libraries" OFF)
# Also honored by Conan's CMakeToolchain when tools.build:skip_test=True
option(BUILD_TESTING "Build the testing tree" ON)
option(ENABLE_TEST_COVERAGE "Enable test coverage" OFF)
option(CTEST_OUTPUT_ON_FAILURE "On test failure, print out its full output" ON)
option(USE_CLANG_TIDY "Use clang-tidy" OFF)
option(CMAKE_EXPORT_COMPILE_COMMANDS "Export compile commands" ON)
option(PRODUCTION_BUILD "Production build (all optimizations enabled)" ON)
option(STARTERKIT_STATIC_CXX_RUNTIME "Link the C++ runtime statically into the executables (GCC)" OFF)

# C++ standard keep in sync with 'compiler.cppstd=' at env/profiles/base.profile this is set also in here so a CMake
# consumer of this project will get it automatically
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_C_VISIBILITY_PRESET hidden)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
# Modules are unused, and their dependency scan breaks clang-tidy
set(CMAKE_CXX_SCAN_FOR_MODULES OFF)

# LTO: on for optimized production builds, off for Debug and non-production builds
include(CheckIPOSupported)
check_ipo_supported(RESULT is_ipo_supported OUTPUT ipo_unsupported_reason)
if(is_ipo_supported)
  if(CMAKE_BUILD_TYPE STREQUAL "Debug" OR NOT PRODUCTION_BUILD)
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION OFF)
  else()
    set(CMAKE_INTERPROCEDURAL_OPTIMIZATION ON)
  endif()
else()
  message(STATUS "LTO disabled: ${ipo_unsupported_reason}")
endif()

# RPATH: Set up runtime path (rpath) handling for shared libraries rpath specifies directories to search for dependent
# shared libraries (.so files) at runtime '$ORIGIN' ensures the rpath is set relative to the binary's location We set it
# to standard locations: executables can be anywhere, but standard install is in bin/ shared libraries are in lib/,
# ../lib/ or right by the executable
set(CMAKE_INSTALL_RPATH $ORIGIN $ORIGIN/lib $ORIGIN/../lib)
set(CMAKE_BUILD_RPATH $ORIGIN $ORIGIN/lib $ORIGIN/../lib)

# cmake modules
include(CTest)
include(GenerateExportHeader)
include(env/cmake/CPM.cmake)
include(env/cmake/PreventInSourceBuilds.cmake)
include(env/cmake/tools.cmake)
include(env/cmake/hardening.cmake)
include(env/cmake/reduced_debug.cmake)

# Prefer using conanfile.py('requires' clause) for import of 3rd party projects If you only have a CMake based
# dependency, use CPM to import it See: https://github.com/cpm-cmake/CPM.cmake for usage Example: CPMAddPackage( NAME
# ibis GITHUB_REPOSITORY mellanox/ibis_tools GIT_TAG release.v16.0.0 )

# Global compiler flags; the latest flag takes precedence
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
  # -Wno-missing-field-initializers: it also fires on designated initializers,
  # https://github.com/llvm/llvm-project/issues/68933
  add_compile_options(-Wall -Wpedantic -Wextra -Werror -Wno-missing-field-initializers)
  # Tolerate GCC-only groups in '#pragma GCC diagnostic' blocks that clang doesn't recognize
  if(CMAKE_CXX_COMPILER_ID MATCHES "Clang")
    add_compile_options(-Wno-unknown-warning-option)
  endif()
  # GCC 12 reports a false overlapping copy in libstdc++'s char_traits.h for std::string operator+, at -O3 only
  if(CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
    add_compile_options($<$<CONFIG:Release>:-Wno-restrict>)
  endif()
endif()

# Headers generated into the build tree (config.h, version.h, <lib>_export.h) live under include/starterkit
include_directories(${PROJECT_BINARY_DIR}/include)

# Common dependencies (to not call find_package() more than once)
find_package(fmt REQUIRED)

add_subdirectory(src)
add_subdirectory(cli)
if(BUILD_TESTING)
  add_subdirectory(tests)
endif()

# Packaging sets STARTERKIT_OS_PACKAGE_NAME, which version.h embeds
include(env/cmake/cpack.cmake)

# At the end, after all subdirs got their chance to set variables which land in the generated headers
string(TIMESTAMP STARTERKIT_BUILD_TIMESTAMP "%Y-%m-%d %H:%M:%S" UTC)
message(STATUS "Configure timestamp: ${STARTERKIT_BUILD_TIMESTAMP}")
configure_file(./src/config.h.in ${PROJECT_BINARY_DIR}/include/starterkit/config.h)
configure_file(./src/version.h.in ${PROJECT_BINARY_DIR}/include/starterkit/version.h)
