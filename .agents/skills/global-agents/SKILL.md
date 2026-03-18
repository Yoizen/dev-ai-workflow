---
name: global-agents
description: >
  Create and maintain global user-profile agents (OpenCode/Copilot) with extension-based templates,
  Agent-Skills bundles, and invoke sync hints.
  Trigger: When the user asks to add/update global agents, bundles.json, or skills invoke behavior.
license: Apache-2.0
metadata:
  author: Yoizen
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "global agents"
    - "bundles"
    - "invoke sync"
---

## When to Use

Use this skill when:
- Creating a new global agent role (template + bundle mapping)
- Updating `ywai/extensions/install-steps/global-agents/templates/*.md`
- Updating `ywai/extensions/install-steps/global-agents/bundles.json`
- Aligning generated `Skills bundle` / `Skills invoke` sections in global profiles

---

## Critical Patterns

### Pattern 1: Source of truth lives in extensions

- Global agents must be sourced from:
  - `ywai/extensions/install-steps/global-agents/templates/`
  - `ywai/extensions/install-steps/global-agents/bundles.json`
- Do not use project `AGENTS.md` as global-agent content source.

### Pattern 2: Agent ↔ Skills bundle contract

- Every global agent should have an explicit bundle in `bundles.json`.
- Use `defaults.<agent>` for baseline.
- Use `by_project_type.<type>.<agent>` only when a type needs a different bundle.
- Keep skill names aligned to folders under `skills/<name>/SKILL.md`.

### Pattern 3: Invoke hints come from skill metadata

- `Skills invoke` should be derived from each skill's `metadata.auto_invoke` when available.
- If unavailable, fallback text should remain generic and safe.

---

## Workflow

1. Identify target project type(s) and global agents from `ywai/setup/types/types.json` (`global_agents`).
2. Create/update agent templates in `templates/`.
3. Create/update `bundles.json` mappings.
4. Ensure generator logic in `ywai/skills/setup.sh` renders:
   - `## Skills bundle (global)`
   - `## Skills invoke`
5. Smoke test with global-only mode and inspect generated profile files.

---

## Commands

```bash
# Validate setup script syntax
bash -n ywai/skills/setup.sh

# Smoke test global agent generation (isolated HOME/XDG)
tmpdir="$(mktemp -d)"; mkdir -p "$tmpdir/home" "$tmpdir/xdg"
HOME="$tmpdir/home" XDG_CONFIG_HOME="$tmpdir/xdg" bash ywai/skills/setup.sh --global-only --opencode --copilot --project-type=devops

# Inspect generated global agent
sed -n '1,140p' "$tmpdir/xdg/opencode/agent/devops.md"
```

---

## Resources

- **Contract**: [references/bundles-contract.md](references/bundles-contract.md)
- **Templates**: `ywai/extensions/install-steps/global-agents/templates/`
- **Bundles**: `ywai/extensions/install-steps/global-agents/bundles.json`
- **Generator**: `ywai/skills/setup.sh`
