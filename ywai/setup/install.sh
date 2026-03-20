#!/bin/bash
# YWAI Installer — curl -sSL https://github.com/Yoizen/dev-ai-workflow/releases/latest/download/install.sh | bash
set -euo pipefail

REPO="Yoizen/dev-ai-workflow"
BIN="ywai"
INSTALL_DIR="${HOME}/.local/bin"
DATA_DIR="${HOME}/.local/share/yoizen/dev-ai-workflow"

# ── Platform detection ──────────────────────────────────────────────
os="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m)"
case "$os" in linux|darwin) ;; *) echo "Unsupported OS: $os" >&2; exit 1 ;; esac
case "$arch" in x86_64|amd64) arch="amd64" ;; arm64|aarch64) arch="arm64" ;; *) echo "Unsupported arch: $arch" >&2; exit 1 ;; esac
platform="${os}-${arch}"

# ── Download binary ─────────────────────────────────────────────────
url="https://github.com/${REPO}/releases/latest/download/setup-wizard-${platform}"
mkdir -p "$INSTALL_DIR"
tmp="$(mktemp)"

echo "Downloading YWAI for ${platform}..."
curl -fsSL "$url" -o "$tmp"
mv "$tmp" "${INSTALL_DIR}/${BIN}"
chmod +x "${INSTALL_DIR}/${BIN}"

# ── Download extensions + skills ────────────────────────────────────
echo "Downloading extensions, skills, and templates..."
mkdir -p "$DATA_DIR"
tmpzip="$(mktemp)"
curl -fsSL "https://github.com/${REPO}/archive/refs/heads/main.tar.gz" -o "$tmpzip"
tar -xzf "$tmpzip" -C "$DATA_DIR" --strip-components=1 \
  dev-ai-workflow-main/ywai/extensions \
  dev-ai-workflow-main/ywai/skills \
  dev-ai-workflow-main/ywai/types \
  dev-ai-workflow-main/ywai/config \
  dev-ai-workflow-main/ywai/templates \
  2>/dev/null || true
rm -f "$tmpzip"

# ── PATH (persist) ─────────────────────────────────────────────────
if ! echo "$PATH" | grep -qF "$INSTALL_DIR"; then
  export PATH="$INSTALL_DIR:$PATH"
  for rc in "$HOME/.bashrc" "$HOME/.zshrc"; do
    [ -f "$rc" ] && grep -qF "$INSTALL_DIR" "$rc" 2>/dev/null || continue
    continue 2
  done
  for rc in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.profile"; do
    [ -f "$rc" ] || continue
    echo "" >> "$rc"
    echo "# YWAI" >> "$rc"
    echo "export PATH=\"${INSTALL_DIR}:\$PATH\"" >> "$rc"
    break
  done
fi

echo ""
echo "YWAI installed to ${INSTALL_DIR}/${BIN}"
echo "Extensions at ${DATA_DIR}/ywai/"
echo ""

# ── Launch wizard ───────────────────────────────────────────────────
exec "${INSTALL_DIR}/${BIN}" "$@"
