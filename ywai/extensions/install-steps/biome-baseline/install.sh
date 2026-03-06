#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
BIOME_CONFIG="$TARGET_DIR/biome.json"
PACKAGE_JSON="$TARGET_DIR/package.json"

if [[ -f "$BIOME_CONFIG" ]]; then
  echo "biome.json already exists, skipping"
  exit 0
fi

cat > "$BIOME_CONFIG" <<'EOF'
{
  "$schema": "https://biomejs.dev/schemas/2.3.2/schema.json",
  "files": {
    "ignoreUnknown": true
  },
  "formatter": {
    "enabled": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineWidth": 80
  },
  "linter": {
    "enabled": true,
    "rules": {
      "recommended": true
    }
  }
}
EOF

echo "Created biome.json baseline"

if [[ -f "$PACKAGE_JSON" ]] && command -v npm >/dev/null 2>&1; then
  if (cd "$TARGET_DIR" && npm install --save-dev @biomejs/biome >/dev/null 2>&1); then
    echo "Installed @biomejs/biome"
  else
    echo "Warning: failed to install @biomejs/biome" >&2
  fi
fi
