add_library(starterkit)
target_sources(starterkit PRIVATE ./starterkit.cpp)
target_include_directories(
  starterkit
  PUBLIC $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include> #
         $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include> #
         $<INSTALL_INTERFACE:include>
  PRIVATE $<BUILD_INTERFACE:${PROJECT_BINARY_DIR}/include/starterkit> #
          $<BUILD_INTERFACE:${PROJECT_SOURCE_DIR}/include/starterkit>)
# being a cross-platform target, we enforce standards conformance on MSVC
target_compile_options(starterkit PUBLIC "$<$<COMPILE_LANG_AND_ID:CXX,MSVC>:/permissive->")
target_link_libraries(starterkit PRIVATE fmt::fmt)

# Visibility is hidden by default; the export header marks the public API for shared builds
generate_export_header(starterkit BASE_NAME starterkit EXPORT_FILE_NAME
                       ${PROJECT_BINARY_DIR}/include/starterkit/starterkit_export.h)
if(NOT BUILD_SHARED_LIBS)
  target_compile_definitions(starterkit PUBLIC STARTERKIT_STATIC_DEFINE)
endif()
# Keep symbols of statically linked dependencies out of the shared library's exports
if(BUILD_SHARED_LIBS AND CMAKE_SYSTEM_NAME STREQUAL "Linux")
  target_link_options(starterkit PRIVATE "-Wl,--exclude-libs,ALL")
endif()
starterkit_verify_hardening(starterkit)

add_library(starterkit::starterkit ALIAS starterkit)

install(
  TARGETS starterkit
  RUNTIME DESTINATION bin COMPONENT Runtime
  LIBRARY DESTINATION lib COMPONENT Runtime
  ARCHIVE DESTINATION lib COMPONENT Development)
install(
  DIRECTORY ${PROJECT_SOURCE_DIR}/include/
  DESTINATION include
  COMPONENT Development)
install(
  DIRECTORY ${PROJECT_BINARY_DIR}/include/
  DESTINATION include
  COMPONENT Development)
