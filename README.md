# dev-ai-workflow — Extension Pack for gentle-ai

Additional technology and meta-skills layered on top of the [Gentleman Stack](https://github.com/Gentleman-Programming/gentle-ai).

---

## What is this?

- **gentle-ai** provides the base: SDD orchestrator, Engram, Context7, foundation skills, persona, and permissions.
- **This repo** adds technology-specific skills (React 19, Tailwind 4, Angular, .NET, DevOps, Playwright, Biome, TypeScript) and meta-skills (skill-creator, golang-code-style, gentleman-bubbletea).

---

## Quick Start

### 1. Install the base (gentle-ai)

Requires [Go](https://go.dev/dl/).

```bash
go install github.com/Gentleman-Programming/gentle-ai@latest

# Install the Gentleman Stack into your agent
gentle-ai install --agent opencode --preset ecosystem-only
```

Supported agents: `claude-code`, `opencode`, `gemini-cli`, `cursor`, `vscode-copilot`, `codex`, `windsurf`, `antigravity`.

### 2. Link extra skills from this repo

```powershell
# Windows
.\setup.ps1

# macOS / Linux
./setup.sh
```

This auto-detects installed agents and symlinks `skills/*` into each agent's skills directory (e.g., `~/.config/opencode/skills/`, `~/.windsurf/skills/`, `~/.claude/skills/`).

### 3. Initialize a project (AGENTS.md + REVIEW.md)

```powershell
# Windows
.\setup.ps1 -Init nest

# macOS / Linux
./setup.sh --init react
```

Available types: `generic`, `nest`, `react`, `dotnet`, `devops`.

---

## Project Structure

```
dev-ai-workflow/
├── skills/              # Extra technology skills
│   ├── angular/         # Angular (core, forms, performance, architecture)
│   ├── biome/           # Biome linter/formatter
│   ├── devops/          # Azure Pipelines, Helm, K8s
│   ├── dotnet/          # .NET / C#
│   ├── git-commit/      # Conventional commits
│   ├── playwright/      # E2E testing
│   ├── react-19/        # React 19 patterns
│   ├── tailwind-4/      # Tailwind CSS 4
│   ├── typescript/      # TypeScript best practices
│   ├── skill-creator/   # Create new agent skills
│   └── yz-ui/           # UI component library
│
├── .agents/
│   └── skills/          # Global meta-skills
│       ├── agents-md/
│       ├── gentleman-bubbletea/
│       ├── golang-code-style/
│       └── skill-creator/
│
├── project-types/       # Project-type templates (AGENTS.md + REVIEW.md)
│   ├── generic/
│   ├── nest/
│   ├── react/
│   ├── dotnet/
│   └── devops/
├── setup.ps1            # Windows setup script
├── setup.sh             # macOS/Linux setup script
├── AGENTS.md            # Project index
└── README.md            # This file
```

---

## Usage

### Simple tasks

Use your agent directly:

```text
> Agrega validación de email en el form de registro
```

### Complex features (SDD)

Use the SDD workflow provided by gentle-ai:

```bash
sdd:new feature-name     # Create proposal
sdd:ff feature-name      # Fast-forward: spec + design + tasks
/sdd-apply               # Implement tasks
/sdd-verify              # Validate implementation
/sdd:archive             # Archive when done
```

---

## Available Skills

### Technology Skills

| Skill | Technology |
|:---|:---|
| `typescript` | TypeScript |
| `react-19` | React 19 |
| `tailwind-4` | Tailwind CSS 4 |
| `biome` | Biome (linter/formatter) |
| `angular/*` | Angular (core, forms, performance, architecture) |
| `dotnet` | .NET / C# |
| `devops` | Azure Pipelines, Helm charts, Kubernetes |
| `playwright` | E2E testing (browser APIs, frameworks, CI/CD) |
| `git-commit` | Conventional commits |

### Meta Skills

| Skill | Purpose |
|:---|:---|
| `skill-creator` | Create new AI agent skills |
| `golang-code-style` | Go code style, formatting, and conventions |
| `gentleman-bubbletea` | Bubbletea TUI patterns for Gentleman.Dots installer |

---

## Contributing

- Issues: https://github.com/Yoizen/dev-ai-workflow/issues
- Upstream: https://github.com/Gentleman-Programming/gentle-ai
