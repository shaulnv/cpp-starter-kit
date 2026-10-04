#!/usr/bin/env bash
# Install a locally built DEB/RPM (default: newest main package in ./dist) and verify the
# payload landed. Works on Debian-like and RPM-like hosts; run it as root, e.g. inside a
# clean container, to prove the package installs without the build environment.
#
# Usage: install-os-package.sh [PACKAGE_FILE]
# Env:   PACKAGE_NAME (default starterkit), INSTALL_PREFIX (default /usr/local/<PACKAGE_NAME>),
#        VERIFY_BINARY (default starterkit-cli, resolved under <prefix>/bin)

set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO} failed (exit $?)" >&2' ERR

package_name="${PACKAGE_NAME:-starterkit}"
install_prefix="${INSTALL_PREFIX:-/usr/local/${package_name}}"
verify_binary="${VERIFY_BINARY:-starterkit-cli}"
root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

pkg="${1:-}"
if [[ -z $pkg ]]; then
  ext=rpm
  command -v apt-get >/dev/null && ext=deb
  # Newest first; skip the debug-symbols package, which installs no binaries. Matching the
  # basename prefix (not a substring) keeps main packages from branches named '...dbgsym'.
  while IFS= read -r f; do
    case "$(basename "$f")" in
      "${package_name}"-debuginfo-* | "${package_name}"-dbgsym_*) continue ;;
    esac
    pkg="$f"
    break
  done < <(ls -t "$root_dir"/dist/"${package_name}"[-_]*."$ext" 2>/dev/null)
fi
[[ -f $pkg ]] || {
  echo "ERROR: no package found (build one with ./build.sh --package)" >&2
  exit 1
}
pkg=$(readlink -f "$pkg")

echo ">>> Installing $pkg"
if [[ $pkg == *.deb ]]; then
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y "$pkg"
elif command -v dnf >/dev/null; then
  dnf install -y "$pkg"
else
  yum install -y "$pkg"
fi

# A debug-only or empty package installs "successfully" without the payload.
if [[ ! -x ${install_prefix}/bin/${verify_binary} ]]; then
  echo "ERROR: ${install_prefix}/bin/${verify_binary} missing after install" >&2
  exit 1
fi
echo "OK: $(basename "$pkg") installed, ${verify_binary} present."
