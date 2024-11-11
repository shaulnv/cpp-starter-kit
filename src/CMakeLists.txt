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
install_compile_commands_json(starterkit)

install(TARGETS starterkit)
install(DIRECTORY ${PROJECT_SOURCE_DIR}/include/ DESTINATION include)
install(DIRECTORY ${PROJECT_BINARY_DIR}/starterkit/ DESTINATION include/starterkit)
