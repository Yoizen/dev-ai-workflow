# SDD Profiles

Configure named model profiles for SDD phases and switch between them.

## Overview

Profiles allow you to create multiple model configurations for SDD and switch between them. Profiles are stored in `.ywai/sdd-profiles.json` (or globally in `~/.ywai/sdd-profiles.json`).

This feature follows the **LLM-first pattern**: the LLM executes CLI commands and applies changes selectively, similar to `ywai --sync`.

## Usage with LLM

```text
User: "Create a cheap SDD profile using claude-3-5-sonnet for implementation"

LLM: [ejecuta ywai sdd-profiles create cheap]
     [ejecuta ywai sdd-profiles set cheap sdd-apply anthropic/claude-3-5-sonnet]
     [ejecuta ywai sdd-profiles activate cheap]
```

## Quick Start (CLI)

List profiles:

```bash
ywai sdd-profiles list
```

Create a profile:

```bash
ywai sdd-profiles create cheap
```

Set a model for a specific phase:

```bash
ywai sdd-profiles set cheap sdd-apply anthropic/claude-3-5-sonnet
```

Activate a profile:

```bash
ywai sdd-profiles activate cheap
```

Delete a profile:

```bash
ywai sdd-profiles delete old-profile
```

## Configuration

Profiles are stored in `.ywai/sdd-profiles.json`:

```json
{
  "provider": "opencode",
  "default_model": "anthropic/claude-sonnet-4",
  "models": {
    "default": "anthropic/claude-sonnet-4",
    "sdd-explore": "anthropic/claude-sonnet-4",
    "sdd-apply": ""
  },
  "profiles": {
    "cheap": {
      "name": "cheap",
      "orchestrator_model": "anthropic/claude-haiku-3.5-20241022",
      "models": {
        "default": "anthropic/claude-haiku-3.5-20241022",
        "sdd-explore": "anthropic/claude-haiku-3.5-20241022",
        "sdd-spec": "anthropic/claude-haiku-3.5-20241022",
        "sdd-design": "anthropic/claude-haiku-3.5-20241022",
        "sdd-tasks": "anthropic/claude-haiku-3.5-20241022",
        "sdd-apply": "anthropic/claude-haiku-3.5-20241022",
        "sdd-verify": "anthropic/claude-haiku-3.5-20241022"
      }
    },
    "premium": {
      "name": "premium",
      "orchestrator_model": "anthropic/claude-opus-4-20250514",
      "models": {
        "default": "anthropic/claude-opus-4-20250514",
        "sdd-explore": "anthropic/claude-opus-4-20250514",
        "sdd-spec": "anthropic/claude-opus-4-20250514",
        "sdd-design": "anthropic/claude-opus-4-20250514",
        "sdd-tasks": "anthropic/claude-opus-4-20250514",
        "sdd-apply": "anthropic/claude-opus-4-20250514",
        "sdd-verify": "anthropic/claude-opus-4-20250514"
      }
    }
  }
}
```

## Profile Name Rules

| Input | Valid? | Reason |
|---|---|---|
| `cheap` | Yes | Simple slug |
| `premium-v2` | Yes | Hyphens allowed |
| `my profile` | No | Spaces not allowed |
| `default` | No | Reserved for the base orchestrator |
| `LOUD` | Becomes `loud` | Auto-lowercased |

## How It Works

Each profile generates 11 agent entries in `opencode.json`:
- 1 orchestrator: `sdd-orchestrator-{name}` (mode `primary`)
- 10 sub-agents: `sdd-{phase}-{name}` (mode `subagent`, hidden)

The orchestrator's permissions are scoped so it can only delegate to its own suffixed sub-agents.

During sync or update, the installer:
1. Detects existing profiles by scanning for `sdd-orchestrator-*` keys
2. Updates shared prompt files
3. Regenerates orchestrator prompts
4. Preserves your model assignments

## Managing Profiles

### Create a Profile

```bash
ywai-wizard sync --profile cheap:anthropic/claude-haiku-3.5-20241022
```

### Delete a Profile

Edit `.ywai/config.json` and remove the profile entry, then run:

```bash
ywai-wizard sync
```

### Edit a Profile

Edit `.ywai/config.json` and modify the profile's models, then run:

```bash
ywai-wizard sync
```

## Example Profiles

### Cost-Optimized Profile

Use cheaper models for implementation:

```bash
ywai sdd-profiles create cheap
ywai sdd-profiles set cheap sdd-apply anthropic/claude-3-5-sonnet
```

### Hybrid Profile

Powerful models for design, cheaper for implementation:

```bash
ywai sdd-profiles create hybrid
ywai sdd-profiles set hybrid sdd-apply anthropic/claude-3-5-sonnet
```

### Quality-First Profile

Use the best model everywhere:

```bash
ywai sdd-profiles create premium
ywai sdd-profiles set premium sdd-design anthropic/claude-sonnet-4
```

## Available Models (from README)

| Tarea | Modelo recomendado |
|------|-------------------|
| Planning / diseño | `anthropic/claude-opus-4-20250514` |
| Implementación | `openai/codex-5.3` / `anthropic/claude-sonnet-4-20250514` |
| Commits, PRs, docs | `google/gemini-3-flash` |
| Ajustes de UI/CSS | `google/gemini-3-1-pro` |
| Code review básica | `google/gemini-3-flash` / `anthropic/claude-haiku-4-5-20250514` |
| Code review crítica | `openai/codex-5.3` |

Regla general:
- Modelo caro → pensar, planificar, revisar código crítico
- Modelo barato → ejecutar, commits, reviews rutinarias
