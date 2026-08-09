#!/usr/bin/env bash
set -euo pipefail

RUNNER_DIR=/runner/actions-runner
RUNNER_URL=${RUNNER_REPO_URL:-}
RUNNER_TOKEN=${RUNNER_TOKEN:-}
RUNNER_NAME=${RUNNER_NAME:-}
RUNNER_WORKDIR=/runner/_work
GIT_PUSH_TOKEN=${GIT_PUSH_TOKEN:-}

if [ -z "$RUNNER_URL" ] || [ -z "$RUNNER_TOKEN" ] || [ -z "$RUNNER_NAME" ]; then
  echo "RUNNER_REPO_URL, RUNNER_TOKEN and RUNNER_NAME must be set"
  exec /bin/bash
fi

mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f "$RUNNER_DIR/run.sh" ]; then
  echo "Downloading GitHub Actions runner"
  RUNNER_TAR="actions-runner-linux-x64-2.308.0.tar.gz"
  curl -fsSL -o "$RUNNER_TAR" "https://github.com/actions/runner/releases/download/v2.308.0/$RUNNER_TAR"
  tar xzf "$RUNNER_TAR"
fi

./config.sh --unattended --url "$RUNNER_URL" --token "$RUNNER_TOKEN" --name "$RUNNER_NAME" --work "$RUNNER_WORKDIR"

cleanup() {
  ./config.sh remove --unattended --token "$RUNNER_TOKEN" || true
}
trap cleanup EXIT

# Export GIT_PUSH_TOKEN for workflows if provided
if [ -n "$GIT_PUSH_TOKEN" ]; then
  export GIT_PUSH_TOKEN
fi

./run.sh
