# Build-time analysis profile: same as the --clang build, plus Clang's -ftime-trace.
# Each TU emits a <obj>.json trace next to its .o for per-header / per-template
# compile-time attribution (feed to ClangBuildAnalyzer or build-analysis/ scripts).
# Usage: ./build.sh --profile clang-trace --released --no-production-build
include(clang.profile)

[conf]
tools.build:cxxflags+=["-ftime-trace"]
