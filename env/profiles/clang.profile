{% set compiler, version, compiler_exe = detect_api.detect_clang_compiler() %}

include(base.profile)

[settings]
compiler={{ compiler }}
compiler.version={{ detect_api.default_compiler_version(compiler, version) }}

[conf]
# Pin the C/C++ drivers to the detected clang so CMake does not fall back to the
# system default; the C++ driver is derived from it (clang -> clang++, clang-22 -> clang++-22).
tools.build:compiler_executables={"c": "{{ compiler_exe }}", "cpp": "{{ compiler_exe.replace('clang', 'clang++', 1) }}"}
