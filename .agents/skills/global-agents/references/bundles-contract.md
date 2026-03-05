# Global Agents Bundles Contract

## Files

- Templates: `ywai/extensions/install-steps/global-agents/templates/<agent>.md`
- Bundles: `ywai/extensions/install-steps/global-agents/bundles.json`

## JSON schema (practical)

```json
{
  "defaults": {
    "<agent-name>": ["<skill>", "<skill>"]
  },
  "by_project_type": {
    "<type>": {
      "<agent-name>": ["<skill>"]
    }
  }
}
```

## Rules

1. Keep `defaults` complete for each global agent role.
2. Add `by_project_type` only for true overrides.
3. Skill names must match `skills/<name>/SKILL.md` directories.
4. Generated global agents must expose:
   - `## Skills bundle (global)`
   - `## Skills invoke`
5. Never source global agent directives from project `AGENTS.md`.

## Example

- `devops` agent bundle: `["devops"]`
- `sdd-orchestator` bundle: full SDD chain (`sdd-init` ... `sdd-archive`)
