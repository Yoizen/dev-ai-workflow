#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
EXT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="$TARGET_DIR/.ywai/engram"
STATUS_FILE="$STATE_DIR/status.txt"
README_FILE="$STATE_DIR/README.md"
VSCODE_MCP_FILE="$TARGET_DIR/.vscode/mcp.json"
VSCODE_MCP_TEMPLATE="$EXT_DIR/copilot-mcp.json"

mkdir -p "$STATE_DIR"

cat > "$README_FILE" << 'EOF'
# Engram Setup

This project uses the `engram-setup` base extension.

The setup requires the `engram` binary.

If `engram` is missing, the installer will attempt an automatic installation.

After `engram` is available, the installer attempts to auto-configure:

- OpenCode
- Codex
- Gemini CLI

Reference:
- https://github.com/Gentleman-Programming/engram

Recommended next step for OpenCode session tracking:

```bash
engram serve &
```

If automatic installation fails, install `engram` manually and rerun:

```bash
bash ywai/setup/lib/installer.sh install-type-extensions generic .
```
EOF

write_install_failed_status() {
  local note="$1"
  cat > "$STATUS_FILE" << EOF
engram: install_failed
auto_configured: no
note: ${note}
EOF
}

configure_copilot_mcp() {
  [[ -f "$VSCODE_MCP_TEMPLATE" ]] || return 1

  mkdir -p "$(dirname "$VSCODE_MCP_FILE")"

  if command -v jq >/dev/null 2>&1 && [[ -f "$VSCODE_MCP_FILE" ]]; then
    if jq -e . "$VSCODE_MCP_FILE" >/dev/null 2>&1 \
      && jq -e . "$VSCODE_MCP_TEMPLATE" >/dev/null 2>&1 \
      && jq -s '.[0] * .[1]' "$VSCODE_MCP_FILE" "$VSCODE_MCP_TEMPLATE" > "${VSCODE_MCP_FILE}.tmp"; then
      mv "${VSCODE_MCP_FILE}.tmp" "$VSCODE_MCP_FILE"
      return 0
    fi
    rm -f "${VSCODE_MCP_FILE}.tmp"
  fi

  cp "$VSCODE_MCP_TEMPLATE" "$VSCODE_MCP_FILE"
}

resolve_platform() {
  local os_name arch_name
  os_name="$(uname -s 2>/dev/null | tr '[:upper:]' '[:lower:]')"
  arch_name="$(uname -m 2>/dev/null | tr '[:upper:]' '[:lower:]')"

  case "$os_name" in
    linux|darwin) ENGRAM_OS="$os_name" ;;
    *) return 1 ;;
  esac

  case "$arch_name" in
    x86_64|amd64) ENGRAM_ARCH="amd64" ;;
    arm64|aarch64) ENGRAM_ARCH="arm64" ;;
    *) return 1 ;;
  esac

  return 0
}

try_install_with_brew() {
  command -v brew >/dev/null 2>&1 || return 1

  brew install gentleman-programming/tap/engram >/dev/null 2>&1 && return 0

  # Migration path from old cask package
  brew uninstall --cask engram >/dev/null 2>&1 || true
  brew install gentleman-programming/tap/engram >/dev/null 2>&1
}

try_install_with_release_binary() {
  command -v curl >/dev/null 2>&1 || return 1
  command -v tar >/dev/null 2>&1 || return 1
  resolve_platform || return 1

  local api_url release_json download_url tmp_dir tarball local_bin
  api_url="https://api.github.com/repos/Gentleman-Programming/engram/releases/latest"
  release_json="$(curl -fsSL "$api_url")" || return 1

  download_url="$(printf '%s' "$release_json" \
    | grep -Eo '"browser_download_url"[[:space:]]*:[[:space:]]*"[^"]+"' \
    | cut -d '"' -f 4 \
    | grep -E "engram_.*_${ENGRAM_OS}_${ENGRAM_ARCH}\\.tar\\.gz$" \
    | head -n 1)"

  [[ -n "$download_url" ]] || return 1

  tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/engram-install-XXXXXX")"
  tarball="$tmp_dir/engram.tar.gz"
  local_bin="$HOME/.local/bin"

  curl -fsSL "$download_url" -o "$tarball" || { rm -rf "$tmp_dir"; return 1; }
  tar -xzf "$tarball" -C "$tmp_dir" || { rm -rf "$tmp_dir"; return 1; }

  mkdir -p "$local_bin"
  install -m 0755 "$tmp_dir/engram" "$local_bin/engram" || {
    rm -rf "$tmp_dir"
    return 1
  }

  rm -rf "$tmp_dir"
  export PATH="$local_bin:$PATH"
  command -v engram >/dev/null 2>&1
}

if ! command -v engram >/dev/null 2>&1; then
  echo "Engram CLI not found. Installing (required)..."
  try_install_with_brew || true
fi

if ! command -v engram >/dev/null 2>&1; then
  try_install_with_release_binary || true
fi

if ! command -v engram >/dev/null 2>&1; then
  write_install_failed_status "automatic install failed; install engram manually, then rerun type extensions"
  echo "ERROR: Engram CLI is required but could not be installed automatically. See $README_FILE"
  exit 1
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

if configure_copilot_mcp; then
  echo "Configured engram MCP for Copilot at .vscode/mcp.json"
else
  echo "Could not configure Copilot MCP at .vscode/mcp.json"
fi

cat > "$STATUS_FILE" << EOF
engram: installed
version: ${version:-unknown}
auto_configured: yes
configured_targets: $configured
failed_targets: $failed
EOF

echo "Engram setup complete ($configured configured, $failed failed)"
