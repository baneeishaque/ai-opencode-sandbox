# Minimal services-agent image
# Base byte-frozen: Python 3.13.14 patch tag + index digest pin (freezes the
# baked OS layer beneath Python too — glibc, openssl, libc6). Bump discipline:
#   docker buildx imagetools inspect python:3.13.14-slim  # get new index digest
# then update the @sha256:... below. The apt layer is snapshot-pinned below.
FROM python:3.14.7-slim@sha256:caaf356f40667c496d405780745b9ac25771c189a51dfcc42430d531ea09f8a2

# All RUN steps use bash: set -o pipefail and brace-groups are bash-isms, and
# Debian/Ubuntu /bin/sh is dash (which has neither). ENTRYPOINT already uses
# /bin/bash -lc.
SHELL ["/bin/bash", "-c"]

# Required build args — fail-fast gate: docker build (or compose build) must
# receive these, mirroring the runtime env requirements. Values are validated
# but NOT baked into the image (no ENV/COPY from them); the container gets
# them via compose environment at run time.
ARG GITHUB_PAT
ARG AI_REPO_URL
ARG FRONTEND_REPO_URL
ARG BACKEND_REPO_URL
ARG TESTS_REPO_URL
ARG DB_REPO_URL
ARG DB_DUMP_PATH
ARG GIT_USER_NAME
ARG GIT_USER_EMAIL
ARG BACKEND_PROJECT_DIR

RUN test -n "$GITHUB_PAT" \
  && test -n "$AI_REPO_URL" \
  && test -n "$FRONTEND_REPO_URL" \
  && test -n "$BACKEND_REPO_URL" \
  && test -n "$TESTS_REPO_URL" \
  && test -n "$DB_REPO_URL" \
  && test -n "$DB_DUMP_PATH" \
  && test -n "$GIT_USER_NAME" \
  && test -n "$GIT_USER_EMAIL" \
  && test -n "$BACKEND_PROJECT_DIR" \
  || { echo "ERROR: required build args missing (GITHUB_PAT, AI_REPO_URL, FRONTEND_REPO_URL, BACKEND_REPO_URL, TESTS_REPO_URL, DB_REPO_URL, DB_DUMP_PATH, GIT_USER_NAME, GIT_USER_EMAIL, BACKEND_PROJECT_DIR) — pass via --build-arg or compose build args" >&2; exit 1; }

ENV DEBIAN_FRONTEND=noninteractive

# System deps: Chromium runtime libs, Postgres server (ephemeral sandbox DB),
# git + ca-certificates (runtime), curl (build-time only, purged below), and
# the C toolchain (build-essential python3-dev libpq-dev swig) so the
# backend's pip install can COMPILE the packages that have no binary wheels:
# psycopg2 (Django's postgres driver, definitely imported) and quickfix
# (builds with g++ + swig). Keeps upstream requirements text byte-identical.
#
# Reproducibility: the entire apt layer is pinned to a dated Debian snapshot
# (2026-08-01), freezing git, postgresql-17, and every transitive lib to exact
# versions. Snapshot Releases are older than apt's 7-day validity window, so
# Check-Valid-Until: no is required.
#
# Output capture: every RUN step below tees its output to /var/log/build/*.log
# inside the image (in addition to stdout), so a later failure can be
# interpreted via docker exec after the build. set -o pipefail keeps a failing
# step failing — tee must never mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && rm -f /etc/apt/sources.list.d/debian.sources \
  && printf 'Types: deb\nURIs: https://snapshot.debian.org/archive/debian/20260801T000000Z/\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\nCheck-Valid-Until: no\n' > /etc/apt/sources.list.d/snapshot.sources \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends curl ca-certificates git git-lfs xz-utils \
     postgresql-17 \
     build-essential python3-dev libpq-dev swig \
     libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libx11-6 libxcomposite1 libxrandr2 libxdamage1 libxss1 libasound2 libgbm1 \
     libdbus-1-3 libdrm2 libxkbcommon0 libxcb1 libxext6 libxfixes3 libxshmfence1 libxtst6 \
     libpango-1.0-0 libcairo2 libatspi2.0-0 libnspr4 libglib2.0-0 fonts-liberation \
     2>&1 | tee /var/log/build/apt-install.log

# Node.js 18.20.8 (final 18.x; required by the frontend stack) + OpenCode CLI
# 1.18.15 (the agent runtime, pinned to the host's version).
# Supply-chain hardening: official binary tarballs with PINNED SHA-256, instead
# of the Nodesource setup script (mutable remote code executed as root) and apt
# repo (its 18.x signing key uses SHA-1 and is rejected by Debian trixie since
# 2026-02-01; Nodesource rotated the key for 20/22/24 LTS only). OpenCode's
# GitHub release ships no official checksums, so its pin is cross-verified
# against the npm registry package (opencode-linux-x64@1.18.15): both extract
# to the identical binary (sha256 c1971d3d...).
# Hash sources: https://nodejs.org/dist/latest-v18.x/SHASUMS256.txt
# https://github.com/anomalyco/opencode/releases/download/v1.18.15/opencode-linux-x64.tar.gz
RUN set -o pipefail \
  && { curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz \
    && echo "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && curl -fsSL -o /tmp/opencode.tar.gz https://github.com/anomalyco/opencode/releases/download/v1.18.15/opencode-linux-x64.tar.gz \
    && echo "d842e0e8c622c672a481b7dc6f0329009b64db96b2ba6041e56f4f93f0293b1c  /tmp/opencode.tar.gz" | sha256sum -c - \
    && tar -xzf /tmp/opencode.tar.gz -C /usr/local/bin opencode \
    && chmod 755 /usr/local/bin/opencode \
    && rm /tmp/opencode.tar.gz; } 2>&1 | tee /var/log/build/node-opencode-download.log

# Remove build-time-only curl and apt metadata
RUN set -o pipefail \
  && apt-get purge -y --auto-remove curl 2>&1 | tee /var/log/build/apt-purge.log \
  && rm -rf /var/lib/apt/lists/*

# Playwright CLI and browsers — exact version pinned; playwright verifies
# browser archive integrity during install. 1.61.x is the newest line that
# supports node 18 (1.62+ requires node >=20); --only-shell installs just the
# headless Chromium shell (screenshots only) — saves ~100 MB over full Chromium.
RUN set -o pipefail \
  && npm i -g playwright@1.61.1 2>&1 | tee /var/log/build/playwright-install.log \
  && npx playwright install chromium --only-shell 2>&1 | tee /var/log/build/playwright-browsers.log \
  && npm cache clean --force \
  && rm -rf /root/.npm

# Python tooling: none needed — base ships pip 26.1.2 (frozen by the digest
# pin); setuptools/wheel are unnecessary (PEP 517 build isolation, and all
# runtime deps ship cp313 wheels). psql/pg_restore come via postgresql-17.

WORKDIR /workspace

# Copy scripts (baked outside /workspace so the repo volume can mount there)
COPY services/start-all.bash /init/start-all.bash
COPY services/restore-db.bash /init/restore-db.bash
COPY services/link-opencode-plugins.bash /init/link-opencode-plugins.bash
COPY services/scripts/ /init/scripts/
COPY init/clone-repos.bash /init/clone-repos.bash
RUN chmod +x /init/start-all.bash /init/restore-db.bash /init/link-opencode-plugins.bash /init/clone-repos.bash

ENTRYPOINT ["/bin/bash", "-lc", "/init/start-all.bash"]
