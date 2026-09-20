# Homecore

Homecore is a generic Fedora CoreOS-derived bootable container for a small
homelab. It adds pinned Nomad, Tailscale, CNI, and firewalld components without
embedding host names, network configuration, credentials, SSH keys, Ignition,
or workload secrets.

Host provisioning belongs in the separate private homelab repository. This
public repository owns only the reusable OS image and raw-disk conversion.

## Local validation

Requirements are `just` and ShellCheck, plus Apple Container on macOS or Podman
on Linux. `just image` builds and inspects the x86-64 image locally. Disk
conversion requires rootful Podman on an x86-64 Linux host; use the GitHub
release workflow for normal disk publication.

```sh
just check
just image
# On an x86-64 host:
just disk
# Or build from a specific published tag:
just disk ghcr.io/aatng-gh/homecore:sha-<commit>
```

`just disk` builds from `ghcr.io/aatng-gh/homecore:stable`; the installed system
follows that tag for future bootc updates. Pass one tagged image reference to
build and follow a different published image.

The compressed raw disk and its checksum remain under the ignored `build/`
directory.

## Publishing

Pull requests validate and build without publishing. Merges to `main` publish
`stable` and commit-specific `sha-<commit>` tags to the public GHCR package.

Run the `Release Homecore disk` workflow from `main` when an installation or
reflash needs a new raw disk. It builds the current `stable` image on an x86-64
runner and publishes `disk.raw.xz` plus `SHA256SUMS` in a commit-specific GitHub
release. The workflow summary prints the two values consumed by the private
homelab repository.
