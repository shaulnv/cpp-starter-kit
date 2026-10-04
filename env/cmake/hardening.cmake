# Binary hardening flags, applied globally so every object, shared library and executable inherits
# the same protection set. Linux with GCC/Clang, production builds only; local builds stay un-hardened.
# Post-build enforcement: starterkit_verify_hardening() (env/scripts/verify_hardening.sh).

option(STARTERKIT_HARDENING "Enable binary hardening (stack protector, RELRO/BIND_NOW, PIE, FORTIFY)" ON)

# POST_BUILD gate asserting a target's ELF carries the hardening set; no-op when hardening is off
# or for static archives (not ELF images).
function(starterkit_verify_hardening target)
  get_target_property(target_type ${target} TYPE)
  if(NOT STARTERKIT_HARDENING OR target_type STREQUAL "STATIC_LIBRARY")
    return()
  endif()
  add_custom_command(
    TARGET ${target}
    POST_BUILD
    COMMAND bash ${PROJECT_SOURCE_DIR}/env/scripts/verify_hardening.sh $<TARGET_FILE:${target}>
    VERBATIM
    COMMENT "Verifying ${target} binary hardening")
endfunction()

if(NOT PRODUCTION_BUILD)
  set(STARTERKIT_HARDENING OFF)
endif()

# ELF-specific flags; macOS, Windows and Emscripten builds skip hardening.
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
  set(STARTERKIT_HARDENING OFF)
endif()

if(STARTERKIT_HARDENING AND CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
  message(STATUS "starterkit: binary hardening ENABLED")

  # PIE for executables, PIC for every object so static libs fold into PIE executables and shared libs.
  include(CheckPIESupported)
  check_pie_supported(LANGUAGES C CXX)
  set(CMAKE_POSITION_INDEPENDENT_CODE ON)

  add_compile_options(-fstack-protector-strong -fstack-clash-protection)

  # Control-Flow Enforcement (CET) is x86_64-only; other targets reject the flag.
  if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|amd64|AMD64")
    add_compile_options(-fcf-protection=full)
  endif()

  # Fall back to _FORTIFY_SOURCE=2 where the toolchain rejects =3 under -Werror.
  include(CheckCXXSourceCompiles)
  set(CMAKE_REQUIRED_FLAGS "-O2 -Werror -U_FORTIFY_SOURCE -D_FORTIFY_SOURCE=3")
  check_cxx_source_compiles("#include <features.h>\nint main() { return 0; }" STARTERKIT_FORTIFY3_SUPPORTED)
  unset(CMAKE_REQUIRED_FLAGS)
  if(STARTERKIT_FORTIFY3_SUPPORTED)
    set(_sk_fortify_level 3)
  else()
    set(_sk_fortify_level 2)
  endif()
  message(STATUS "starterkit: _FORTIFY_SOURCE=${_sk_fortify_level}")

  # Optimized configs only (FORTIFY needs -O1+); -U first so a predefine doesn't trip -Werror redefinition.
  set(_sk_fortify_configs "$<OR:$<CONFIG:Release>,$<CONFIG:RelWithDebInfo>,$<CONFIG:MinSizeRel>>")
  add_compile_options("$<${_sk_fortify_configs}:-U_FORTIFY_SOURCE>"
                      "$<${_sk_fortify_configs}:-D_FORTIFY_SOURCE=${_sk_fortify_level}>")

  # full RELRO + non-exec stack
  add_link_options(-Wl,-z,relro -Wl,-z,now -Wl,-z,noexecstack)
else()
  # Turn the option OFF either way so the verify gate skips unhardened binaries.
  if(STARTERKIT_HARDENING)
    message(
      WARNING "starterkit: binary hardening requested but compiler '${CMAKE_CXX_COMPILER_ID}' is unsupported; disabling"
    )
    set(STARTERKIT_HARDENING OFF)
  else()
    message(STATUS "starterkit: binary hardening DISABLED")
  endif()
endif()
