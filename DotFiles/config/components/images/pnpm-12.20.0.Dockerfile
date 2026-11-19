# toolshelf docker-mode image for pnpm 12.20.0. Docker Hub has no official
# pnpm image, so this builds one on the pinned official Node image.
#
#   node 22.21.1 (full bookworm: python3, make, g++ for native builds such as
#   better-sqlite3) + pnpm 12.20.0 from the npm tarball, checked against the
#   registry's sha512 before install. pnpm can't switch itself to another
#   version, and there's no corepack shim.
#
# Build (the user runs it; agents can't run `docker build` into the manifest):
#   docker build -t toolshelf/pnpm:12.20.0 \
#     -f ~/.config/components/images/pnpm-12.20.0.Dockerfile ~/.config/components/images
#   docker image ls --digests toolshelf/pnpm     # the sha256 to pin
# Then in components.conf:
#   pnpm 12.20.0 default docker=toolshelf/pnpm:12.20.0@sha256:<digest>
# Colima's Docker uses the containerd store, so a local build has a real
# digest and `docker run image@sha256:…` finds it without a registry.
# On a new machine, build it again: the digest changes, so update the pin.

FROM node:22.21.1-bookworm@sha256:b84d52cd45bfe261096ccbf886955d431b8b9ed01b72eaef588e8886bda09e78

ARG PNPM_VERSION=12.20.0
ARG PNPM_INTEGRITY=sha512-bMx0mXzO9OZ5mXiOGNv7+lg+KoSWaGaNtHB7aoMGZi9HFW5lAjKphb0+wkz5NkwaoVTTflHteqxiwc0eOvyAww==

RUN set -eu; \
    curl -fsSLo /tmp/pnpm.tgz "https://registry.npmjs.org/pnpm/-/pnpm-${PNPM_VERSION}.tgz"; \
    got="sha512-$(openssl dgst -sha512 -binary /tmp/pnpm.tgz | base64 -w0)"; \
    if [ "$got" != "$PNPM_INTEGRITY" ]; then echo "pnpm tarball integrity mismatch: $got" >&2; exit 1; fi; \
    npm install --global --no-audit --no-fund --ignore-scripts /tmp/pnpm.tgz; \
    rm -f /tmp/pnpm.tgz; \
    rm -f /usr/local/bin/corepack; \
    pnpm --version | grep -qx "${PNPM_VERSION}"

# pnpm 12 reads only pnpm_config_*. Same choices as the host component (78-pnpm.zsh):
# no self-switching to the project's packageManager version, no update checks.
ENV pnpm_config_manage_package_manager_versions=false \
    pnpm_config_update_notifier=false \
    COREPACK_ENABLE_NETWORK=0

LABEL org.opencontainers.image.title="toolshelf pnpm ${PNPM_VERSION}" \
      org.opencontainers.image.description="node 22.21.1 + pnpm ${PNPM_VERSION} + build tools, for toolshelf docker mode"
