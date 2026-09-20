#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck disable=SC1091
. "${repo_dir}/config/versions.env"

for name in \
  FCOS_CNI_RPM \
  FCOS_FIREWALLD_RPM \
  NOMAD_VERSION \
  NOMAD_ASSET \
  NOMAD_LINUX_AMD64_SHA256 \
  NOMAD_PODMAN_DRIVER_VERSION \
  NOMAD_PODMAN_DRIVER_ASSET \
  NOMAD_PODMAN_DRIVER_SHA256 \
  TAILSCALE_ASSET \
  TAILSCALE_SHA256; do
  printf '%s=%s\n' "${name}" "${!name}"
done
