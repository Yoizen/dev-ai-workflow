---
name: sdd-init
description: >
  Bootstrap the .sdd/ directory structure for Spec-Driven Development in any project.
  Trigger: "sdd init", "iniciar sdd", "initialize specs", "setup sdd", "bootstrap sdd",
  "configurar sdd", "preparar proyecto", "/sdd:init".

metadata:
  author: Yoizen
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for bootstrapping the Spec-Driven Development (SDD) structure in a project. You initialize the `.sdd/` directory and optionally create the project config.

## Execution and Persistence Contract

From the orchestrator:
- `artifact_store.mode`: `auto | file | none`

Resolution:
- If mode resolves to `file`, run full bootstrap and create `.sdd/`.
- If mode resolves to `none`, return detected context without writing project files.

## What to Do

### Step 1: Detect Project Context

Read the project to understand:
- Tech stack (check package.json, go.mod, pyproject.toml, Cargo.toml, *.csproj, etc.)
- Existing conventions (linters, test frameworks, CI/CD pipelines)
- Architecture patterns in use
- Monorepo vs single-project structure (check for workspaces, nx.json, lerna.json, turbo.json)
- Existing documentation patterns (ADRs, RFCs, CHANGELOG)

> **Monorepo detection**: If the project is a monorepo, initialize `.sdd/` at the root level.
> Individual packages/apps should reference the root `.sdd/config.yaml` unless they need independent SDD cycles.

### Step 2: Initialize Persistence Backend

If mode resolves to `file`, create this directory structure:

```
.sdd/
├── config.yaml              ← Project-specific SDD config
├── specs/                   ← Source of truth (empty initially)
└── changes/                 ← Active changes
    └── archive/             ← Completed changes
```

### Step 3: Generate Config (file mode)

Based on what you detected, create the config when in `file` mode:

```yaml
# .sdd/config.yaml
schema: spec-driven
schema_version: 2

context: |
  Tech stack: {detected stack}
  Architecture: {detected patterns}
  Testing: {detected test framework}
  Style: {detected linting/formatting}
  CI/CD: {detected pipeline}

rules:
  proposal:
    - Include rollback plan for risky changes
    - Identify affected modules/packages
    - Estimate effort using T-shirt sizes (XS/S/M/L/XL)
  specs:
    - Use Given/When/Then format for scenarios
    - Use RFC 2119 keywords (MUST, SHALL, SHOULD, MAY)
    - Assign traceability IDs to requirements (REQ-XXX)
    - Include non-functional requirements when relevant
  design:
    - Include sequence diagrams for complex flows
    - Document architecture decisions with rationale
    - Address security implications for public-facing changes
    - Address performance impact for data-heavy operations
  tasks:
    - Group tasks by phase (infrastructure, implementation, testing)
    - Use hierarchical numbering (1.1, 1.2, etc.)
    - Keep tasks small enough to complete in one session
    - Mark parallelizable tasks with ⊕ prefix
  apply:
    - Follow existing code patterns and conventions
    - Load relevant coding skills for the project stack
    - Create atomic commits per task or logical group
  verify:
    - Run tests if test infrastructure exists
    - Compare implementation against every spec scenario
    - Check for security regressions
    - Validate no performance degradation on critical paths
  archive:
    - Warn before merging destructive deltas (large removals)
    - Capture lessons learned for retrospective
```

### Step 4: Return Summary

Return a structured summary:

```
## SDD Initialized

**Project**: {project name}
**Stack**: {detected stack}
**Location**: .sdd/

### Structure Created
- .sdd/config.yaml ← Project config with detected context
- .sdd/specs/      ← Ready for specifications
- .sdd/changes/    ← Ready for change proposals

### Next Steps
Ready for /sdd:explore <topic> or /sdd:new <change-name>.
```

## Error Recovery

| Situation | Action |
|-----------|--------|
| `.sdd/` already exists | Read existing config, report current state, ask orchestrator whether to upgrade or skip |
| Cannot detect tech stack | Set context to "Unknown — manual configuration recommended" and proceed |
| Config file is corrupted | Back up to `.sdd/config.yaml.bak`, generate fresh config |
| Monorepo detected but ambiguous root | Ask orchestrator which directory should host `.sdd/` |
| Schema version mismatch (upgrading from v1) | Migrate config: add `schema_version: 2` and any new default rules |

## Rules

- NEVER create placeholder spec files — specs are created via sdd-spec during a change
- ALWAYS detect the real tech stack, don't guess
- If the project already has an `.sdd/` directory, report what exists and offer to upgrade the config to the latest schema version
- Keep config.yaml context CONCISE — no more than 10 lines
- If `.sdd/config.yaml` exists with `schema_version: 1`, offer migration to v2 (add new rule keys, preserve custom rules)
- When in a monorepo, note the workspace structure in config context
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
