# Frontend runner — node-based toolchain on the node tier (runner-base + node).
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

# Yarn removed — the frontend stack is npm-only (same as services-agent:
# setup-node@v4 + npm in the workflow); node 18 + npm already come from the
# node tier, so no extra toolchain layer is needed.
