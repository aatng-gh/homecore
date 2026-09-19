#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
image_ref=${HOMECORE_LOCAL_IMAGE:-localhost/homecore:dev}
podman_cmd=()
# shellcheck disable=SC1091
. scripts/lib/podman.sh

command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }
homecore_podman_init
build_args=()
while IFS= read -r build_arg; do
  build_args+=(--build-arg "${build_arg}")
done < <(scripts/build-args.sh)

"${podman_cmd[@]}" build --platform linux/amd64 \
  "${build_args[@]}" \
  --file "${repo_dir}/Containerfile" \
  --label org.opencontainers.image.title=Homecore \
  --label org.opencontainers.image.source=https://github.com/aatng-gh/homecore \
  --tag "${image_ref}" "${repo_dir}"

for executable in \
  /usr/bin/nomad \
  /usr/bin/tailscale \
  /usr/bin/tailscaled \
  /usr/libexec/nomad/plugins/nomad-driver-podman \
  /usr/libexec/cni/bridge \
  /usr/bin/firewall-cmd; do
  "${podman_cmd[@]}" run --rm --arch amd64 \
    --entrypoint /usr/bin/test "${image_ref}" -x "${executable}"
done
echo "built and inspected ${image_ref}"
