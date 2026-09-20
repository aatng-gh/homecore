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
# The Containerfile must defer expansion to the container builder.
# shellcheck disable=SC2016
grep -Fxq 'FROM ${FCOS_BASE_IMAGE}' Containerfile
grep -Fq 'sha256sum -c -' Containerfile
scripts/build-args.sh >/dev/null
echo "Homecore checks passed"
