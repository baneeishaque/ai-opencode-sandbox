# DB runner — Postgres SERVER tooling, STANDALONE image: it does NOT build
# FROM the jammy runner-base, because db workflows restore 17-format dumps
# and jammy only ships postgresql-14 (which cannot restore them). Instead it
# is Debian trixie — the same distro + snapshot domain as services-agent —
# carrying the full runner prereqs + postgresql-17 so initdb / restore /
# psql all run locally on the runner.
# Base byte-frozen: debian:trixie-slim digest pin (freezes the exact base
# layer). Bump discipline: docker buildx imagetools inspect debian:trixie-slim
# then update the @sha256:... below.
FROM debian:trixie-slim@sha256:d7e12182ce18b85b93007c1dedf31f2d29e01ccf3182cc4017c709b6259bc132

# RUN steps use bash (see services-agent): /bin/sh is dash, no pipefail.
SHELL ["/bin/bash", "-c"]

# Required build args — fail-fast gate mirroring the runtime env requirements.
# Values are validated but NOT baked into the image; the container gets them
# via compose environment at run time.
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

# Runner runtime deps (trixie names, verified against the snapshot: libicu76 /
# libssl3t64 / libkrb5-3) — same ELF-verified reasoning as runner-base:
# libicu76 pulls libstdc++6 + libgcc-s1 (hard load-time deps of coreclr +
# bundled node20), libssl3t64 pulls zlib1g, tar pulls liblzma5. Plus the
# Postgres SERVER (postgresql-17, same as services-agent) for local
# initdb/restore/psql workflows. No gzip — nothing uses the binary.
#
# Reproducibility: apt layer pinned to the same dated Debian snapshot
# (2026-08-01) as services-agent, freezing postgresql-17 and every transitive
# lib to exact versions. Snapshot Releases are older than apt's 7-day
# validity window, so Check-Valid-Until: no is required.
#
# Output capture: RUN steps tee their output to /var/log/build/*.log inside
# the image (in addition to stdout) so failures can be interpreted later via
# docker exec. set -o pipefail keeps a failing step failing — tee must never
# mask an error.
#
# CA bootstrap: debian:trixie-slim ships NO CA store, so https apt against
# snapshot.debian.org fails TLS ("certificate verify failed") before any
# package installs. The default debian.sources uses plain http deb.debian.org
# (and the archive keyring is preinstalled), so ca-certificates is
# bootstrapped from it first, then sources are swapped to the pinned
# snapshot. python-slim bases (services-agent, runner-backend) ship certs
# and do not need this.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && apt-get update 2>&1 | tee /var/log/build/apt-bootstrap-update.log \
  && apt-get install -y --no-install-recommends ca-certificates \
     2>&1 | tee /var/log/build/apt-bootstrap-ca.log \
  && rm -f /etc/apt/sources.list.d/debian.sources \
  && printf 'Types: deb\nURIs: https://snapshot.debian.org/archive/debian/20260801T000000Z/\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\nCheck-Valid-Until: no\n' > /etc/apt/sources.list.d/snapshot.sources \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl git tar libicu76 libssl3t64 libkrb5-3 postgresql-17 \
     2>&1 | tee /var/log/build/apt-install.log \
  && rm -rf /var/lib/apt/lists/*

# GitHub's runner refuses to run as root ("Must not run with sudo", EUID
# check in config.sh). Standalone image (no runner-base), so it gets the
# runner user itself; the entrypoint chowns /runner and runs config.sh /
# run.sh via `su runner -c`.
RUN useradd -m -s /bin/bash runner

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
