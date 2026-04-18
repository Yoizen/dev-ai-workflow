#!/usr/bin/env bash
# Plannotator Setup Extension — macOS / Linux / WSL
# Installs plannotator CLI and configures detected agent tools.
set -e

TARGET_DIR="${1:-.}"

log() { printf "[plannotator-setup] %s\n" "$*"; }
warn() { printf "[plannotator-setup] WARN: %s\n" "$*" >&2; }

have() { command -v "$1" >/dev/null 2>&1; }

# ---------------------------------------------------------------------------
# 1. Install plannotator CLI
# ---------------------------------------------------------------------------
if have plannotator; then
  log "plannotator CLI already installed: $(plannotator --version 2>/dev/null || echo present)"
else
  if have curl; then
    log "Installing plannotator CLI from https://plannotator.ai/install.sh"
    if curl -fsSL https://plannotator.ai/install.sh | bash; then
      log "plannotator CLI installed"
    else
      warn "plannotator CLI install failed"
    fi
  else
    warn "curl not available — cannot install plannotator CLI automatically"
  fi
fi

# ---------------------------------------------------------------------------
# 2. Configure OpenCode (if opencode.json exists in target)
# ---------------------------------------------------------------------------
OPENCODE_JSON="$TARGET_DIR/opencode.json"
if [[ -f "$OPENCODE_JSON" ]]; then
  if grep -q '@plannotator/opencode' "$OPENCODE_JSON"; then
    log "OpenCode: plannotator plugin already configured"
  elif have node; then
    log "OpenCode: adding @plannotator/opencode@latest to $OPENCODE_JSON"
    node - "$OPENCODE_JSON" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const raw = fs.readFileSync(path, 'utf8');
let cfg;
try { cfg = JSON.parse(raw); } catch (e) {
  console.error('Could not parse opencode.json:', e.message);
  process.exit(0);
}
cfg.plugin = Array.isArray(cfg.plugin) ? cfg.plugin : [];
const entry = '@plannotator/opencode@latest';
if (!cfg.plugin.includes(entry)) {
  cfg.plugin.push(entry);
  fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + '\n');
  console.log('Added @plannotator/opencode@latest to plugin[]');
} else {
  console.log('Already present');
}
NODE
  else
    warn "OpenCode: node not available — add '@plannotator/opencode@latest' to plugin[] manually"
  fi
else
  log "OpenCode: no opencode.json in $TARGET_DIR (skipping)"
fi

# ---------------------------------------------------------------------------
# 3. Gemini CLI — plannotator installer auto-detects ~/.gemini
# ---------------------------------------------------------------------------
if [[ -d "$HOME/.gemini" ]]; then
  log "Gemini CLI detected (~/.gemini) — plannotator installer auto-configures hook + slash commands"
fi

# ---------------------------------------------------------------------------
# 4. Claude Code / Copilot CLI — manual plugin step (logged for user)
# ---------------------------------------------------------------------------
if have claude; then
  log "Claude Code detected. Run inside Claude Code:"
  log "    /plugin marketplace add backnotprop/plannotator"
fi
if have copilot; then
  log "Copilot CLI detected. Run inside Copilot CLI:"
  log "    /plugin marketplace add backnotprop/plannotator"
  log "    /plugin install plannotator-copilot@plannotator"
fi

# ---------------------------------------------------------------------------
# 5. Pi extension
# ---------------------------------------------------------------------------
if have pi; then
  log "Pi detected — installing @plannotator/pi-extension"
  if pi install npm:@plannotator/pi-extension >/dev/null 2>&1; then
    log "Pi extension installed"
  else
    warn "Failed to install @plannotator/pi-extension via pi"
  fi
fi

log "Done"
