#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
image_ref=${HOMECORE_LOCAL_IMAGE:-localhost/homecore:dev}
build_args=()
while IFS= read -r build_arg; do
  build_args+=(--build-arg "${build_arg}")
done < <(scripts/build-args.sh)

case $(uname -s) in
  Darwin)
    command -v container >/dev/null 2>&1 || {
      echo "Apple Container is required on macOS" >&2
      exit 1
    }
    build_cmd=(container build --platform linux/amd64)
    run_cmd=(container run --rm --platform linux/amd64)
    ;;
  Linux)
    podman_cmd=()
    # shellcheck disable=SC1091
    . scripts/lib/podman.sh
    command -v podman >/dev/null 2>&1 || { echo "Podman is required on Linux" >&2; exit 1; }
    homecore_podman_init
    build_cmd=("${podman_cmd[@]}" build --platform linux/amd64)
    run_cmd=("${podman_cmd[@]}" run --rm --arch amd64)
    ;;
  *)
    echo "unsupported build host: $(uname -s)" >&2
    exit 1
    ;;
esac

"${build_cmd[@]}" \
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
  "${run_cmd[@]}" \
    --entrypoint /usr/bin/test "${image_ref}" -x "${executable}"
done
echo "built and inspected ${image_ref}"
