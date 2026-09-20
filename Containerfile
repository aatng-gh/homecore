ARG FCOS_BASE_IMAGE=quay.io/fedora/fedora-coreos@sha256:43e7756f7bb0e6e1127cb3cb4121596383c01968e81f3d4874b586a18562bad9
FROM ${FCOS_BASE_IMAGE}

ARG FCOS_CNI_RPM
ARG FCOS_FIREWALLD_RPM
ARG NOMAD_VERSION
ARG NOMAD_ASSET
ARG NOMAD_LINUX_AMD64_SHA256
ARG NOMAD_PODMAN_DRIVER_VERSION
ARG NOMAD_PODMAN_DRIVER_ASSET
ARG NOMAD_PODMAN_DRIVER_SHA256
ARG TAILSCALE_ASSET
ARG TAILSCALE_SHA256

RUN rpm-ostree install "${FCOS_CNI_RPM}" "${FCOS_FIREWALLD_RPM}" && \
    rpm-ostree cleanup -m

RUN set -eux; \
    workdir="$(mktemp -d)"; \
    curl --fail --location --proto '=https' --tlsv1.2 \
      --output "${workdir}/${NOMAD_ASSET}" \
      "https://releases.hashicorp.com/nomad/${NOMAD_VERSION}/${NOMAD_ASSET}"; \
    printf '%s  %s\n' "${NOMAD_LINUX_AMD64_SHA256}" "${workdir}/${NOMAD_ASSET}" | sha256sum -c -; \
    curl --fail --location --proto '=https' --tlsv1.2 \
      --output "${workdir}/${NOMAD_PODMAN_DRIVER_ASSET}" \
      "https://releases.hashicorp.com/nomad-driver-podman/${NOMAD_PODMAN_DRIVER_VERSION}/${NOMAD_PODMAN_DRIVER_ASSET}"; \
    printf '%s  %s\n' "${NOMAD_PODMAN_DRIVER_SHA256}" "${workdir}/${NOMAD_PODMAN_DRIVER_ASSET}" | sha256sum -c -; \
    curl --fail --location --proto '=https' --tlsv1.2 \
      --output "${workdir}/${TAILSCALE_ASSET}" \
      "https://pkgs.tailscale.com/stable/${TAILSCALE_ASSET}"; \
    printf '%s  %s\n' "${TAILSCALE_SHA256}" "${workdir}/${TAILSCALE_ASSET}" | sha256sum -c -; \
    mkdir -p "${workdir}/nomad" "${workdir}/driver" "${workdir}/tailscale" /usr/libexec/nomad/plugins; \
    bsdtar -xf "${workdir}/${NOMAD_ASSET}" -C "${workdir}/nomad"; \
    bsdtar -xf "${workdir}/${NOMAD_PODMAN_DRIVER_ASSET}" -C "${workdir}/driver"; \
    bsdtar -xf "${workdir}/${TAILSCALE_ASSET}" -C "${workdir}/tailscale" --strip-components 1; \
    install -m 0755 "${workdir}/nomad/nomad" /usr/bin/nomad; \
    install -m 0755 "${workdir}/driver/nomad-driver-podman" /usr/libexec/nomad/plugins/nomad-driver-podman; \
    install -m 0755 "${workdir}/tailscale/tailscale" /usr/bin/tailscale; \
    install -m 0755 "${workdir}/tailscale/tailscaled" /usr/bin/tailscaled; \
    rm -rf "${workdir}"; \
    /usr/bin/nomad version; \
    test -x /usr/libexec/nomad/plugins/nomad-driver-podman; \
    /usr/bin/tailscale version; \
    test -x /usr/libexec/cni/bridge; \
    test -x /usr/bin/firewall-cmd; \
    printf '%s\n' 'L+ /etc/resolv.conf - - - - ../run/systemd/resolve/stub-resolv.conf' \
      > /usr/lib/tmpfiles.d/homecore-resolv.conf; \
    unlink /etc/resolv.conf; \
    touch /etc/resolv.conf

RUN ostree container commit
