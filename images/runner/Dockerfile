# Common GitHub Actions self-hosted runner BASE image.
# Dedicated per-repo images (images/runner-<repo>/Dockerfile) build FROM this
# (or from the shared node tier, images/runner-node/Dockerfile) and add their
# own toolchains. The base itself never runs as a runner — it only exists as
# a build dependency.
# Base byte-frozen: ubuntu 22.04 digest pin (freezes the exact base layer).
# Bump discipline: docker buildx imagetools inspect ubuntu:22.04  # new digest
# then update the @sha256:... below. The runner tarball (2.336.0, downloaded
# at runtime by entrypoint.bash) is checksum-verified against the SHA-256
# GitHub now publishes in each release's notes.
FROM ubuntu:26.04@sha256:513c074113a871b51a8d16ab445c88779d6452d937a164fb5cc479f32668a41d

# All RUN steps use bash: set -o pipefail and brace-groups are bash-isms, and
# Ubuntu /bin/sh is dash (which has neither). ENTRYPOINT already uses
# /bin/bash -lc.
SHELL ["/bin/bash", "-c"]

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
# larger). Deps were verified against the 2.308.0 tarball's ELF needs when
# the base was designed; the 2.336.0 bump is expected to keep them (same
# load-time shape) — if it ever changes, the missing-lib failure shows in
# /var/log/runner-entrypoint.log. libicu70 is what pulls libstdc++6 +
# libgcc-s1 (hard load-time deps of coreclr + bundled node20), libssl3 pulls
# zlib1g, tar pulls liblzma5. curl kept (actions +
# Node tarball fetch). No gzip — nothing uses the binary; tar -xzf and the
# .NET/Playwright extractors decompress via libz/bundled code. No python
# (runner-backend only) and no node (runner-node tier only) — per-layer
# toolchains stay out of the shared base.
#
# Reproducibility: apt layer pinned to a dated Ubuntu snapshot (2026-08-09),
# freezing every package to exact versions. Snapshot Releases are older than
# apt's 7-day validity window, so Check-Valid-Until: no is required. All
# downstream layers (runner-node, per-repo toolchains) inherit these pinned
# sources. TWO pockets: jammy main + jammy-updates — the pinned base digest
# is rebuilt with jammy-updates versions baked in (e.g. perl-base
# 5.34.0-3ubuntu1.7), so a main-only pin creates version skew (snapshot perl
# 5.34.0-3ubuntu1 requires perl-base exactly = 5.34.0-3ubuntu1) and apt
# fails with "held broken packages".
#
# Output capture: RUN steps tee their output to /var/log/build/*.log inside
# the image (in addition to stdout) so failures can be interpreted later via
# docker exec. set -o pipefail keeps a failing step failing — tee must never
# mask an error.
#
# CA bootstrap: the ubuntu:22.04 base image ships NO CA store, so an https
# apt against the snapshot fails TLS before any package is installed
# ("No system certificates available. Try installing ca-certificates").
# Default sources are plain http archive.ubuntu.com, so ca-certificates is
# bootstrapped from them first, then sources are swapped to the pinned
# snapshot. Debian-slim bases (services-agent, runner-db) ship certs and do
# not need this.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && apt-get update 2>&1 | tee /var/log/build/apt-bootstrap-update.log \
  && apt-get install -y --no-install-recommends ca-certificates \
     2>&1 | tee /var/log/build/apt-bootstrap-ca.log \
  && rm -f /etc/apt/sources.list \
  && printf 'deb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260809T000000Z/ jammy main\ndeb [check-valid-until=no] https://snapshot.ubuntu.com/ubuntu/20260809T000000Z/ jammy-updates main\n' > /etc/apt/sources.list \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl git tar libicu70 libssl3 libkrb5-3 \
     2>&1 | tee /var/log/build/apt-install.log \
  && rm -rf /var/lib/apt/lists/*

# GitHub's runner refuses to run as root ("Must not run with sudo", EUID
# check in config.sh). Everything runner-owned lives under /runner; the
# entrypoint chowns /runner and runs config.sh/run.sh via `su runner -c`.
# runner-frontend, runner-e2e and runner-node inherit this user.
RUN useradd -m -s /bin/bash runner

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
