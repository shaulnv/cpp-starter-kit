#!/usr/bin/env bash
# Verify a freshly built DEB/RPM needs no glibc/libstdc++/libcxxabi symbol newer than the
# runtime it ships into. A dependency built on a newer container than the target runtime
# fails at load time with "version `GLIBC_2.xx' not found"; this catches it before release.
#
# The package is extracted, not installed, so the build host is left untouched. Every ELF
# executable under bin/ and shared object under lib/ is checked, because static dependencies
# can leak newer symbols into any of them.
#
# The ceilings are what the *runtime* image's libc.so.6 / libstdc++.so.6 export. Raise one
# only together with the runtime image.
#
# Usage (repo root): ./env/scripts/smoke-test-package.sh [DIST_DIR]
# Env:
#   RUNTIME_NAME       ceiling set to use (default: detected from /etc/os-release)
#   MAX_GLIBC / MAX_GLIBCXX / MAX_CXXABI   override the table, e.g. MAX_GLIBC=2.31
#   PACKAGE_NAME       package basename (default: starterkit)
#   INSTALL_PREFIX     prefix inside the package (default: usr/local/<PACKAGE_NAME>)

set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO} failed (exit $?)" >&2' ERR
[[ ${ENABLE_DEBUG:-false} == "true" ]] && set -x

package_name="${PACKAGE_NAME:-starterkit}"
install_prefix="${INSTALL_PREFIX:-usr/local/${package_name}}"

detect_runtime_name() {
  # shellcheck source=/dev/null
  . /etc/os-release
  case "$ID:$VERSION_ID" in
    ubuntu:22.04) echo ubuntu22.04 ;;
    ubuntu:24.04) echo ubuntu24.04 ;;
    debian:12) echo debian12 ;;
    amzn:2023) echo amazonlinux_2023 ;;
    rhel:9.* | rocky:9.* | almalinux:9.*) echo rhel9 ;;
    *)
      echo "ERROR: no ABI ceiling for '$ID $VERSION_ID'; set RUNTIME_NAME or MAX_GLIBC/MAX_GLIBCXX/MAX_CXXABI" >&2
      return 2
      ;;
  esac
}

# Highest symbol version each runtime exports.
declare -A GLIBC=([ubuntu22.04]=2.35 [ubuntu24.04]=2.39 [debian12]=2.36 [amazonlinux_2023]=2.34 [rhel9]=2.34)
declare -A GLIBCXX=([ubuntu22.04]=3.4.30 [ubuntu24.04]=3.4.33 [debian12]=3.4.30 [amazonlinux_2023]=3.4.33 [rhel9]=3.4.30)
declare -A CXXABI=([ubuntu22.04]=1.3.13 [ubuntu24.04]=1.3.15 [debian12]=1.3.13 [amazonlinux_2023]=1.3.15 [rhel9]=1.3.13)

runtime_name="${RUNTIME_NAME:-}"
if [[ -z ${MAX_GLIBC:-} || -z ${MAX_GLIBCXX:-} || -z ${MAX_CXXABI:-} ]]; then
  [[ -n $runtime_name ]] || runtime_name=$(detect_runtime_name)
  MAX_GLIBC="${MAX_GLIBC:-${GLIBC[$runtime_name]:-}}"
  MAX_GLIBCXX="${MAX_GLIBCXX:-${GLIBCXX[$runtime_name]:-}}"
  MAX_CXXABI="${MAX_CXXABI:-${CXXABI[$runtime_name]:-}}"
fi
runtime_name="${runtime_name:-custom}"
if [[ -z $MAX_GLIBC || -z $MAX_GLIBCXX || -z $MAX_CXXABI ]]; then
  echo "ERROR: incomplete ABI ceiling for '$runtime_name'" >&2
  exit 2
fi

dist_dir="${1:-./dist}"
[[ -d $dist_dir ]] || {
  echo "ERROR: dist dir '$dist_dir' missing" >&2
  exit 1
}

shopt -s nullglob
if command -v dpkg-deb >/dev/null && [[ -z ${PACKAGE_EXT:-} ]]; then
  PACKAGE_EXT=deb
