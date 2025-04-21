find_package(fmt REQUIRED)

add_library(starterkit)
target_sources(starterkit PRIVATE ./starterkit.cpp)
target_include_directories(
  starterkit
  PUBLIC $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}> #
         $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> #
         $<INSTALL_INTERFACE:include>
  PRIVATE $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/starterkit> #
          $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include/starterkit>)
# being a cross-platform target, we enforce standards conformance on MSVC
target_compile_options(starterkit PUBLIC "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/permissive->")
target_link_libraries(starterkit PRIVATE fmt::fmt)
add_library(starterkit::starterkit ALIAS starterkit)

install(TARGETS starterkit)
install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/ DESTINATION include)
install(DIRECTORY ${PROJECT_BINARY_DIR}/starterkit/ DESTINATION include/starterkit)

# Set target properties to prefer static linking
set_target_properties(starterkit PROPERTIES
    LINK_SEARCH_START_STATIC ON
    LINK_SEARCH_END_STATIC ON
)

###
set(CMAKE_SHARED_LINKER_FLAGS "")
set(CMAKE_C_FLAGS " -static-libgcc -static-libstdc++")
set(CMAKE_CXX_FLAGS " -static-libgcc -static-libstdc++")
add_library(starterkit-shared SHARED)
target_sources(starterkit-shared PRIVATE ./starterkit.cpp)
target_include_directories(
  starterkit-shared
  PUBLIC $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}> #
         $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> #
         $<INSTALL_INTERFACE:include>
  PRIVATE $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/starterkit> #
          $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include/starterkit>)
# being a cross-platform target, we enforce standards conformance on MSVC
target_compile_options(starterkit-shared PUBLIC "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/permissive->")
target_link_libraries(starterkit-shared PRIVATE fmt::fmt)
add_library(starterkit-shared::starterkit-shared ALIAS starterkit-shared)

install(TARGETS starterkit-shared)
install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/ DESTINATION include)
install(DIRECTORY ${PROJECT_BINARY_DIR}/starterkit/ DESTINATION include/starterkit)

# Set target properties to prefer static linking
set_target_properties(starterkit-shared PROPERTIES
    LINK_SEARCH_START_STATIC ON
    LINK_SEARCH_END_STATIC ON
)

# MAGIC (don't work): -Wl,-Bstatic -lc -lm -Wl,-Bdynamic
