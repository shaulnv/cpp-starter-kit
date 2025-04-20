include(default)

[settings]
compiler.cppstd=17

[conf]
tools.cmake.cmaketoolchain:generator=Ninja
tools.cmake.cmaketoolchain:extra_variables*={'CMAKE_EXPORT_COMPILE_COMMANDS': 'ON'}
tools.system.package_manager:mode=install
tools.system.package_manager:sudo=True