elif [[ -z ${PACKAGE_EXT:-} ]]; then
  PACKAGE_EXT=rpm
fi
mains=()
for f in "$dist_dir"/"${package_name}"[-_]*."$PACKAGE_EXT"; do
  # Match the debug-symbols package by basename prefix: the version field embeds the branch
  # name, so a substring match would also drop a main package from a branch named '...dbgsym'.
  case "$(basename "$f")" in
    "${package_name}"-debuginfo-* | "${package_name}"-dbgsym_*) continue ;;
  esac
  mains+=("$f")
done
if [[ ${#mains[@]} -ne 1 ]]; then
  echo "ERROR: expected exactly one main .$PACKAGE_EXT in $dist_dir, found ${#mains[@]}: ${mains[*]:-}" >&2
  exit 1
fi
pkg="${mains[0]}"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
abs_pkg=$(readlink -f "$pkg") # rpm2cpio runs after cd, so a relative path would break
case "$pkg" in
  *.rpm) (cd "$tmp" && rpm2cpio "$abs_pkg" | cpio -idm --quiet) ;;
  *.deb) dpkg-deb -x "$abs_pkg" "$tmp" ;;
esac

install_root="$tmp/$install_prefix"
[[ -d $install_root ]] || {
  echo "ERROR: expected $install_root in extracted package" >&2
  exit 1
}

# -type f skips library symlinks so each real file is reported once.
mapfile -d '' to_check < <(
  find "$install_root/bin" "$install_root/lib" -maxdepth 1 -type f \( -executable -o -name '*.so*' \) -print0 2>/dev/null | sort -z
)
if [[ ${#to_check[@]} -eq 0 ]]; then
  echo "ERROR: no executables/shared-objects under $install_root" >&2
  exit 1
fi

# ver_le X Y: true iff X <= Y in version order.
ver_le() { [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -uV | head -1)" == "$1" ]]; }

# max_symbol_version BIN PREFIX -> highest PREFIX_x.y[.z] referenced by BIN's dynamic symbols.
max_symbol_version() {
  local syms
  syms=$(objdump -T "$1" 2>/dev/null) || return 0 # a static binary has no dynamic symbols
  # grep exits 1 when the binary references none of this family, which is a valid "none".
  grep -oE "$2_[0-9]+\.[0-9]+(\.[0-9]+)?" <<<"$syms" | sort -uV | tail -1 || test $? -eq 1
}

echo "===== ABI smoke test: $runtime_name ====="
echo "  package: $(basename "$pkg")"
echo "  ceiling: GLIBC_$MAX_GLIBC GLIBCXX_$MAX_GLIBCXX CXXABI_$MAX_CXXABI"

fail=0
for bin in "${to_check[@]}"; do
  label="${bin#"$install_root"/}"
  bad=()
  report=""
  for kind in GLIBC:"$MAX_GLIBC" GLIBCXX:"$MAX_GLIBCXX" CXXABI:"$MAX_CXXABI"; do
    prefix="${kind%%:*}"
    ceiling="${kind#*:}"
    found=$(max_symbol_version "$bin" "$prefix")
    report+=" $prefix=${found:-<none>}"
    if [[ -n $found ]] && ! ver_le "$found" "${prefix}_${ceiling}"; then
      bad+=("$found > ${prefix}_${ceiling}")
    fi
  done
  if [[ ${#bad[@]} -eq 0 ]]; then
    printf '  %-30s%s OK\n' "$label" "$report"
  else
    printf '  %-30s%s FAIL\n' "$label" "$report"
    printf '      %s\n' "${bad[@]}" >&2
    fail=1
  fi
done

if [[ $fail -ne 0 ]]; then
  cat >&2 <<MSG

To fix, build on a container whose glibc/libstdc++ match the runtime (no upgrade in the build
image), including for prebuilt Conan packages. Only as a last resort raise the runtime image
and this ceiling together.
MSG
  exit 1
fi
echo "PASS: all binaries are within the $runtime_name runtime ceiling."
