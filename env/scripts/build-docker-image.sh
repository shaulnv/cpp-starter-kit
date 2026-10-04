#!/usr/bin/env bash
# Build a runtime Docker image from a package in dist/ (see env/docker/Dockerfile).
#
# Usage: build-docker-image.sh [--package FILE] [--tag NAME:TAG] [--base IMAGE]
#   --package   .deb/.rpm to install (default: newest main package in dist/)
#   --tag       image tag (default: <PACKAGE_NAME>:local)
#   --base      base image (default: debian:bookworm-slim for .deb, amazonlinux:2023 for .rpm)
# Env: PACKAGE_NAME (default starterkit), VERIFY_BINARY (default starterkit-cli)

set -Eeuo pipefail
trap 'echo "ERROR: ${BASH_SOURCE[0]}:${LINENO} failed (exit $?)" >&2' ERR

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
package_name="${PACKAGE_NAME:-starterkit}"
verify_binary="${VERIFY_BINARY:-starterkit-cli}"
pkg=""
tag=""
base=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package)
      pkg="$2"
      shift 2
      ;;
    --tag)
      tag="$2"
      shift 2
      ;;
    --base)
      base="$2"
      shift 2
      ;;
    -h | --help)
      sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "ERROR: unknown option: $1" >&2
      exit 1
      ;;
  esac
done

if [[ -z $pkg ]]; then
  # Skip the debug-symbols package by basename prefix; it carries no binaries.
  while IFS= read -r f; do
    case "$(basename "$f")" in
      "${package_name}"-debuginfo-* | "${package_name}"-dbgsym_*) continue ;;
    esac
    pkg="$f"
    break
  done < <(ls -t "$root_dir"/dist/"${package_name}"[-_]*.deb "$root_dir"/dist/"${package_name}"[-_]*.rpm 2>/dev/null)
fi
[[ -f $pkg ]] || {
  echo "ERROR: no package found (build one with ./build.sh --package)" >&2
  exit 1
}
pkg=$(readlink -f "$pkg")

if [[ -z $base ]]; then
  case "$pkg" in
    *.deb) base="debian:bookworm-slim" ;;
    *.rpm) base="public.ecr.aws/amazonlinux/amazonlinux:2023" ;;
    *)
      echo "ERROR: package must be .deb or .rpm: $pkg" >&2
      exit 1
      ;;
  esac
fi

# Docker COPY only sees the build context, so stage the package in a throwaway one.
context=$(mktemp -d)
trap 'rm -rf "$context"' EXIT
cp "$pkg" "$context/"
cp "$root_dir/env/docker/Dockerfile" "$context/"

tag="${tag:-${package_name}:local}"

docker build \
  --build-arg BASE_IMAGE="$base" \
  --build-arg PACKAGE_NAME="$package_name" \
  --build-arg VERIFY_BINARY="$verify_binary" \
  --build-arg PACKAGE_FILE="$(basename "$pkg")" \
  -t "$tag" "$context"
echo "Built image: $tag (from $(basename "$pkg"))"
