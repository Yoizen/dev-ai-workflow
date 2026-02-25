# GA + SDD Orchestrator Bootstrap - Automated Setup

This directory contains automation scripts to configure **GA (Guardian Agent)** and **SDD Orchestrator** (SDD sub-agents) in any repository with simple interactive prompts or automated mode.

## ⚡ Quick Install (One Command)

### Windows (PowerShell)

```powershell
# Download and run (interactive prompts)
irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1 | iex

# Install everything automatically (non-interactive)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -All

# Custom installation
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -InstallGA -Provider claude
```

### Linux/macOS (Bash)

```bash
# Download and run (interactive prompts)
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash

# Install everything automatically (non-interactive)
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --all

# Custom installation
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --install-ga --provider=claude
```

---

## 🎨 Installation Modes

### 1. Interactive Mode (Default)

Run without flags for simple Y/n prompts:

```bash
./bootstrap.sh              # Bash
.\bootstrap.ps1             # PowerShell
```

**Interactive Features:**
- ✅ System prerequisites check
- ✅ Simple Y/n prompts for each component
- ✅ Installation summary before proceeding
- ✅ Next steps after completion

**Auto-Detection:** The installer automatically detects non-interactive environments (CI/CD, piped input, Docker) and falls back to automated mode with `--all`.

### 2. Automated Mode (Non-Interactive)

Use flags for **unattended installation** in scripts, CI/CD, or one-liners:

```bash
# Install everything
./bootstrap.sh --all

# Selective installation
./bootstrap.sh --install-ga --install-sdd --skip-vscode

# With specific provider
./bootstrap.sh --all --provider=opencode

# Dry run to preview changes
./bootstrap.sh --all --dry-run

# Silent mode (minimal output)
./bootstrap.sh --all --silent
```

---

## 📋 What Does the Bootstrap Do?

The `bootstrap` script automatically:

1. **Verifies Prerequisites**: Git, Node.js, npm, VS Code (optional)
2. **Installs Components**:
   - **GA** (Guardian Agent) - Globally in `~/.local/share/yoizen/dev-ai-workflow`
   - **SDD Orchestrator** - SDD skills cloned into the project
   - **VS Code Extensions** - GitHub Copilot & Copilot Chat
  - **OpenCode Command Hooks (optional)** - Post-edit automation hooks
  - **Biome Baseline (optional)** - Minimal lint/format rules for new projects
3. **Configures the Target Repository**:
   - Copies `AGENTS.MD`, `REVIEW.md`
   - Copies `skills/` directory (OpenCode skills + SDD sub-agents)
   - Initializes GA (`.ga`)
   - Sets up `.vscode/settings.json`
    - Installs GA git hooks (or Lefthook if available)
    - Creates `lefthook.yml` from template (includes optional `biome-check` example when `biome.json` is present)

---

## 🎯 Command-Line Options

### Bash (bootstrap.sh)

#### Installation Options
| Flag | Description |
|------|-------------|
| `--all` | Install everything (non-interactive mode) |
| `--install-ga` | Install only GA |
| `--install-sdd` | Install only SDD Orchestrator |
| `--install-vscode` | Install only VS Code extensions |
| `--hooks` | Install OpenCode command hooks plugin |
| `--biome` | Install optional Biome baseline (minimal rules) |

#### Skip Options
| Flag | Description |
|------|-------------|
| `--skip-ga` | Skip GA installation |
| `--skip-sdd` | Skip SDD Orchestrator installation |
| `--skip-vscode` | Skip VS Code extensions |

#### Configuration
| Flag | Description | Example |
|------|-------------|---------|
| `--provider=<name>` | Set AI provider | `--provider=claude` |
| `--target=<path>` | Target directory | `--target=/path/to/project` |

#### Advanced
| Flag | Description |
|------|-------------|
| `--update-all` | Update all installed components |
| `--force` | Force reinstall/overwrite |
| `--silent` | Minimal output |
| `--dry-run` | Show what would be done without executing |
| `-h, --help` | Show help message |

### PowerShell (bootstrap.ps1)

#### Installation Options
| Parameter | Description |
|-----------|-------------|
| `-All` | Install everything (non-interactive mode) |
| `-InstallGA` | Install only GA |
| `-InstallSDD` | Install only SDD Orchestrator |
| `-InstallVSCode` | Install only VS Code extensions |
| `-Hooks` | Install OpenCode command hooks plugin |
| `-Biome` | Install optional Biome baseline (minimal rules) |

