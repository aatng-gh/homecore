set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Validate scripts, pins, and the smoke-test Ignition configuration.
check:
    ./scripts/check.sh

# Build and inspect the local x86-64 Homecore OCI image.
image:
    ./scripts/build-image.sh

# Build x86-64 QCOW2 and compressed raw disks from an immutable OCI digest.
disk source_image update_image="ghcr.io/aatng-gh/homecore:stable":
    ./scripts/build-disks.sh {{ quote(source_image) }} {{ quote(update_image) }}

# Boot the generated QCOW2 and wait for its Ignition smoke-test marker.
smoke disk="build/disks/qcow2/disk.qcow2":
    ./scripts/smoke-test.sh {{ quote(disk) }}

# Build both disk formats, package the raw disk, and smoke-test the QCOW2.
test source_image update_image="ghcr.io/aatng-gh/homecore:stable":
    just disk {{ quote(source_image) }} {{ quote(update_image) }}
    just smoke
