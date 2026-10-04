#!/usr/bin/env bash
# Verify a starterkit ELF artifact carries the binary hardening set (see
# env/cmake/hardening.cmake): PIE (DYN), full RELRO + BIND_NOW, non-executable stack and
# stack protector. FORTIFY is advisory (its _chk symbols only appear in optimized builds
# that actually use a fortifiable libc call). Uses only readelf (present in every CI
# image). Run as a POST_BUILD step on each library and cli binary.
set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO}: command failed (exit $?)" >&2' ERR

bin="${1:?usage: $0 <path-to-elf>}"
name="$(basename "$bin")"
fail=0

hdr="$(readelf -hlW "$bin")"
dyn="$(readelf -dW "$bin" 2>/dev/null || true)"
syms="$(readelf -sW "$bin" 2>/dev/null || true)"

check() { # check <description> <ok:0|1>
  if [[ $2 == "1" ]]; then
    echo "  OK   : $1"
  else
    echo "  FAIL : $1" >&2
    fail=1
  fi
}

# PIE: a shared object (.so) and a PIE executable are both ELF type DYN; a non-PIE
# executable is EXEC.
grep -qE '^[[:space:]]*Type:[[:space:]]*DYN' <<<"$hdr" && pie=1 || pie=0
check "PIE / position-independent (ELF type DYN)" "$pie"

# Full RELRO = a GNU_RELRO segment plus BIND_NOW (eager binding).
grep -q "GNU_RELRO" <<<"$hdr" && relro=1 || relro=0
check "RELRO segment (GNU_RELRO)" "$relro"
{ grep -q "BIND_NOW" <<<"$dyn" || grep -qE "FLAGS_1.*NOW" <<<"$dyn"; } && now=1 || now=0
check "BIND_NOW (full RELRO)" "$now"

# Non-executable stack: GNU_STACK program header must not carry the 'E' (execute) flag.
# readelf -W prints offsets/addresses as lowercase hex, so an uppercase 'E' anywhere on the
# GNU_STACK line can only be the execute flag. An absent GNU_STACK defaults to non-exec.
gnu_stack_line="$(grep "GNU_STACK" <<<"$hdr" | head -1)"
if [[ -n $gnu_stack_line && $gnu_stack_line == *E* ]]; then
  noexec=0
else
  noexec=1
fi
check "non-executable stack (GNU_STACK without E)" "$noexec"

# Stack protector: __stack_chk_fail must be referenced.
grep -q "__stack_chk_fail" <<<"$syms" && ssp=1 || ssp=0
check "stack protector (__stack_chk_fail)" "$ssp"

# FORTIFY: advisory/informational — _chk symbols appear only in optimized builds that call a
# fortifiable libc function; the result is reported (OK / note) and the build proceeds.
if grep -qE "__(memcpy|memmove|memset|sprintf|snprintf|vsnprintf|printf|fprintf|strcpy|strncpy|strcat|strncat|read|fread)_chk" <<<"$syms"; then
  echo "  OK   : FORTIFY (_chk symbols present)"
else
  echo "  note : no _chk symbols (expected for Debug/-O0 or no fortifiable calls)"
fi

if ((fail)); then
  echo "ERROR: $name is missing required hardening (see FAIL lines above)." >&2
  exit 1
fi
echo "OK: $name passes hardening checks (PIE/RELRO/BIND_NOW/noexecstack/stack-protector)."