#### Skip Options
| Parameter | Description |
|-----------|-------------|
| `-SkipGA` | Skip GA installation |
| `-SkipSDD` | Skip SDD Orchestrator installation |
| `-SkipVSCode` | Skip VS Code extensions |

#### Configuration
| Parameter | Description | Example |
|-----------|-------------|---------|
| `-Provider <name>` | Set AI provider | `-Provider claude` |
| `-Target <path>` | Target directory | `-Target C:\path\to\project` |

#### Advanced
| Parameter | Description |
|-----------|-------------|
| `-UpdateAll` | Update all installed components |
| `-Force` | Force reinstall/overwrite |
| `-Silent` | Minimal output |
| `-DryRun` | Show what would be done without executing |
| `-Help` | Show help message |

---

## 🔧 AI Providers

| Provider | Description | When to Use |
|----------|-------------|-------------|
| `opencode` | OpenCode AI Coding Agent (default) | Recommended for most projects |
| `claude` | Anthropic Claude | Advanced reasoning, code analysis |
| `gemini` | Google Gemini | Multimodal support |
| `ollama` | Ollama (local models) | Privacy-first, offline work |

---

## 📖 Usage Examples

### Interactive Installation

```bash
# Bash - Simple Y/n prompts
./bootstrap.sh

# PowerShell - Simple Y/n prompts
.\bootstrap.ps1
```

### Automated Installation

```bash
# Install everything with default provider
./bootstrap.sh --all

# Install only GA with Claude
./bootstrap.sh --install-ga --provider=claude

# Install GA and SDD Orchestrator, skip VS Code
./bootstrap.sh --install-ga --install-sdd --skip-vscode

# Install optional Biome baseline for a new project
./bootstrap.sh --install-ga --install-sdd --biome

# Install OpenCode hooks + Biome baseline together
./bootstrap.sh --install-ga --hooks --biome

# Update all components in a specific project
./bootstrap.sh --update-all --target=/home/user/my-project

# Dry run to preview installation
./bootstrap.sh --all --dry-run

# Silent automated installation
./bootstrap.sh --all --silent
```

```powershell
# PowerShell - Install everything
.\bootstrap.ps1 -All

# PowerShell - Custom installation
.\bootstrap.ps1 -InstallGA -InstallSDD -Provider gemini

# PowerShell - Optional Biome baseline
.\bootstrap.ps1 -InstallGA -InstallSDD -Biome

# PowerShell - Hooks + Biome baseline together
.\bootstrap.ps1 -InstallGA -Hooks -Biome

# PowerShell - Update all
.\bootstrap.ps1 -UpdateAll -Target C:\Users\dev\project
```

### CI/CD Integration

```yaml
# .github/workflows/setup.yml
name: Setup GA + SDD Orchestrator

on:
  push:
    branches: [ main ]

jobs:
  setup:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup GA + SDD Orchestrator
        run: |
          curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/bootstrap.sh | bash -s -- --all --skip-vscode --silent
      
      - name: Run Guardian Agent
        run: ga run
```

### Multi-Project Setup

```bash
#!/bin/bash
# setup-all-projects.sh

PROJECTS=(
    "/home/user/project1"
    "/home/user/project2"
    "/home/user/project3"
)

for project in "${PROJECTS[@]}"; do
    echo "Configuring $project..."
    ./bootstrap.sh --all --target="$project"
done
```

---

## 📁 File Structure After Installation

```
your-project/
├── .ga                              # GA configuration
├── .git/
│   └── hooks/
│       └── pre-commit                # GA hook
├── AGENTS.MD                         # AI agent directives
├── REVIEW.md                         # Code review checklist
├── skills/                           # Skills directory
│   ├── README.md                     # Skills documentation
│   ├── git-commit/                   # Git commit skill
│   ├── skill-creator/                # Skill creation tool
│   ├── skill-sync/                   # Skill sync tool
│   ├── sdd-init/                     # SDD: Initialize project context
│   ├── sdd-explore/                  # SDD: Explore & research
│   ├── sdd-propose/                  # SDD: Write proposal
│   ├── sdd-spec/                     # SDD: Technical spec
│   ├── sdd-design/                   # SDD: Architecture design
│   ├── sdd-tasks/                    # SDD: Task breakdown
│   ├── sdd-apply/                    # SDD: Implement tasks
│   ├── sdd-verify/                   # SDD: Verify implementation
│   └── sdd-archive/                  # SDD: Archive completed work
├── .vscode/
│   └── settings.json                 # VS Code configuration
└── package.json
```

