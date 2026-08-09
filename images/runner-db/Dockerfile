# DB runner — Postgres SERVER tooling, STANDALONE image: it does NOT build
# FROM the jammy runner-base, because db workflows restore 17-format dumps
# and jammy only ships postgresql-14 (which cannot restore them). Instead it
# is Debian trixie — the same distro + snapshot domain as services-agent —
# carrying the full runner prereqs + postgresql-17 so initdb / restore /
# psql all run locally on the runner.
# Base byte-frozen: debian:trixie-slim digest pin (freezes the exact base
# layer). Bump discipline: docker buildx imagetools inspect debian:trixie-slim
# then update the @sha256:... below.
FROM debian:trixie-slim@sha256:3a39a0592364683e6bab97937b72cad5a8fa6dcbbee90edb3bb48c7f8e94f258

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
RUN rm -f /etc/apt/sources.list.d/debian.sources \
  && printf 'Types: deb\nURIs: https://snapshot.debian.org/archive/debian/20260801T000000Z/\nSuites: trixie trixie-updates\nComponents: main\nSigned-By: /usr/share/keyrings/debian-archive-keyring.gpg\nCheck-Valid-Until: no\n' > /etc/apt/sources.list.d/snapshot.sources \
  && apt-get update \
  && apt-get install -y --no-install-recommends curl ca-certificates git tar libicu76 libssl3t64 libkrb5-3 postgresql-17 \
  && rm -rf /var/lib/apt/lists/*

WORKDIR /runner
COPY runner/entrypoint.bash /runner/entrypoint.bash
RUN chmod +x /runner/entrypoint.bash

ENTRYPOINT ["/bin/bash", "-lc", "/runner/entrypoint.bash"]
