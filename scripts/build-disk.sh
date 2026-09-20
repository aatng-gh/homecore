#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
podman_cmd=()
# shellcheck disable=SC1091
. config/versions.env
# shellcheck disable=SC1091
. scripts/lib/podman.sh

image=${1:-ghcr.io/aatng-gh/homecore:stable}
output_dir=${HOMECORE_DISK_OUTPUT_DIR:-${repo_dir}/build/disk}

[[ $# -le 1 ]] || {
  echo "usage: $0 [registry/image:tag]" >&2
  exit 1
}
[[ ${image} =~ ^[^[:space:]@]+:[^[:space:]:]+$ ]] || {
  echo "image must be a tagged registry reference" >&2
  exit 1
}
command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }
command -v xz >/dev/null 2>&1 || { echo "xz is required" >&2; exit 1; }
[[ $(uname -m) == x86_64 ]] || {
  echo "Homecore disk builds currently require an x86-64 host" >&2
  echo "run 'just image' for local ARM validation; CI publishes the x86-64 image" >&2
  exit 1
}
homecore_podman_init

mkdir -p "${output_dir}"
output_dir=$(cd "${output_dir}" && pwd)

"${podman_cmd[@]}" pull --arch amd64 "${image}"
"${podman_cmd[@]}" pull --arch amd64 "${BOOTC_IMAGE_BUILDER_IMAGE}"

"${podman_cmd[@]}" run --rm --arch amd64 --privileged \
  --security-opt label=type:unconfined_t \
  --volume "${output_dir}:/output" \
  --volume /var/lib/containers/storage:/var/lib/containers/storage \
  "${BOOTC_IMAGE_BUILDER_IMAGE}" \
  --chown "$(id -u):$(id -g)" \
  --output /output \
  --progress verbose \
  --rootfs xfs \
  --target-arch amd64 \
  --type raw \
  "${image}"

raw=${output_dir}/image/disk.raw
compressed_raw=${raw}.xz
[[ -s ${raw} ]] || { echo "builder did not produce ${raw}" >&2; exit 1; }
xz --threads=0 --force "${raw}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
else
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
fi

raw_sha=$(sha256 "${compressed_raw}")
printf '%s  %s\n' "${raw_sha}" "image/disk.raw.xz" >"${output_dir}/SHA256SUMS"

echo "built Homecore raw disk under ${output_dir}"
