enable_testing()
find_package(doctest REQUIRED)

add_executable(starterkit-tests)
target_sources(starterkit-tests PRIVATE ./src/main-tests.cpp ./src/starterkit-test.cpp)
target_link_libraries(starterkit-tests doctest::doctest starterkit::starterkit)
install(TARGETS starterkit-tests RUNTIME DESTINATION tests)

include(doctest)

if(EMSCRIPTEN)
  message(STATUS "Building Emscripten tests")
  add_test(NAME starterkit-tests COMMAND node ${CMAKE_CURRENT_BINARY_DIR}/starterkit-tests.js)
else()
  message(STATUS "Building native tests")
  doctest_discover_tests(starterkit-tests)
endif()

# enable compiler warnings
if(CMAKE_CXX_COMPILER_ID MATCHES "Clang" OR CMAKE_CXX_COMPILER_ID MATCHES "GNU")
  target_compile_options(starterkit-tests PUBLIC -Wall -Wpedantic -Wextra -Werror)
elseif(MSVC)
  target_compile_options(starterkit-tests PUBLIC /W4 /WX)
  target_compile_definitions(starterkit-tests PUBLIC DOCTEST_CONFIG_USE_STD_HEADERS)
endif()

if(ENABLE_TEST_COVERAGE)
  target_compile_options(starterkit-tests PUBLIC -O0 -g -fprofile-arcs -ftest-coverage)
  target_link_options(starterkit-tests PUBLIC -fprofile-arcs -ftest-coverage)
endif()
