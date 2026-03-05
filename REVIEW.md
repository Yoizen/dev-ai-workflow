# Code Review Rules - AI Development Workflow

The reviewer must verify **each** of these points before approving the PR.
Any violation of points marked as 🛑 **BLOCKING** requires immediate changes.


## 1. 🏗 Architecture & Structure (🛑 BLOCKING)
- [ ] **Skill Structure**: New skills follow the established pattern in `ywai/skills/` with proper `SKILL.md` metadata.
- [ ] **Setup Extensions**: Extensions in `ywai/extensions/` follow the template structure and are properly wired.
- [ ] **Single Responsibility**: Each skill/extension does one thing well.
- [ ] **Size Limits**:
    - [ ] No skill script exceeds **300 lines**.
    - [ ] No function exceeds **80 lines**.
    - [ ] Setup scripts are modular and readable.

## 2. 🛡 Security & Performance (🛑 BLOCKING)
- [ ] **NO Hardcoded Secrets**: No keys, tokens, or passwords in setup scripts or skills.
- [ ] **Input Validation**: Setup scripts validate user inputs and environment.
- [ ] **Network Safety**: All external downloads use HTTPS and verify integrity when possible.
- [ ] **Performance**: Setup scripts don't perform unnecessary operations and have reasonable timeouts.

## 3. 🧹 Clean Code & Standards
- [ ] **Shell Scripts**: 
    - [ ] Use `set -euo pipefail` for error handling
    - [ ] Variables are properly quoted: `"$VAR"` not `$VAR`
    - [ ] Functions are defined before use
- [ ] **PowerShell Scripts**:
    - [ ] Use `Set-StrictMode -Version Latest`
    - [ ] Proper error handling with `try/catch`
    - [ ] Follow PowerShell naming conventions
- [ ] **Markdown**: All documentation follows consistent formatting and has proper links.
- [ ] **JSON**: Configuration files are valid JSON with proper indentation.

## 4. 🔧 Setup & Installation
- [ ] **Cross-Platform**: Setup works on macOS, Linux, and Windows where applicable.
- [ ] **Dependencies**: Required tools are checked and installation instructions are clear.
- [ ] **Idempotency**: Running setup multiple times doesn't break the installation.
- [ ] **Cleanup**: Setup provides uninstall or cleanup options where appropriate.
- [ ] **Version Management**: Setup respects version pins and provides upgrade paths.

## 5. 🤖 AI Agent Integration
- [ ] **Skill Metadata**: All skills have proper `SKILL.md` with trigger words and descriptions.
- [ ] **Auto-invoke**: Skills are properly registered in AGENTS.md auto-invoke tables.
- [ ] **Global Agents**: Global agent templates in `ywai/extensions/install-steps/global-agents/templates/` are consistent.
- [ ] **Bundle Configuration**: Agent bundles in `bundles.json` are properly defined.

## 6. 📝 Documentation & Maintainability
- [ ] **README Updates**: New features are documented in relevant README files.
- [ ] **Examples**: Usage examples are provided and tested.
- [ ] **Dead Code**: No commented-out code or unused files.
- [ ] **TODOs**: If a `TODO` exists, it must have an associated issue ID.
- [ ] **Links**: All internal links work and point to correct files/sections.

## 7. 🧪 Testing & Validation
- [ ] **Setup Testing**: New setup options are tested on at least one platform.
- [ ] **Skill Testing**: Skills have basic validation or examples.
- [ ] **Documentation Testing**: Code examples in documentation are copy-pastable.
- [ ] **Integration**: Changes don't break existing workflows or installations.

## 8. 🌐 Internationalization
- [ ] **Language Consistency**: Choose English or Spanish per file and stick to it.
- [ ] **User Messages**: Setup scripts provide clear, user-friendly error messages.
- [ ] **Documentation**: Critical documentation is available in both languages when appropriate.

---

## Technology-Specific Rules

### Shell Scripts (bash/sh)
- [ ] Use `#!/usr/bin/env bash` shebang
- [ ] Prefer `[[ ]]` over `[ ]` for conditionals
- [ ] Use local variables in functions
- [ ] Handle signals and cleanup properly

### PowerShell Scripts (.ps1)
- [ ] Use `#Requires -Version X.X` for version requirements
- [ ] Implement proper logging with `Write-Verbose`/`Write-Warning`
- [ ] Use approved verbs for function names (Get, Set, New, etc.)

### YAML/JSON Configuration
- [ ] Validate syntax before committing
- [ ] Use consistent indentation (2 spaces for YAML)
- [ ] Avoid duplicate keys or properties

### Markdown Documentation
- [ ] Use fenced code blocks with language specification
- [ ] All links are tested and working
- [ ] Tables are properly formatted and readable

---

## Review Process

1. **Automated Checks**: Run `validate-local.sh` and ensure it passes
2. **Manual Review**: Verify each checklist item above
3. **Testing**: Test setup/changes in a clean environment
4. **Documentation**: Verify all documentation is accurate and complete

---

*If this PR is an urgent Hotfix that violates a rule, it must bear the `waiver-approved` label and a linked technical debt ticket.*
