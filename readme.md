# Homecore

Homecore is a generic Fedora CoreOS-derived bootable container for a small
homelab. It adds pinned Nomad, Tailscale, CNI, and firewalld components without
embedding host names, network configuration, credentials, SSH keys, Ignition,
or workload secrets.

Host provisioning belongs in the separate private homelab repository. This
public repository owns only the reusable OS image and local disk validation.

## Local validation

Requirements are `just`, Podman, and—only for the boot smoke test—
`qemu-system-x86_64`. On macOS, `just machine` creates or starts a dedicated
rootful `homecore-builder` Podman machine. `just image` works on Apple Silicon
through Rosetta. Disk conversion currently requires an x86-64 host because the
image builder's nested x86-64 `crun` cannot run under ARM translation.

```sh
just check
just machine
just image
# On an x86-64 host:
just test ghcr.io/aatng-gh/homecore@sha256:<manifest-digest>
```

The immutable digest supplies the disk contents. The resulting system follows
`ghcr.io/aatng-gh/homecore:stable` for future bootc updates unless a different
tagged update reference is passed as the second argument.

Generated QCOW2, compressed raw disk, checksums, metadata, Ignition, and serial
logs remain under the ignored `build/` directory. Override the dedicated
machine name and resources with `HOMECORE_PODMAN_MACHINE`,
`HOMECORE_PODMAN_CPUS`, `HOMECORE_PODMAN_MEMORY`, and
`HOMECORE_PODMAN_DISK_SIZE` when necessary.

## Publishing

Pull requests validate and build without publishing. Merges to `main` publish
`candidate` and `sha-<commit>` to the public GHCR package. The manual promotion
workflow verifies that the commit-specific tag resolves to the selected digest
before moving `stable`.
