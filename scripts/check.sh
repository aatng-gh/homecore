#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
# shellcheck disable=SC1091
. config/versions.env
# shellcheck disable=SC1091
. scripts/lib/coreos-tools.sh

command -v shellcheck >/dev/null 2>&1 || { echo "shellcheck is required" >&2; exit 1; }
shellcheck scripts/*.sh scripts/lib/*.sh
for script in scripts/*.sh; do bash -n "${script}"; done

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

validation_dir=$(mktemp -d "${repo_dir}/.coreos-tools.XXXXXX")
trap 'rm -rf "${validation_dir}"' EXIT
coreos_tools_init
butane_run --strict --pretty config/smoke-test.bu >"${validation_dir}/smoke.ign"
ignition_validate_run "${validation_dir}/smoke.ign"
echo "Homecore checks passed"
