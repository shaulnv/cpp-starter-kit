# Reduced debug info for fast local iteration.
#
# RelWithDebInfo spends most of its compile CPU in the -g backend. -g1 emits line tables only and
# -gsplit-dwarf keeps debug info out of the link, for faster builds and links. Opt-in; shipped
# packages keep their full debug info.

option(STARTERKIT_REDUCED_DEBUG "Reduced debug info (-g1 + split-DWARF) for fast local iteration" OFF)

if(STARTERKIT_REDUCED_DEBUG)
  # One quoted genex per flag: a ';'-separated list inside a single genex splits into malformed arguments.
  # Applied after CMAKE_CXX_FLAGS_RELWITHDEBINFO, so -g1 overrides its default -g.
  add_compile_options("$<$<CONFIG:RelWithDebInfo>:-g1>" "$<$<CONFIG:RelWithDebInfo>:-gsplit-dwarf>")
  add_link_options("$<$<CONFIG:RelWithDebInfo>:-gsplit-dwarf>")
endif()
