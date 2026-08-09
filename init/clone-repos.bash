#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=/workspace
mkdir -p "$REPO_ROOT"
cd "$REPO_ROOT"

# Minimum-storage clone semantics: never smudge LFS pointers (even if a repo
# declares them) and never recurse into submodules — submodule content is
# cloned separately as its own top-level repo (e.g. the db repo itself).
export GIT_LFS_SKIP_SMUDGE=1

# Repo URLs passed via environment variables — required, no defaults.
# docker-compose.yml provides these; set -u aborts if any is unset.
# AI_REPO_URL / FRONTEND_REPO_URL / BACKEND_REPO_URL / TESTS_REPO_URL / DB_REPO_URL
# GITHUB_PAT (required, for private repos, e.g. GITHUB_PAT=github_pat_xxx) is injected
# as https://x-access-token:<PAT>@github.com/...

# URLs are always plain https://github.com/... (no embedded credentials), so
# auth injection is a straight rewrite: scheme stripped, PAT inserted.
auth_url() {
  local url="$1"
  if [ -n "$GITHUB_PAT" ]; then
    printf 'https://x-access-token:%s@%s' "$GITHUB_PAT" "${url#https://}"
  else
    printf '%s' "$url"
  fi
}

clone_or_update() {
  local url="$1"
  local name="$2"
  url=$(auth_url "$url")
  if [ -d "$name/.git" ]; then
    echo "Updating $name"
    git -C "$name" fetch --all --prune --depth=1 --no-tags || true
  else
    echo "Cloning $name from $url"
    # --depth=1 --single-branch --no-tags: shallow, one branch, no refs —
    # minimum storage. Submodules are NOT recursed (left as gitlinks).
    git clone --depth=1 --single-branch --no-tags "$url" "$name" \
      || { echo "Clone failed for $name"; exit 1; }
  fi
}

clone_or_update "$AI_REPO_URL" "ai-repo"
clone_or_update "$FRONTEND_REPO_URL" "frontend"
clone_or_update "$BACKEND_REPO_URL" "backend"
clone_or_update "$TESTS_REPO_URL" "tests"
clone_or_update "$DB_REPO_URL" "db"

echo "Repos ready at $REPO_ROOT"
