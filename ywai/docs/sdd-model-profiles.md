# SDD Model Profiles

Assign different AI models to different SDD phases for cost/quality optimization.

## Overview

Not all SDD phases require the same level of model capability:

| Phase | Recommended Model | Rationale |
|-------|------------------|-----------|
| **sdd-explore** | Powerful (Claude Sonnet, GPT-4) | Deep analysis, comparison matrices |
| **sdd-propose** | Default | Simple documentation |
| **sdd-spec** | Powerful | Requirements need precision |
| **sdd-design** | Powerful | Architecture decisions are critical |
| **sdd-tasks** | Default | Task breakdown is straightforward |
| **sdd-apply** | Fast/Cheap (Qwen, Llama) | High throughput implementation |
| **sdd-verify** | Default | Validation is rule-based |

## Configuration

### OpenSpec Mode

Add the `models:` section to `openspec/config.yaml`:

```yaml
# openspec/config.yaml
schema: spec-driven

context: |
  Tech stack: NestJS + TypeScript
  Architecture: Clean Architecture
  Testing: Jest

# Model assignment per SDD phase
models:
  default: ""                                # Use agent's default
  sdd-explore: "anthropic/claude-sonnet-4"   # Powerful for analysis
  sdd-propose: ""                            # Use default
  sdd-spec: "anthropic/claude-sonnet-4"      # Powerful for specs
  sdd-design: "anthropic/claude-sonnet-4"    # Powerful for architecture
  sdd-tasks: ""                              # Use default
  sdd-apply: "openrouter/qwen/qwen3-30b"     # Fast/cheap for implementation
  sdd-verify: ""                             # Use default

rules:
  # ... your rules
```

### Engram Mode

Store model configuration in Engram project context:

```markdown
# Project Context: my-project

## SDD Models
- default: (agent default)
- sdd-explore: anthropic/claude-sonnet-4
- sdd-design: anthropic/claude-sonnet-4
- sdd-apply: openrouter/qwen/qwen3-30b
```

## Example Profiles

### Cost-Optimized Profile

Minimize costs while maintaining quality where it matters:

```yaml
models:
  default: "openrouter/qwen/qwen3-30b:free"
  sdd-explore: "anthropic/claude-sonnet-4"
  sdd-spec: "anthropic/claude-sonnet-4"
  sdd-design: "anthropic/claude-sonnet-4"
  sdd-apply: "openrouter/qwen/qwen3-30b:free"
```

### Quality-First Profile

Use powerful models everywhere:

```yaml
models:
  default: "anthropic/claude-sonnet-4"
```

### Speed-First Profile

Use fast models everywhere (for prototyping):

```yaml
models:
  default: "openrouter/qwen/qwen3-30b"
```

### Hybrid Profile (Recommended)

Balance cost, quality, and speed:

```yaml
models:
  default: ""
  sdd-explore: "anthropic/claude-sonnet-4"
  sdd-spec: "anthropic/claude-sonnet-4"
  sdd-design: "anthropic/claude-sonnet-4"
  sdd-apply: "openrouter/qwen/qwen3-30b"
```

## How It Works

1. **sdd-init** generates `openspec/config.yaml` with empty `models:` section
2. User customizes model assignments per phase
3. **sdd-orchestrator** reads config before launching each sub-agent
4. Orchestrator requests the configured model for each phase
5. If model is empty or missing, uses `models.default` or agent's default

## Model Identifiers

Use the format your AI client expects:

| Client | Format | Example |
|--------|--------|---------|
| OpenCode | `provider/model` | `anthropic/claude-sonnet-4` |
| OpenRouter | `openrouter/provider/model` | `openrouter/qwen/qwen3-30b` |
| Ollama | `ollama/model` | `ollama/llama3` |

## Benefits

- **Cost optimization**: Use cheap models for implementation, expensive for design
- **Quality where it matters**: Critical phases get powerful reasoning
- **Flexibility**: Change models per project without code changes
- **Transparency**: Model choices are documented in config
