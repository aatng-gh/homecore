#!/usr/bin/env bash

# This library defines podman_cmd for the scripts that source it.
# shellcheck disable=SC2034

# Select an isolated rootful Podman environment. On macOS, a dedicated machine
# keeps Homecore's storage independent while preserving Podman's required
# /var/lib/containers/storage path inside the VM.
homecore_podman_init() {
  if [[ $(uname -s) == Darwin ]]; then
    local machine=${HOMECORE_PODMAN_MACHINE:-homecore-builder}
    if ! podman machine inspect "${machine}" >/dev/null 2>&1; then
      podman machine init \
        --cpus "${HOMECORE_PODMAN_CPUS:-4}" \
        --memory "${HOMECORE_PODMAN_MEMORY:-6144}" \
        --disk-size "${HOMECORE_PODMAN_DISK_SIZE:-100}" \
        --rootful "${machine}"
    fi
    if [[ $(podman machine inspect "${machine}" --format '{{.State}}') != running ]]; then
      podman machine start "${machine}"
    fi

    # Podman 5.8 can create an AppleHV machine with Rosetta attached but omit
    # the activation marker. Repair the dedicated machine so amd64 image builds
    # do not silently fall back to slower, less compatible QEMU translation.
    if [[ $(uname -m) == arm64 ]] &&
      [[ $(podman machine inspect "${machine}" --format '{{.Rosetta}}') == true ]] &&
      ! podman machine ssh "${machine}" -- test -e /etc/containers/enable-rosetta; then
      podman machine ssh "${machine}" -- sudo touch /etc/containers/enable-rosetta
      podman machine stop "${machine}"
      podman machine start "${machine}"
    fi

    podman_cmd=(podman machine ssh "${machine}" -- sudo podman)
    return
  fi

  if [[ ${EUID} -eq 0 ]]; then
    podman_cmd=(podman)
  else
    command -v sudo >/dev/null 2>&1 || {
      echo "rootful Podman or sudo is required" >&2
      return 1
    }
    podman_cmd=(sudo podman)
  fi
}
