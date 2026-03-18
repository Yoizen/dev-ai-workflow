# global-agents

Defines source templates for global user-profile agents (OpenCode/Copilot).

## Scope
- Templates are consumed by `ywai/skills/setup.sh` in global profile mode.
- These templates are the canonical source for global agent content.
- `AGENTS.md` from project types is intentionally not used for global agents.
- Global agents are generated with a per-agent skills bundle + invoke hints.

## Template location

`templates/<agent-name>.md`

Supported names:
- `sdd-orchestator`
- `fe-engineer`
- `nest-engineer`
- `dotnet-engineer`
- `qa-playwright`
- `devops`

## Agent-Skills bundles

`bundles.json` maps each global agent to its skills.

- `defaults.<agent>`: default bundle for any project type.
- `by_project_type.<type>.<agent>`: optional override for a specific type.

Example:

- `devops` agent -> `devops` skill
- `qa-playwright` agent -> `playwright` skill
- `sdd-orchestator` agent -> full SDD skill set (`sdd-init` ... `sdd-archive`)

During generation, each global agent file gets:

- `## Skills bundle (global)`
- `## Skills invoke` (using `metadata.auto_invoke` from each `skills/*/SKILL.md` when available)
