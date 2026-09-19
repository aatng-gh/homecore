#!/usr/bin/env bash
# shellcheck disable=SC2154

coreos_tools_init() {
  coreos_tools_mode=container
  if command -v butane >/dev/null 2>&1 &&
    butane --version 2>&1 | grep -F "${BUTANE_VERSION}" >/dev/null &&
    command -v ignition-validate >/dev/null 2>&1; then
    coreos_tools_mode=local
    return
  fi

  if command -v podman >/dev/null 2>&1; then
    coreos_tools_engine=podman
  elif command -v docker >/dev/null 2>&1; then
    coreos_tools_engine=docker
  else
    echo "local Butane and Ignition binaries or Podman/Docker are required" >&2
    return 1
  fi
}

butane_run() {
  if [[ ${coreos_tools_mode} == local ]]; then
    butane "$@"
  else
    "${coreos_tools_engine}" run --rm \
      --volume "${repo_dir}:${repo_dir}:ro" --workdir "${repo_dir}" \
      "${BUTANE_IMAGE}" "$@"
  fi
}

ignition_validate_run() {
  if [[ ${coreos_tools_mode} == local ]]; then
    ignition-validate "$@"
  else
    "${coreos_tools_engine}" run --rm \
      --volume "${repo_dir}:${repo_dir}:ro" --workdir "${repo_dir}" \
      "${IGNITION_VALIDATE_IMAGE}" "$@"
  fi
}
