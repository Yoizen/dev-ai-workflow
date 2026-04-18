#!/usr/bin/env bash
# SDD Engram Plugin Setup — macOS / Linux / WSL
# Registers opencode-sdd-engram-manage plugin in ~/.config/opencode/tui.json
set -e

log() { printf "[sdd-engram-plugin] %s\n" "$*"; }
warn() { printf "[sdd-engram-plugin] WARN: %s\n" "$*" >&2; }

TUI_JSON="$HOME/.config/opencode/tui.json"
PLUGIN_ENTRY="opencode-sdd-engram-manage"

# ---------------------------------------------------------------------------
# Ensure tui.json exists
# ---------------------------------------------------------------------------
if [[ ! -f "$TUI_JSON" ]]; then
  log "Creating $TUI_JSON with plugin entry"
  mkdir -p "$(dirname "$TUI_JSON")"
  cat > "$TUI_JSON" <<EOF
{
  "\$schema": "https://opencode.ai/tui.json",
  "plugin": ["$PLUGIN_ENTRY"]
}
EOF
  log "Created $TUI_JSON with $PLUGIN_ENTRY"
  exit 0
fi

# ---------------------------------------------------------------------------
# Add plugin to tui.json
# ---------------------------------------------------------------------------
if command -v node >/dev/null 2>&1; then
  log "Adding $PLUGIN_ENTRY to $TUI_JSON"
  node - "$TUI_JSON" "$PLUGIN_ENTRY" <<'NODE'
const fs = require('fs');
const path = process.argv[2];
const plugin = process.argv[3];
const raw = fs.readFileSync(path, 'utf8');
let cfg;
try { cfg = JSON.parse(raw); } catch (e) {
  console.error('Could not parse tui.json:', e.message);
  process.exit(1);
}
cfg.plugin = Array.isArray(cfg.plugin) ? cfg.plugin : [];
if (!cfg.plugin.includes(plugin)) {
  cfg.plugin.push(plugin);
  fs.writeFileSync(path, JSON.stringify(cfg, null, 2) + '\n');
  console.log(`Added ${plugin} to plugin[]`);
} else {
  console.log('Already present');
}
NODE
else
  warn "node not available — cannot edit $TUI_JSON automatically"
  warn "Manually add \"$PLUGIN_ENTRY\" to the plugin[] array in $TUI_JSON"
fi

log "Done"
