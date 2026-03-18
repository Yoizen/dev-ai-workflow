#!/usr/bin/env bash
set -e

TARGET_DIR="${1:-.}"
ABS_TARGET="$(cd "$TARGET_DIR" && pwd)"
OPENCODE_DIR="$ABS_TARGET/.opencode"
PLUGINS_DIR="$OPENCODE_DIR/plugins"
PLUGIN_FILE="$PLUGINS_DIR/command-hooks.js"
HOOKS_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bun >/dev/null 2>&1; then
  echo "Bun is required to build the OpenCode command hooks plugin"
  echo "Install: curl -fsSL https://bun.sh/install | bash"
  echo "Skipping hook installation for now (non-fatal)"
  exit 0
fi

mkdir -p "$PLUGINS_DIR"

if [[ -d "$PLUGINS_DIR/opencode-command-hooks" ]]; then
  rm -rf "$PLUGINS_DIR/opencode-command-hooks"
  echo "Removed legacy plugin directory"
fi

BUILD_DIR="$(mktemp -d)"
cp "$HOOKS_SOURCE/package.json" "$BUILD_DIR/"
cp "$HOOKS_SOURCE/tsconfig.json" "$BUILD_DIR/" 2>/dev/null || true
[[ -d "$HOOKS_SOURCE/src" ]] && cp -r "$HOOKS_SOURCE/src" "$BUILD_DIR/"

echo "Installing plugin dependencies..."
(cd "$BUILD_DIR" && bun install --frozen-lockfile 2>/dev/null || bun install) >/dev/null 2>&1

echo "Bundling OpenCode command hooks..."
if ! (cd "$BUILD_DIR" && bun build src/index.ts --target=bun \
  --outfile="$PLUGIN_FILE" \
  --external @opencode-ai/plugin \
  --external @opencode-ai/sdk) >/dev/null 2>&1; then
  rm -rf "$BUILD_DIR"
  echo "Plugin bundle failed"
  exit 1
fi
rm -rf "$BUILD_DIR"

OPENCODE_JSON="$OPENCODE_DIR/opencode.json"
if [[ -f "$OPENCODE_JSON" ]] && grep -q "file:.*opencode-command-hooks" "$OPENCODE_JSON" 2>/dev/null; then
  node -e "
    const fs=require('fs'),p='$OPENCODE_JSON';
    const cfg=JSON.parse(fs.readFileSync(p,'utf8'));
    if(Array.isArray(cfg.plugin)){
      cfg.plugin=cfg.plugin.filter(p=>!p.includes('opencode-command-hooks'));
      if(!cfg.plugin.length)delete cfg.plugin;
    }
    fs.writeFileSync(p,JSON.stringify(cfg,null,2)+'\n');
  " 2>/dev/null || true
fi

rm -f "$OPENCODE_DIR/bun.lock" 2>/dev/null || true
if [[ -f "$OPENCODE_DIR/package.json" ]] && grep -q "opencode-command-hooks" "$OPENCODE_DIR/package.json" 2>/dev/null; then
  rm -f "$OPENCODE_DIR/package.json"
  rm -rf "$OPENCODE_DIR/node_modules"
fi

HOOKS_CONFIG="$OPENCODE_DIR/command-hooks.jsonc"
if [[ ! -f "$HOOKS_CONFIG" ]]; then
  cat > "$HOOKS_CONFIG" << 'HOOKS_CONFIG'
{
  // OpenCode Command Hooks Configuration
  "truncationLimit": 30000,
  "tool": [
    {
      "id": "post-edit-lint",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npm run lint --silent 2>&1 || true"],
      "inject": "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Lint Check", "message": "exit {exitCode}", "variant": "info" }
    },
    {
      "id": "post-edit-typecheck",
      "when": { "phase": "after", "tool": ["edit", "write"] },
      "run": ["npx tsc --noEmit 2>&1 || true"],
      "inject": "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```",
      "toast": { "title": "Type Check", "message": "exit {exitCode}", "variant": "info" }
    }
  ],
  "session": []
}
HOOKS_CONFIG
fi

AGENT_DIR="$OPENCODE_DIR/agent"
AGENT_TARGET="$AGENT_DIR/engineer.md"
mkdir -p "$AGENT_DIR"
if [[ ! -f "$AGENT_TARGET" ]]; then
  if [[ -f "$HOOKS_SOURCE/agents/engineer.md" ]]; then
    cp "$HOOKS_SOURCE/agents/engineer.md" "$AGENT_TARGET"
  else
    cat > "$AGENT_TARGET" << 'AGENT'
---
description: Senior Software Engineer - Writes clean, tested, and maintainable code
mode: subagent
hooks:
  after:
    - run: ["npm run lint"]
      inject: "Lint Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
    - run: ["npm run typecheck"]
      inject: "Type Check Results (exit {exitCode}):\n```\n{stdout}\n{stderr}\n```"
---

You are a senior software engineer. Follow best practices, ensure type safety,
write tests, and fix any lint or type errors before considering a task complete.
AGENT
  fi
fi

echo "OpenCode command hooks installed"
