---
name: extension-creator
description: >
  Creates or updates YWAI setup extensions following the project extension model.
  Trigger: When the user asks to add a new hook, MCP, install-step, prompts package,
  or to move installer behavior into `ywai/extensions/`.
license: Apache-2.0
metadata:
  author: Yoizen
  version: "1.0"
  scope: [root]
  auto_invoke:
    - "extensions"
    - "installer"
    - "setup"
---

## When to Use

Use this skill when:
- Adding a new extension under `ywai/extensions/`
- Converting hardcoded installer behavior into an extension
- Wiring an extension into `ywai/setup/types/types.json`
- Moving an existing installable feature into hooks, mcps, or install-steps

---

## Critical Patterns

### Pattern 1: Keep extensions outside `setup`

- Treat `ywai/setup/` as the installer engine
- Treat `ywai/extensions/` as the catalog of installable assets
- New extensions belong in one of:
  - `ywai/extensions/hooks/`
  - `ywai/extensions/mcps/`
  - `ywai/extensions/install-steps/`

### Pattern 2: Every extension must be installable

- Prefer a dedicated `install.sh`
- Keep the extension self-contained (bundle templates/assets inside the extension folder)
- Avoid hardcoded copies from unrelated repo roots when the asset can live inside the extension
- If an extension cannot safely install itself, do not create it until the install contract is clear

### Pattern 3: Wire through `types.json`

- Global defaults go in `base_config.extensions`
- Type-specific additions go in `types.<type>.extensions`
- Do not duplicate base extensions in every type unless there is a strong reason

---

## Decision Tree

```
Is it reusable across all project types?      → Add to base_config.extensions
Is it only for one/few project types?         → Add to types.<type>.extensions
Does it modify local project files/settings?  → install-steps
Does it add an MCP config/example?            → mcps
Does it install runtime hooks/plugins?        → hooks
```

---

## Code Examples

### Example 1: Add a base install-step extension

```bash
mkdir -p ywai/extensions/install-steps/my-extension
cat > ywai/extensions/install-steps/my-extension/install.sh <<'EOF'
#!/usr/bin/env bash
set -e
TARGET_DIR="${1:-.}"
echo "Install into $TARGET_DIR"
EOF
chmod +x ywai/extensions/install-steps/my-extension/install.sh
```

Then register it in `ywai/setup/types/types.json`:

```json
{
  "base_config": {
    "extensions": {
      "install-steps": ["my-extension"]
    }
  }
}
```

### Example 2: Add a Nest-only hook extension

```json
{
  "types": {
    "nest": {
      "extensions": {
        "hooks": ["my-hook"]
      }
    }
  }
}
```

Place the implementation in:

```text
ywai/extensions/hooks/my-hook/
└── install.sh
```

---

## Commands

```bash
mkdir -p ywai/extensions/hooks/<name>                    # Create hook extension
mkdir -p ywai/extensions/mcps/<name>                     # Create MCP extension
mkdir -p ywai/extensions/install-steps/<name>            # Create install-step extension
bash ywai/setup/setup.sh --list-extensions               # Verify extension registry
bash ywai/setup/lib/installer.sh install-type-extensions nest .  # Smoke test type extensions
```

---

## Resources

- **Project registry**: `ywai/extensions/`
- **Installer wiring**: `ywai/setup/lib/installer.sh`
- **Type config**: `ywai/setup/types/types.json`
- **Related skill**: `skill-creator` for general skill authoring patterns
