# Common GitHub Actions self-hosted runner BASE image.
# Dedicated per-repo images (images/runner-<repo>/Dockerfile) build FROM this
# (or from the shared node tier, images/runner-node/Dockerfile) and add their
# own toolchains. The base itself never runs as a runner — it only exists as
# a build dependency.
# Base byte-frozen: ubuntu 22.04 digest pin (freezes the exact base layer).
# Bump discipline: docker buildx imagetools inspect ubuntu:22.04  # new digest
# then update the @sha256:... below. The runner tarball itself has no
# published checksum (GitHub publishes none) — version pin + TLS only.
FROM ubuntu:22.04@sha256:3b06811b2afd352be909dd088a004166d665dc76d38b13eada33522a9d915c6f

# Required build args — fail-fast gate, same as every runner image. The base
# is repo-agnostic, so compose wires the e2e value set as the canonical probe
# (RUNNER_E2E_* is always required by the active compose). Values are
# validated but NOT baked into the image.
ARG RUNNER_REPO_URL
ARG RUNNER_TOKEN
ARG GIT_PUSH_TOKEN
ARG RUNNER_NAME

RUN test -n "$RUNNER_REPO_URL" \
  && test -n "$RUNNER_TOKEN" \
  && test -n "$GIT_PUSH_TOKEN" \
  && test -n "$RUNNER_NAME" \
  || { echo "ERROR: required build args missing (RUNNER_REPO_URL, RUNNER_TOKEN, GIT_PUSH_TOKEN, RUNNER_NAME) — pass via --build-arg or compose build args" >&2; exit 1; }

ENV DEBIAN_FRONTEND=noninteractive

# gh runner runtime deps: the runner binary links the runtime .so only —
# runtime packages (libicu70/libssl3), not the -dev header packages (3-4x
# larger). Verified against the pinned tarball's ELF deps: libicu70 is what
# pulls libstdc++6 + libgcc-s1 (hard load-time deps of coreclr + bundled
# node20), libssl3 pulls zlib1g, tar pulls liblzma5. curl kept (actions +
# Node tarball fetch). No gzip — nothing uses the binary; tar -xzf and the
# .NET/Playwright extractors decompress via libz/bundled code. No python
# (runner-backend only) and no node (runner-node tier only) — per-layer
# toolchains stay out of the shared base.
#
# Reproducibility: apt layer pinned to a dated Ubuntu snapshot (2026-08-09),
# freezing every package to exact versions. Snapshot Releases are older than
# apt's 7-day validity window, so Check-Valid-Until: no is required. All
# downstream layers (runner-node, per-repo toolchains) inherit these pinned
# sources. main only — every package in the stack (incl. the Chromium libs
# on the e2e tier) resolves from main.
RUN rm -f /etc/apt/sources.list \
  && printf 'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260809T000000Z/ jammy main\n' > /etc/apt/sources.list \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates git tar libicu70 libssl3 libkrb5-3 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
