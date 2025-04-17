include(clang.profile)

[conf]
tools.cmake.cmaketoolchain:extra_variables*={'USE_CLANG_TIDY': 'ON'}
