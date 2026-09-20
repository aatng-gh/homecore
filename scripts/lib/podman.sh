#!/usr/bin/env bash

# This library defines podman_cmd for the scripts that source it.
# shellcheck disable=SC2034

# Select rootful Podman for Linux image and disk builds.
homecore_podman_init() {
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
