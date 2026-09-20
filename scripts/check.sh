#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"

command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required" >&2; exit 1; }
shellcheck scripts/*.sh scripts/lib/*.sh
for script in scripts/*.sh scripts/lib/*.sh; do bash -n "${script}"; done

for ignore_file in .containerignore .dockerignore; do
  [[ $(<"${ignore_file}") == $'**\n!Containerfile' ]] || {
    echo "${ignore_file} must expose only Containerfile to the image build" >&2
    exit 1
  }
done
# The base must remain valid without injected build arguments and immutable.
grep -Eq '^ARG FCOS_BASE_IMAGE=quay.io/fedora/fedora-coreos@sha256:[0-9a-f]{64}$' \
  Containerfile
# shellcheck disable=SC2016
grep -Fxq 'FROM ${FCOS_BASE_IMAGE}' Containerfile
grep -Fq 'sha256sum -c -' Containerfile
scripts/build-args.sh >/dev/null
echo "Homecore checks passed"
