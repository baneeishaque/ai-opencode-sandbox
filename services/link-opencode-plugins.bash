#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT=/workspace
PLUGIN_DIR=${OPENCODE_PLUGIN_DIR:-}
if [ -z "$PLUGIN_DIR" ]; then
  echo "OPENCODE_PLUGIN_DIR unset — skipping plugin link (plugins are optional)"
  exit 0
fi
[ "${PLUGIN_DIR#/}" = "$PLUGIN_DIR" ] \
  || { echo "ERROR: OPENCODE_PLUGIN_DIR must be relative to the ai-repo folder (got: $PLUGIN_DIR)" >&2; exit 1; }

PLUGIN_SRC="$REPO_ROOT/ai-repo/$PLUGIN_DIR"
[ -d "$PLUGIN_SRC" ] \
  || { echo "ERROR: opencode plugin folder not found: $PLUGIN_SRC (OPENCODE_PLUGIN_DIR=$PLUGIN_DIR)" >&2; exit 1; }

GLOBAL_PLUGINS=/root/.config/opencode/plugins
mkdir -p "$GLOBAL_PLUGINS"
linked=0
for f in "$PLUGIN_SRC"/*.ts; do
  [ -e "$f" ] || continue
  ln -sf "$f" "$GLOBAL_PLUGINS/"
  linked=$((linked + 1))
done
echo "Linked $linked opencode plugin(s) from $PLUGIN_SRC into $GLOBAL_PLUGINS"
