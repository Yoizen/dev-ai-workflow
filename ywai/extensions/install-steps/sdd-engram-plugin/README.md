# sdd-engram-plugin

Install-step extension that registers [opencode-sdd-engram-manage](https://github.com/j0k3r-dev-rgl/sdd-engram-plugin):
an OpenCode TUI plugin for SDD profile management and Engram project memories.

## What it does

Registers the `opencode-sdd-engram-manage` plugin in `~/.config/opencode/tui.json`.

Once installed, the plugin provides:

- **SDD Profile Management**: Create, activate, edit, rename, and delete SDD profiles directly from the OpenCode TUI
- **Engram Project Memories**: List, read, and delete project memories via Engram integration
- **Per-Agent Fallbacks**: Configure fallback models for each `sdd-*` agent

## Usage

After installation, open the plugin in OpenCode TUI with:

- Shortcut: `Alt + K`
- Slash command: `/sdd-model`

## Opt-in

This step is **opt-in**. It is only executed when:
- the wizard enables it, or
- the `--skip-sdd-engram-plugin` flag is NOT set and `sdd-engram-plugin` is listed in the active type's `extensions.install-steps`.

## Skip

Use `--skip-sdd-engram-plugin` to skip this step even if it is listed in the type config.

## Orchestrator Fallback Policy (Optional)

The upstream repo includes a script to ensure the `sdd-orchestrator` prompt contains the fallback policy block required for `sdd-*-fallback` agents.

If you want to use this feature:

```bash
# Check mode (no changes)
npm run orchestrator:fallback:check

# Apply changes
npm run orchestrator:fallback:apply

# Custom config path
node ./scripts/ensure-orchestrator-fallback-policy.ts --config /path/to/opencode.json
```

This requires Node.js and TypeScript. The plugin works without it, but the script ensures proper fallback agent configuration.

## References

- Repo: https://github.com/j0k3r-dev-rgl/sdd-engram-plugin
- Package: https://www.npmjs.com/package/opencode-sdd-engram-manage
