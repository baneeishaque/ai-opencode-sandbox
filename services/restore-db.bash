#!/usr/bin/env bash
set -euo pipefail

# Restore the latest DB dump into sandbox_db, dispatching on file type.
# Candidates: *.sql (psql), *.dump / *.tar (pg_restore), *-cluster-*/ dirs
# (pg_dumpall split: psql globals.sql + pg_restore the app DB dump).

export PATH="/usr/lib/postgresql/17/bin:$PATH"
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

REPO_ROOT=/workspace
DB_DUMP_PATH=${DB_DUMP_PATH:?DB_DUMP_PATH is required}
[ "${DB_DUMP_PATH#/}" = "$DB_DUMP_PATH" ] \
  || { echo "ERROR: DB_DUMP_PATH must be relative to the db repo folder (got: $DB_DUMP_PATH)" >&2; exit 1; }
DB_DUMP_PATH="$REPO_ROOT/db/$DB_DUMP_PATH"
APP_DUMP_NAME=${APP_DUMP_NAME:-app.dump}

# Convert a filename (or dirname) to a sortable epoch key by parsing the
# embedded timestamp. Handles DD-MM-YYYY-HH-MM and DD-mon-YYYY-HH-MM (e.g.
# app-production-28-march-2026-00-24-ist.sql). Untimestamped names sort last.
ts_key() {
  local name="$1"
  python3 "$SCRIPT_DIR/scripts/ts_key.py" "$name"
}

# If a candidate is a Git LFS pointer, fetch the real object on demand (scoped
# to just this file) from the git repo that tracks it, then restore. Pointers
# appear because clones are shallow and skip LFS smudge (GIT_LFS_SKIP_SMUDGE=1)
# — minimum-storage clones; the real bytes are fetched only for the dump we
# actually restore. Fails fast with a clear message if the object is missing.
# The db repo is always at /workspace/db (clone-repos.bash), and the dumps
# always live under its db_dumps/ subdir.
DB_REPO=/workspace/db

ensure_real() {
  local file="$1"
  if head -2 "$file" 2>/dev/null | grep -q "git-lfs.github.com/spec/v1"; then
    echo "LFS pointer detected: $file — fetching real object"
    local rel
    rel=$(python3 "$SCRIPT_DIR/scripts/lfs-relpath.py" "$file" "$DB_REPO")
    unset GIT_LFS_SKIP_SMUDGE
    git -C "$DB_REPO" lfs pull --include="$rel" || {
      echo "ERROR: git lfs pull failed for $rel (object missing from remote?)" >&2
      exit 1
    }
    if head -2 "$file" 2>/dev/null | grep -q "git-lfs.github.com/spec/v1"; then
      echo "ERROR: $file is still a pointer after lfs pull" >&2
      exit 1
    fi
  fi
}

latest_candidate() {
  local best=""
  local best_key="00000000000000"
  local entry
  for entry in "$DB_DUMP_PATH"/*; do
    [ -e "$entry" ] || continue
    local key
    key=$(ts_key "$(basename "$entry")")
    if [ "$key" -gt "$best_key" ]; then
      best_key="$key"
      best="$entry"
    fi
  done
  printf '%s' "$best"
}

restore_one() {
  local file="$1"
  local type="$2"
  echo "Restoring $type: $file"
  case "$type" in
    sql)
      ensure_real "$file"
      su -s /bin/bash -c "psql sandbox_db < \"$file\"" postgres
      ;;
    dump|tar)
      ensure_real "$file"
      su -s /bin/bash -c "pg_restore --no-owner --no-privileges -d sandbox_db \"$file\"" postgres
      ;;
    cluster)
      ensure_real "$file/globals.sql"
      su -s /bin/bash -c "psql -f \"$file/globals.sql\"" postgres || true
      local app_dump="$file/$APP_DUMP_NAME"
      if [ ! -f "$app_dump" ]; then
        app_dump=$(find "$file" -maxdepth 1 -name '*.dump' ! -name 'postgres.dump' | head -1)
      fi
      if [ -n "$app_dump" ]; then
        ensure_real "$app_dump"
        su -s /bin/bash -c "pg_restore --no-owner --no-privileges -d sandbox_db \"$app_dump\"" postgres
      fi
      ;;
  esac
}

if [ ! -d "$DB_DUMP_PATH" ]; then
  echo "No DB dump directory at $DB_DUMP_PATH; skipping restore"
  exit 0
fi

candidate=$(latest_candidate)
if [ -z "$candidate" ]; then
  echo "No dump candidates in $DB_DUMP_PATH; skipping restore"
  exit 0
fi

base=$(basename "$candidate")
case "$base" in
  *.sql)  restore_one "$candidate" sql ;;
  *.dump) restore_one "$candidate" dump ;;
  *.tar)  restore_one "$candidate" tar ;;
  *)      restore_one "$candidate" cluster ;;
esac
