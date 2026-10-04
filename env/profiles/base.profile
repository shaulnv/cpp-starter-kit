include(default)

[settings]
# os.id and os.glibc_version (see settings_user.yml) are passed on the command line
# (-s:a os.id=rhel) when needed, so they are not detected here.
compiler.cppstd=17

[conf]
tools.cmake.cmaketoolchain:generator=Ninja
tools.cmake.cmaketoolchain:extra_variables*={'CMAKE_EXPORT_COMPILE_COMMANDS': 'ON'}
tools.system.package_manager:mode=install
tools.system.package_manager:sudo=True
# Run test_requires-driven test steps during `conan create`.
tools.build:skip_test=False
