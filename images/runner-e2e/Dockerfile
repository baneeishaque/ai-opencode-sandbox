# E2E runner — Playwright toolchain on the node tier (runner-base + node).
# Selenium/cucumber is discontinued; Playwright is the only future.
FROM ai-opencode-sandbox-runner-node:latest

# RUN steps use bash (see runner-base): /bin/sh is dash, no pipefail.
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

# Chromium runtime libs — hand-picked (same proven list as services-agent),
# resolved from the base's snapshot-pinned apt sources. Hand-picked instead
# of playwright's --with-deps so the layer installs exactly this set: no
# extra playwright-chosen packages, no second apt-get update, and apt lists
# are removed (--with-deps leaves them behind).
#
# Output capture: RUN steps tee their output to /var/log/build/*.log inside
# the image (in addition to stdout) so failures can be interpreted later via
# docker exec. set -o pipefail keeps a failing step failing — tee must never
# mask an error.
RUN set -o pipefail \
  && mkdir -p /var/log/build \
  && apt-get update 2>&1 | tee /var/log/build/apt-update.log \
  && apt-get install -y --no-install-recommends \
     libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libx11-6 libxcomposite1 libxrandr2 libxdamage1 libxss1 libasound2 libgbm1 \
     libdbus-1-3 libdrm2 libxkbcommon0 libxcb1 libxext6 libxfixes3 libxshmfence1 libxtst6 \
     libpango-1.0-0 libcairo2 libatspi2.0-0 libnspr4 libglib2.0-0 fonts-liberation \
     2>&1 | tee /var/log/build/apt-install.log \
  && rm -rf /var/lib/apt/lists/*

# Playwright CLI and browsers for CI tests — exact version pinned; playwright
# verifies browser archive integrity during install. --only-shell installs
# just the headless Chromium shell (saves ~100 MB over full Chromium; covers
# headless CI e2e — screenshots, video, tracing), same as services-agent.
# 1.61.x is the newest line that supports node 18 (1.62+ requires node >=20);
# the node tier carries node 18.20.8.
RUN set -o pipefail \
  && npm i -g playwright@1.61.1 2>&1 | tee /var/log/build/playwright-install.log \
  && npx playwright install chromium --only-shell 2>&1 | tee /var/log/build/playwright-browsers.log \
  && npm cache clean --force \
  && rm -rf /root/.npm
