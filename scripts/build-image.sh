#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
image_ref=${HOMECORE_LOCAL_IMAGE:-localhost/homecore:dev}

command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }
build_args=()
while IFS= read -r build_arg; do
  build_args+=(--build-arg "${build_arg}")
done < <(scripts/build-args.sh)

podman build --platform linux/amd64 \
  "${build_args[@]}" \
  --label org.opencontainers.image.title=Homecore \
  --label org.opencontainers.image.source=https://github.com/aatng-gh/homecore \
  --tag "${image_ref}" .

podman run --rm --arch amd64 "${image_ref}" sh -ceu '
  test -x /usr/bin/nomad
  test -x /usr/bin/tailscale
  test -x /usr/bin/tailscaled
  test -x /usr/libexec/nomad/plugins/nomad-driver-podman
  test -x /usr/libexec/cni/bridge
  test -x /usr/bin/firewall-cmd
'
echo "built and inspected ${image_ref}"
