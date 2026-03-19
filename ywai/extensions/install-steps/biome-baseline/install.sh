#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
BIOME_CONFIG="$TARGET_DIR/biome.json"
PACKAGE_JSON="$TARGET_DIR/package.json"

if [[ -f "$BIOME_CONFIG" ]]; then
  echo "biome.json already exists, skipping"
  exit 0
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATE="$SCRIPT_DIR/biome.json"

if [[ ! -f "$TEMPLATE" ]]; then
  echo "ERROR: biome.json template not found at $TEMPLATE" >&2
  exit 1
fi

cp "$TEMPLATE" "$BIOME_CONFIG"
echo "Created biome.json baseline"

if [[ -f "$PACKAGE_JSON" ]] && command -v npm >/dev/null 2>&1; then
  if (cd "$TARGET_DIR" && npm install --save-dev @biomejs/biome >/dev/null 2>&1); then
    echo "Installed @biomejs/biome"
  else
    echo "Warning: failed to install @biomejs/biome" >&2
  fi
fi
