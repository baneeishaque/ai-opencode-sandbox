# Backend runner — Python toolchain, STANDALONE image: it does NOT build
# FROM the jammy runner-base, because backend workflows need Python 3.13 and
# jammy's apt only ships 3.10. Instead it uses the same digest-pinned
# python:3.13.14-slim trixie base as services-agent (Python 3.13.14, pip
# 26.1.2 — frozen by the digest pin) plus the runner prereqs.
# Base byte-frozen: python:3.13.14-slim digest pin (identical digest to
# services-agent — same baked OS layer). Bump discipline:
#   docker buildx imagetools inspect python:3.13.14-slim  # get new index digest
# then update the @sha256:... below.
FROM python:3.13.14-slim@sha256:9662417aace5ae7b8e2609cce472b72a8958e134ba372808abe9cc1a0c0125e6

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
# bundled node20), libssl3t64 pulls zlib1g, tar pulls liblzma5. No apt python
# — Python 3.13.14 + pip 26.1.2 come from the base (services-agent's
# rationale: PEP 517 build isolation, all runtime deps ship cp313 wheels).
# No node — the backend runner does not carry it. No gzip — unused binary.
#
# Reproducibility: apt layer pinned to the same dated Debian snapshot
# (2026-08-01) as services-agent / runner-db. Snapshot Releases are older
# than apt's 7-day validity window, so Check-Valid-Until: no is required.
#
# Output capture: RUN steps tee their output to /var/log/build/*.log inside
# the image (in addition to stdout) so failures can be interpreted later via
# docker exec. set -o pipefail keeps a failing step failing — tee must never
# mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && rm -f /etc/apt/sources.list.d/debian.sources \
  && printf 'Types: deb\nURIs: https://snapshot.debian.org/archive/debian/20260801T000000Z/\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\nCheck-Valid-Until: no\n' > /etc/apt/sources.list.d/snapshot.sources \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl ca-certificates git tar libicu76 libssl3t64 libkrb5-3 \
     2>&1 | tee /var/log/build/apt-install.log \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
