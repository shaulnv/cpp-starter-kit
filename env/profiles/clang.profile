include(base.profile)

[settings]
compiler=clang
compiler.version=14
compiler.libcxx=libc++

[conf]
tools.cmake.cmaketoolchain:generator=Ninja
tools.build:compiler_executables={"c": "clang", "cpp": "clang++"}