---

## 🔄 Update Management

### Automatic Update Detection

GA automatically detects when updates are available and prompts you to update:

```bash
# During bootstrap - detects and prompts for updates
./bootstrap.sh --install-ga

# Example output:
# ℹ GA directory already exists
# ℹ GA update available!
#   Current version: 1.0.0
# 
#   Update GA now? [Y/n]: 
```

### Update Commands

```bash
# Update GA globally and all configured repositories
./update-all.sh /path/to/repo1 /path/to/repo2

# Update GA only (skip repository configs)
./update-all.sh --update-tools-only

# Update repository configs only (skip GA)
./update-all.sh --update-configs-only /path/to/repo

# Force update (non-interactive)
./update-all.sh --force /path/to/repo

# Dry run (preview changes)
./update-all.sh --dry-run /path/to/repo

# Update specific component with force
./bootstrap.sh --install-ga --force
```

### Version Checking

The update system:
- ✅ Checks for new commits in the GA repository
- ✅ Displays current version from `package.json`
- ✅ Prompts before updating (unless `--force` is used)
- ✅ Displays new version after successful update
- ✅ Updates npm dependencies automatically

---

## 🛠 Troubleshooting

### "Git is not installed"
- **Windows**: Download from https://git-scm.com/download/win
- **Linux**: `sudo apt install git` (Ubuntu/Debian) or `sudo yum install git` (RHEL/CentOS)
- **macOS**: `brew install git`

### "Node.js is not installed"
- Download from https://nodejs.org/
- Or use nvm: https://github.com/nvm-sh/nvm

### "VS Code CLI not found"
- Open VS Code → `Ctrl+Shift+P` → "Shell Command: Install 'code' command in PATH"

### "Permission denied"
- **Windows**: Run PowerShell as Administrator
- **Linux/macOS**: Use `chmod +x bootstrap.sh`

### "Scripts won't execute"
- **PowerShell**: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
- **Bash**: `chmod +x *.sh`

### "Component detection failed"
```bash
# Test detectors manually
./lib/detector.sh
./lib/env-detect.sh
```

---

## 📚 Advanced Usage

### Custom Provider Configuration

After installation, edit `.ga` to customize your provider:

```bash
# Example .ga file
PROVIDER="claude"
API_KEY="your-api-key"
MODEL="claude-3-opus"
```

### Custom Installation Script

```bash
#!/bin/bash
# my-custom-install.sh

# Clone bootstrap scripts
git clone https://github.com/Yoizen/dev-ai-workflow.git /tmp/ga

# Run custom installation
/tmp/ga/auto/bootstrap.sh \
    --install-ga \
    --install-sdd \
    --provider=opencode \
    --target="$PWD" \
    --silent

# Cleanup
rm -rf /tmp/ga
```

---

## 🎓 Spec-First Methodology

This setup implements the **Spec-First** approach:

1. **Specify** before coding (use `/sdd:new` + `/sdd:ff`)
2. **Plan** the implementation
3. **Implement** following the spec (`/sdd:apply`)
4. **Review** with automated checklist (GA)
5. **Validate** against the spec (`/sdd:verify`)

See `REVIEW.md` for the complete checklist.

---

## 🤝 Contributing

To improve these scripts:

1. Edit `bootstrap.ps1` or `bootstrap.sh`
2. Test in a test repository
3. Update this README if adding options
4. Submit PR with changes

---

## 📞 Support

- **Documentation**: [GA README](../README.md)
- **Issues**: https://github.com/Yoizen/dev-ai-workflow/issues

---

## 📝 Version History

### v2.1.0 - Simplified Interactive Mode
- Replaced TUI with simple Y/n prompts
- Cleaner, more reliable interactive experience
- Same automation capabilities

### v2.0.0 - Full Automation
- Comprehensive flag support for automation
- Auto-detection of non-interactive environments
- Component detection with version checking
- Dry-run mode
- Silent mode
- Update-all functionality
- Provider selection (opencode/claude/gemini/ollama)

### v1.0.0 - Initial Release
- Basic bootstrap functionality
- Manual installation only
