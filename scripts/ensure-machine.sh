#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
podman_cmd=()
# shellcheck disable=SC1091
. "${repo_dir}/scripts/lib/podman.sh"

command -v podman >/dev/null 2>&1 || { echo "podman is required" >&2; exit 1; }
homecore_podman_init
"${podman_cmd[@]}" info
