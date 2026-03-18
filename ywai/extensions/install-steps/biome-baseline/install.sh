#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INSTALLER="$REPO_ROOT/setup/lib/installer.sh"

if [[ -x "$INSTALLER" || -f "$INSTALLER" ]]; then
  # shellcheck source=/dev/null
  source "$INSTALLER"
  install_biome "$TARGET_DIR"
else
  echo "installer.sh not found for biome-baseline"
  exit 1
fi
