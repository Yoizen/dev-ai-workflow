# GGA Agent Skills

This directory contains **Agent Skills** that follow the [Agent Skills](https://agentskills.io) standard. The skills capture domain-specific patterns, conventions, and guardrails so AI assistants (Claude Code, OpenCode, Cursor, etc.) understand project requirements.

## What Are Agent Skills?

[Agent Skills](https://agentskills.io) is an open standard that extends an AI agent with specialized knowledge. Originally created by Anthropic and released as an open specification, it is now adopted by multiple agent products.

Skills teach AI assistants how to execute a task. When an assistant loads a skill, it gains context about:

- Critical rules (what to ALWAYS/NEVER do)
- Code patterns and conventions
- Project-specific workflows
- References to detailed documentation

## Setup

Run the setup script so every supported AI tool can locate the skills:

```bash
./skills/setup.sh
```

The script creates symlinks so each tool discovers the same files:

| Tool | Symlink |
|------|---------|
| Claude Code / OpenCode | `.claude/skills/` |
| GitHub Copilot | `.github/skills/` |

After running the script, restart your AI assistant to reload the skills.

## How to Use the Skills

Skills are auto-discovered by the AI agent. To explicitly load one during a session:

```
Read skills/{skill-name}/SKILL.md
```

## Available Skills



### Development Skills

| Skill | Description | Use |
|-------|-------------|-----|
| `biome` | Biome linter and formatter | Lint/format code |
| `git-commit` | Commit standards and best practices | Create commits |


## Skill Structure

Each skill follows this layout:

```
├── SKILL.md              # Main instructions (frontmatter + markdown)
├── references/           # Detailed documentation and references
│   ├── TOPIC-1.md
│   ├── TOPIC-2.md
│   └── ...
├── scripts/              # Optional executable scripts
│   └── script.ts
└── assets/               # Static resources (diagrams, templates)
    └── diagram.png
```

### SKILL.md Format

Every SKILL.md contains YAML frontmatter followed by Markdown content:

```yaml
---
name: skill-name
description: >
  A clear description of what the skill does and when to use it.
  Trigger: When working in X area or doing Y task.
license: Apache-2.0
metadata:
  author: GGA Team
  version: "1.0"
  scope: [root, area1, area2]
  auto_invoke:
    - "keyword1"
    - "keyword2"
allowed-tools: Read, Edit, Write, Glob, Grep, Bash, WebFetch, WebSearch, Task
---
```

## Skill Auto-Invocation

The assistant scans your request for keywords and auto-loads the matching skill:

| Keyword | Skill Loaded |
|---------|--------------|
| "biome", "lint", "format" | `biome` |
| "commit", "git commit" | `git-commit` |


### Manual Loading

You can always force-load a specific skill:

- "Using the web-executor skill, create..."
- "Load the analytics skill to generate metrics"
- "With the testing skill, write tests for..."

## Related Skills

Each skill exposes a "Related Skills" section so you can hop across project areas quickly.

## Skill Maintenance

- Whenever you update code in an area, update the skill as well
- Keep skills synchronized with the codebase
- Periodically confirm that the `auto_invoke` keywords are still relevant

## Validation

Use the Agent Skills validation tool before committing skill updates:

```bash
skills-ref validate ./skills/skill-name
```

The tool checks that the SKILL.md frontmatter is valid and that naming conventions are honored.

## Resources

- **Agent Skills Specification**: https://agentskills.io/specification


## Contribution

To add a new skill:

1. Create the directory `skills/new-skill-name/`
2. Create `SKILL.md` with valid frontmatter
3. Add a `references/` folder with detailed docs
4. Validate using `skills-ref validate`
5. Add the skill to this README
6. Update the implementation plan if needed
