# plannotator-setup

Install-step extension that installs and configures [Plannotator](https://github.com/backnotprop/plannotator):
a tool to annotate and review coding agent plans and code diffs visually.

## What it does

1. Installs the `plannotator` CLI (via `plannotator.ai/install.sh` or `install.ps1`).
2. Auto-detects installed agent tools and configures each:
   - **OpenCode** — adds `@plannotator/opencode@latest` plugin to `opencode.json`.
   - **Gemini CLI** — the installer auto-detects `~/.gemini` and wires hook + slash commands.
   - **Claude Code** — logs manual step (`/plugin marketplace add backnotprop/plannotator`).
   - **Copilot CLI** — logs manual step (plugin marketplace install).
   - **Pi** — if `pi` CLI is present, runs `pi install npm:@plannotator/pi-extension`.

## Opt-in

This step is **opt-in**. It is only executed when:
- the wizard enables it, or
- the `--skip-plannotator` flag is NOT set and `plannotator-setup` is listed in the active type's `extensions.install-steps`.

## Skip

Use `--skip-plannotator` to skip this step even if it is listed in the type config.

## References

- Repo: https://github.com/backnotprop/plannotator
- Docs: https://plannotator.ai/docs/getting-started/installation/
