#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
STATE_DIR="$TARGET_DIR/.ywai/engram"
STATUS_FILE="$STATE_DIR/status.txt"
README_FILE="$STATE_DIR/README.md"

mkdir -p "$STATE_DIR"

cat > "$README_FILE" << 'EOF'
# Engram Setup

This project uses the `engram-setup` base extension.

If the `engram` binary is installed, the installer attempts to auto-configure:

- OpenCode
- Codex
- Gemini CLI

Reference:
- https://github.com/Gentleman-Programming/engram

Recommended next step for OpenCode session tracking:

```bash
engram serve &
```

If `engram` was not installed at setup time, install it first and then rerun:

```bash
bash ywai/setup/lib/installer.sh install-type-extensions generic .
```
EOF

if ! command -v engram >/dev/null 2>&1; then
  cat > "$STATUS_FILE" << 'EOF'
engram: missing
auto_configured: no
note: install the engram binary, then rerun type extensions
EOF
  echo "Engram CLI not found. Wrote setup instructions to $README_FILE"
  exit 0
fi

version="$(engram version 2>/dev/null | head -n 1 || true)"
configured=0
failed=0

for target in opencode codex gemini-cli; do
  if engram setup "$target" >/dev/null 2>&1; then
    echo "Configured engram for $target"
    configured=$((configured + 1))
  else
    echo "Could not auto-configure engram for $target"
    failed=$((failed + 1))
  fi
done

cat > "$STATUS_FILE" << EOF
engram: installed
version: ${version:-unknown}
auto_configured: yes
configured_targets: $configured
failed_targets: $failed
EOF

echo "Engram setup complete ($configured configured, $failed failed)"
