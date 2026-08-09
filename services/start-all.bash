#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=/workspace
GIT_USER_NAME=${GIT_USER_NAME:?GIT_USER_NAME is required}
GIT_USER_EMAIL=${GIT_USER_EMAIL:?GIT_USER_EMAIL is required}
BACKEND_PROJECT_DIR=${BACKEND_PROJECT_DIR:?BACKEND_PROJECT_DIR is required}
[ "${BACKEND_PROJECT_DIR#/}" = "$BACKEND_PROJECT_DIR" ] \
  || { echo "ERROR: BACKEND_PROJECT_DIR must be relative to the backend repo folder (got: $BACKEND_PROJECT_DIR)" >&2; exit 1; }

# Ensure repos are present
if [ -x /init/clone-repos.bash ]; then
  /init/clone-repos.bash
fi

cd "$REPO_ROOT" || exit 1

git config --global user.name "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"

# Output capture: the whole setup phase below tees its output to
# /workspace/logs/start-all.log (in addition to stdout) so failures can be
# interpreted later — /workspace is the repo volume and survives container
# recreation. pipefail keeps tee from masking a failed step. The interactive
# shell after the block is NOT captured (it would grow the log unbounded).
mkdir -p /workspace/logs
{
# Start a lightweight Postgres using the system package (ephemeral).
# Debian keeps the postgres binaries in /usr/lib/postgresql/<ver>/bin (not on
# PATH), and psql defaults to the /var/run/postgresql socket dir — the server
# must be started with -k so the socket lands there.
export PATH="/usr/lib/postgresql/17/bin:$PATH"
PGDATA=/var/lib/postgresql/data
if [ ! -d "$PGDATA" ] || [ -z "$(ls -A $PGDATA 2>/dev/null || true)" ]; then
  mkdir -p "$PGDATA"
  chown -R postgres:postgres "$PGDATA"
  su -s /bin/bash -c "initdb -D $PGDATA" postgres
fi
install -d -o postgres -g postgres /var/run/postgresql

su -s /bin/bash -c "pg_ctl -D $PGDATA -l $PGDATA/postgres.log -o '-k /var/run/postgresql' start" postgres

# Create sandbox DB, then restore the latest dump if present
su -s /bin/bash -c "psql -c \"CREATE DATABASE sandbox_db;\" || true" postgres
if [ -x /init/restore-db.bash ]; then
  /init/restore-db.bash
fi

# Start backend if present
if [ -d "$REPO_ROOT/backend/$BACKEND_PROJECT_DIR" ]; then
  cd "$REPO_ROOT/backend/$BACKEND_PROJECT_DIR"
  python3 -m venv .venv || true
  . .venv/bin/activate
  pip install --no-cache-dir -r requirements/base.txt || true
  # requirements/local.txt is UTF-16 encoded and pins
  # google-api-python-client==1.4.1 (a 2017 sdist that breaks modern pip's
  # metadata build, aborting the whole install mid-file — everything after
  # line 81 silently never installs). Patch a UTF-8 copy to /tmp and install
  # that: replace the dead pin with the latest 2.x. psycopg2 + quickfix have
  # no binary wheels and compile via the C toolchain baked into the image.
  python3 - <<'PATCH_LOCAL_TXT' || true
from pathlib import Path
text = Path("requirements/local.txt").read_bytes().decode("utf-16")
text = text.replace("google-api-python-client==1.4.1", "google-api-python-client==2.198.0")
Path("/tmp/local-sandbox.txt").write_text(text, encoding="utf-8")
PATCH_LOCAL_TXT
  pip install --no-cache-dir -r /tmp/local-sandbox.txt || true
  # Backend imports stripe unconditionally in config/settings/base.py but
  # ships no requirement pin — sandbox installs a known-good version.
  pip install --no-cache-dir stripe==15.4.0 || true
  # Same unguarded-import pattern, resolved during the first boot attempts:
  # apps/paper_app/views.py:79 imports nasdaqdatalink (PyPI project name is
  # "nasdaq-data-link"; the import name "nasdaqdatalink" is not a project) and
  # download_nasdsq_prices.py:46 imports pyarrow.parquet. Pinned to the exact
  # versions verified in the sandbox venv.
  pip install --no-cache-dir nasdaq-data-link==1.0.4 || true
  pip install --no-cache-dir pyarrow==25.0.0 || true
  nohup python manage.py runserver 0.0.0.0:8000 > /workspace/backend.log 2>&1 &
  cd "$REPO_ROOT"
fi

# Start frontend if present
if [ -d "$REPO_ROOT/frontend" ]; then
  cd "$REPO_ROOT/frontend"
  npm ci || true
  # CRA dev-server OOM: webpack bundling exceeded node's default ~2GB old-space
  # heap cap (FATAL ERROR: JavaScript heap out of memory). Raise the heap.
  export NODE_OPTIONS=--max-old-space-size=4096
  nohup npm run start -- --host 0.0.0.0 > /workspace/frontend.log 2>&1 &
  cd "$REPO_ROOT"
fi
} 2>&1 | tee /workspace/logs/start-all.log

# Leave shell in ai-repo workspace so opencode can be started manually or by replacing the exec line
if [ -d "$REPO_ROOT/ai-repo" ]; then
  cd "$REPO_ROOT/ai-repo"
  echo "Agent workspace ready at $REPO_ROOT/ai-repo"
  exec /bin/bash
else
  exec /bin/bash
fi
