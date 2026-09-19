#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "${repo_dir}"
# shellcheck disable=SC1091
. config/versions.env
# shellcheck disable=SC1091
. scripts/lib/coreos-tools.sh

disk=${1:-${repo_dir}/build/disks/qcow2/disk.qcow2}
work_dir=${HOMECORE_SMOKE_WORK_DIR:-${repo_dir}/build/disks/smoke}
timeout_seconds=${HOMECORE_SMOKE_TIMEOUT:-900}
marker=HOMECORE_SMOKE_PASS

[[ -s ${disk} ]] || { echo "missing QCOW2 disk: ${disk}" >&2; exit 1; }
[[ ${timeout_seconds} =~ ^[1-9][0-9]*$ ]] || {
  echo "HOMECORE_SMOKE_TIMEOUT must be a positive integer" >&2
  exit 1
}
command -v qemu-system-x86_64 >/dev/null 2>&1 || {
  echo "qemu-system-x86_64 is required (on macOS: brew install qemu)" >&2
  exit 1
}

mkdir -p "${work_dir}"
ignition=${work_dir}/smoke.ign
serial_log=${work_dir}/serial.log
coreos_tools_init
butane_run --strict --pretty config/smoke-test.bu >"${ignition}"
ignition_validate_run "${ignition}"

firmware=${HOMECORE_OVMF_CODE:-}
if [[ -z ${firmware} ]]; then
  for candidate in \
    /usr/share/OVMF/OVMF_CODE.fd \
    /usr/share/edk2/ovmf/OVMF_CODE.fd \
    /opt/homebrew/share/qemu/edk2-x86_64-code.fd; do
    if [[ -r ${candidate} ]]; then
      firmware=${candidate}
      break
    fi
  done
fi
[[ -r ${firmware} ]] || {
  echo "cannot find x86-64 UEFI firmware; set HOMECORE_OVMF_CODE" >&2
  exit 1
}

host_arch=$(uname -m)
host_os=$(uname -s)
accel=tcg
cpu=max
if [[ ${host_arch} == x86_64 && ${host_os} == Linux && -r /dev/kvm ]]; then
  accel=kvm
  cpu=host
elif [[ ${host_arch} == x86_64 && ${host_os} == Darwin ]]; then
  accel=hvf
  cpu=host
fi

: >"${serial_log}"
qemu_pid=
# Invoked indirectly by the EXIT trap.
# shellcheck disable=SC2329
cleanup() {
  if [[ -n ${qemu_pid} ]] && kill -0 "${qemu_pid}" 2>/dev/null; then
    kill "${qemu_pid}" 2>/dev/null || true
    wait "${qemu_pid}" 2>/dev/null || true
  fi
}
trap cleanup EXIT

qemu-system-x86_64 \
  -machine "q35,accel=${accel}" \
  -cpu "${cpu}" \
  -smp 2 \
  -m 4096 \
  -bios "${firmware}" \
  -drive "if=virtio,format=qcow2,file=${disk},snapshot=on" \
  -fw_cfg "name=opt/com.coreos/config,file=${ignition}" \
  -nic none \
  -display none \
  -monitor none \
  -serial stdio \
  -no-reboot \
  >"${serial_log}" 2>&1 &
qemu_pid=$!

deadline=$((SECONDS + timeout_seconds))
while (( SECONDS < deadline )); do
  if grep -Fq "${marker}" "${serial_log}"; then
    echo "Homecore QCOW2 smoke test passed (${accel})"
    exit 0
  fi
  if ! kill -0 "${qemu_pid}" 2>/dev/null; then
    wait "${qemu_pid}" || true
    echo "Homecore VM exited before reporting success" >&2
    tail -100 "${serial_log}" >&2
    exit 1
  fi
  sleep 2
done

echo "Homecore VM did not report success within ${timeout_seconds}s" >&2
tail -100 "${serial_log}" >&2
exit 1
