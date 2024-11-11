find_package(fmt REQUIRED)
find_package(cxxopts REQUIRED)

add_executable(starterkit-cli)
target_sources(starterkit-cli PRIVATE src/main-cli.cpp)
set_target_properties(starterkit-cli PROPERTIES OUTPUT_NAME "starterkit")
target_link_libraries(starterkit-cli PRIVATE starterkit::starterkit cxxopts::cxxopts fmt::fmt)
install_compile_commands_json(starterkit-cli)
install(TARGETS starterkit-cli)
