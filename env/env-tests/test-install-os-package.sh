#!/usr/bin/env bash
# Install the packages in dist/ inside clean containers of every supported distro, to prove
# they install on a machine that has none of the build environment.
#
# Usage: test-install-os-package.sh [--dry-run]
#   --dry-run   print the docker commands without running them

set -uo pipefail

usage() { sed -n '2,6p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; }

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

docker_runner="docker"
docker info &>/dev/null || docker_runner="sudo docker"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      docker_runner="echo $docker_runner"
      shift
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

# name -> "image package-kind". An image is skipped when dist/ has no package of its kind.
declare -A images=(
  [U22]="ubuntu:22.04 deb"
  [U24]="ubuntu:24.04 deb"
  [Deb12]="debian:bookworm-slim deb"
  [Rhel9]="redhat/ubi9 rpm"
  [Aws]="amazonlinux:2023 rpm"
)

failed=()
for name in "${!images[@]}"; do
  read -r image kind <<<"${images[$name]}"
  if ! compgen -G "$root_dir/dist/*.$kind" >/dev/null; then
    echo "--- ${name}: skipped, no .$kind in dist/"
    continue
  fi
  echo "--- ${name} (${image})"
  $docker_runner run --rm -v "$root_dir:/v:ro" --name "env-test-${name}" "$image" \
    /v/env/scripts/install-os-package.sh || failed+=("$name")
done

echo "--- Summary"
if [[ ${#failed[@]} -eq 0 ]]; then
  echo "All installs succeeded."
else
  echo "Failed: ${failed[*]}"
  exit 1
fi
