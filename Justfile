set shell := ["bash", "-euo", "pipefail", "-c"]

default:
    @just --list

# Validate scripts and immutable build inputs.
check:
    ./scripts/check.sh

# Build and inspect the local x86-64 Homecore OCI image.
image:
    ./scripts/build-image.sh

# Build a compressed x86-64 raw disk from stable or a specified published tag.
disk image="ghcr.io/aatng-gh/homecore:stable":
    ./scripts/build-disk.sh {{ quote(image) }}
