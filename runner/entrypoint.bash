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

# Output capture: everything below tees to /var/log/runner-entrypoint.log
# (in addition to stdout) so registration / job failures can be interpreted
# later via docker exec or docker cp. pipefail keeps tee from masking a
# failure. The cleanup trap lives inside the block — it fires when run.sh
# exits, exactly as before.
mkdir -p /var/log
{
mkdir -p "$RUNNER_DIR"
cd "$RUNNER_DIR"

if [ ! -f "$RUNNER_DIR/run.sh" ]; then
  echo "Downloading GitHub Actions runner"
  # v2.336.0 (2026-07-20) — latest stable. GitHub publishes the per-asset
  # SHA-256 in the release notes, so the tarball is checksum-verified here
  # (2.308.0-era releases published none — TLS only then).
  RUNNER_TAR="actions-runner-linux-x64-2.336.0.tar.gz"
  curl -fsSL -o "$RUNNER_TAR" "https://github.com/actions/runner/releases/download/v2.336.0/$RUNNER_TAR"
  echo "04cf0be1aff4c3ec3554466c39124ca250e3effd8873bb7e8d68535aa9505d5d  $RUNNER_TAR" | sha256sum -c -
  tar xzf "$RUNNER_TAR"
fi

# GitHub's config.sh refuses EUID 0 ("Must not run with sudo") — everything
# runner-owned runs via `su runner -c` after chowning /runner (download and
# extract stay root-side; the container starts as root).
chown -R runner:runner /runner

su -s /bin/bash runner -c "./config.sh --unattended --url \"$RUNNER_URL\" --token \"$RUNNER_TOKEN\" --name \"$RUNNER_NAME\" --work \"$RUNNER_WORKDIR\""

cleanup() {
  su -s /bin/bash runner -c "./config.sh remove --unattended --token \"$RUNNER_TOKEN\"" || true
}
trap cleanup EXIT

# Export GIT_PUSH_TOKEN for workflows if provided
if [ -n "$GIT_PUSH_TOKEN" ]; then
  export GIT_PUSH_TOKEN
fi

su -s /bin/bash runner -c "./run.sh"
} 2>&1 | tee /var/log/runner-entrypoint.log
