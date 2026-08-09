# Shared NODE tier for runner images that need a system node — build
# dependency only, never runs as a runner. Consumed by runner-e2e
# (playwright) and runner-frontend (npm); runner-backend / runner-db do NOT
# include it. Kept as its own tier so the pinned tarball exists once.
FROM ai-opencode-sandbox-runner-base:latest

# RUN steps use bash (see runner-base): /bin/sh is dash, no pipefail.
SHELL ["/bin/bash", "-c"]

# Node.js 18.20.8 — official binary tarball with PINNED SHA-256, instead of the
# Nodesource setup script (mutable remote code executed as root) and apt repo
# (its 18.x signing key uses SHA-1 and is rejected on modern apt since 2026-02).
# Hash source: https://nodejs.org/dist/latest-v18.x/SHASUMS256.txt
# xz-utils is build-time-only (tar -xJf spawns the xz binary) and is purged
# after extraction; it stays out of the shared base per the per-layer rule.
#
# Output capture: the step tees its output to /var/log/build/node-tier-install.log
# inside the image (in addition to stdout) so failures can be interpreted later
# via docker exec. set -o pipefail keeps a failing step failing — tee must
# never mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && { apt-get update \
    && apt-get install -y --no-install-recommends xz-utils \
    && curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v18.20.8/node-v18.20.8-linux-x64.tar.xz \
    && echo "5467ee62d6af1411d46b6a10e3fb5cacc92734dbcef465fea14e7b90993001c9  /tmp/node.tar.xz" | sha256sum -c - \
    && tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
    && rm /tmp/node.tar.xz \
    && apt-get purge -y --auto-remove xz-utils \
    && rm -rf /var/lib/apt/lists/*; } 2>&1 | tee /var/log/build/node-tier-install.log
