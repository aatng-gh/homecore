#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
podman_cmd=()
# shellcheck disable=SC1091
. config/versions.env
# shellcheck disable=SC1091
. scripts/lib/podman.sh

source_image=${1:-}
update_image=${2:-}
output_dir=${HOMECORE_DISK_OUTPUT_DIR:-${repo_dir}/build/disks}

[[ ${source_image} =~ ^[^[:space:]@]+@sha256:[0-9a-f]{64}$ ]] || {
  echo "usage: $0 <registry/image@sha256:digest> <registry/image:update-tag>" >&2
  exit 1
}
[[ ${update_image} =~ ^[^[:space:]@]+:[^[:space:]:]+$ ]] || {
  echo "update image must be a tagged registry reference" >&2
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

# The local update tag points at the already verified digest. The builder reads
# that local store, so disk contents are immutable while bootc follows the tag.
"${podman_cmd[@]}" pull --arch amd64 "${source_image}"
"${podman_cmd[@]}" tag "${source_image}" "${update_image}"
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
  --type qcow2 \
  --type raw \
  "${update_image}"

qcow2=${output_dir}/qcow2/disk.qcow2
raw=${output_dir}/image/disk.raw
[[ -s ${qcow2} ]] || { echo "builder did not produce ${qcow2}" >&2; exit 1; }
[[ -s ${raw} ]] || { echo "builder did not produce ${raw}" >&2; exit 1; }
xz --threads=0 --keep --force "${raw}"

if command -v sha256sum >/dev/null 2>&1; then
  sha256() { sha256sum "$1" | awk '{print $1}'; }
else
  sha256() { shasum -a 256 "$1" | awk '{print $1}'; }
fi

qcow2_sha=$(sha256 "${qcow2}")
raw_sha=$(sha256 "${raw}.xz")
cat >"${output_dir}/metadata.env" <<EOF
HOMECORE_SOURCE_IMAGE=${source_image}
HOMECORE_UPDATE_IMAGE=${update_image}
HOMECORE_QCOW2_SHA256=${qcow2_sha}
HOMECORE_RAW_XZ_SHA256=${raw_sha}
BOOTC_IMAGE_BUILDER_IMAGE=${BOOTC_IMAGE_BUILDER_IMAGE}
EOF
printf '%s  %s\n' \
  "${qcow2_sha}" "qcow2/disk.qcow2" \
  "${raw_sha}" "image/disk.raw.xz" \
  >"${output_dir}/SHA256SUMS"

echo "built Homecore disks under ${output_dir}"
echo "next: just smoke"
