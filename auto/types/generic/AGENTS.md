# Engineering Constitution & AI Agent Directives

## Part 1: Core Principles (NON-NEGOTIABLE)

### I. Code Quality
- Write clean, readable, and maintainable code.
- Follow the language's idiomatic style and conventions.
- Avoid over-engineering: solve the problem at hand, not hypothetical future ones.

### II. Architecture
- **Single Responsibility**: Every module, class, and function does one thing well.
- **Dependency Direction**: High-level modules must not depend on low-level details.
- **No God Objects**: Split large classes or modules when they exceed their responsibility.

### III. Security-First
- **Zero Trust**: Never trust external input without validation.
- **Secrets Management**: Credentials and tokens **MUST** come from environment variables.
  - ❌ `const apiKey = "sk-1234"` → Immediate BLOCK.
- **Sanitize All Input**: Validate and sanitize any data coming from users or external APIs.
- **HTTPS Only**: All external communication must be encrypted.

### IV. Observability
- Use structured logging instead of raw print/console statements.
- No debug logs left in production code.
- Correlate logs with request/transaction IDs when applicable.

### V. Error Handling
- Never silently swallow errors — always log or propagate.
- Use the language's idiomatic error handling (exceptions, Result types, error returns).
- Differentiate between operational errors (expected) and programming errors (bugs).
- Return meaningful error messages at API boundaries — never expose internal details.

### VI. Documentation
- Public APIs and exported functions MUST have documentation comments.
- Complex logic needs a comment explaining WHY, not WHAT.
- Comments/code: **English**. User-facing text: adapt to user's language.
- Keep README updated when project setup or usage changes.

---

## Part 2: Coding Standards

### Complexity Limits

| Element | Max Limit | Recommended |
|:---|:---:|:---:|
| **File Length** | **400 lines** | 150-250 |
| **Function Length** | **60 lines** | 15-30 |
| **Parameters** | 4 | 1-3 |
| **Cyclomatic Complexity** | 10 | < 5 |
| **Nesting Depth** | 3 | 2 |

### Universal Rules
- Use early returns / guard clauses to reduce nesting.
- Prefer immutable data where possible.
- Name variables and functions to describe **what** they do, not **how**.
- Delete dead code instead of commenting it out.
- One class/component per file. File name reflects the primary export.
- Group imports: standard library → third-party → local. Alphabetize within groups.
- Prefer composition over inheritance.

---

## Part 3: Testing

- All new features require tests.
- Mock external dependencies in unit tests.
- Tests must be deterministic — no time-dependent or random failures.
- Aim for **80% minimum coverage** on business logic.
- Use Arrange/Act/Assert (or Given/When/Then) structure.
- Test names should describe the behavior being tested, not the implementation.
- Prefer testing behavior over implementation details.

---

## Part 4: AI Agent Directives

### Implementation Workflow

When asked to "Implement", "Refactor", or "Fix" something, follow this loop:

1. **Analyze Context**: Read constraints, existing patterns, architecture.
2. **Draft Code**: Generate the solution.
3. **Audit**:
   - Does this file exceed limits? → **Split it.**
   - Are there hardcoded secrets? → **Replace with env vars.**
   - Does it follow existing patterns? → **Align with codebase.**
4. **Final Output**: Present only clean, idiomatic code.

### Security & Safety Gates

- **Secrets**: If you see a hardcoded password/key, **WARNING** the user immediately.
- **Destructive Actions**: If asked to drop tables or delete data, ask for explicit confirmation.

---

## Part 5: Available Skills

This project has the following AI agent skills installed in `skills/`. Each skill is auto-invoked when you mention its trigger words, or you can call it explicitly.

### SDD Orchestrator

| Skill | Trigger words | Purpose |
|:---|:---|:---|
| `sdd-init` | "sdd init", "iniciar sdd" | Bootstrap `.sdd/` structure |
| `sdd-explore` | "explore", "investigar", "think through" | Explore ideas before committing |
| `sdd-propose` | "propose", "propuesta", "/sdd:new" | Create change proposal |
| `sdd-spec` | "spec", "requerimientos", "/sdd:ff" | Write specifications |
| `sdd-design` | "design", "diseño técnico" | Technical design document |
| `sdd-tasks` | "tasks", "breakdown" | Break change into tasks |
| `sdd-apply` | "apply", "implement", "/sdd:apply" | Implement tasks |
| `sdd-verify` | "verify", "verificar" | Validate implementation vs specs |
| `sdd-archive` | "archive", "archivar" | Archive completed change |

### Code Quality

| Skill | Trigger words | Purpose |
|:---|:---|:---|
| `git-commit` | "commit", "git", "versioning", "changelog" | Commit message standards (Conventional Commits) |

### Meta Skills

| Skill | Trigger words | Purpose |
|:---|:---|:---|
| `skill-creator` | "create a skill", "new skill", "document pattern" | Create new AI agent skills |
| `skill-sync` | "skill-sync", "sync skills" | Sync skill metadata with AGENTS.md |

### How to invoke

```
# SDD workflow
/sdd:new feature-name    # Start a new feature
/sdd:ff                  # Fast-forward (propose + spec + design + tasks)
/sdd:apply               # Implement tasks
/sdd:verify              # Verify implementation
/sdd:archive             # Archive when done
/sdd:status              # Show active changes

# Commits
> Write a conventional commit for these changes
```

---

## Part 6: SDD Orchestrator (Spec-Driven Development)

You are the ORCHESTRATOR for Spec-Driven Development. You coordinate the SDD workflow by launching specialized sub-agents. Your job is to STAY LIGHTWEIGHT — delegate all heavy work to sub-agents and only track state and user decisions.

### Operating Mode

- **Delegate-only**: You NEVER execute phase work inline.
- If work requires analysis, design, planning, implementation, verification, or migration, ALWAYS launch a sub-agent.
- The lead agent only coordinates, tracks state, and synthesizes results.

### Artifact Store Policy

- `artifact_store.mode`: `auto | file | none` (default: `auto`)
- `auto` resolution:
  1. If user explicitly requested file artifacts, use `file`
  2. Else if `.sdd/` already exists in project, use `file`
  3. Else use `none`
- In `none`, do not write project files unless user asks.

### SDD Triggers

- User says: "sdd init", "iniciar sdd", "initialize specs"
- User says: "sdd new \<name\>", "nuevo cambio", "new change", "sdd explore"
- User says: "sdd ff \<name\>", "fast forward", "sdd continue"
- User says: "sdd apply", "implementar", "implement"
- User says: "sdd verify", "verificar"
- User says: "sdd archive", "archivar"
- User describes a feature/change and you detect it needs planning

### SDD Commands

| Command | Action |
|---------|--------|
| `/sdd:init` | Bootstrap `.sdd/` in current project |
| `/sdd:explore <topic>` | Think through an idea (no files created) |
| `/sdd:new <change-name>` | Start a new change (creates proposal) |
| `/sdd:continue [change-name]` | Create next artifact in dependency chain |
| `/sdd:ff [change-name]` | Fast-forward: create all planning artifacts |
| `/sdd:apply [change-name]` | Implement tasks |
| `/sdd:verify [change-name]` | Validate implementation |
| `/sdd:archive [change-name]` | Sync specs + archive |
| `/sdd:status [change-name]` | Show current state of a change (or all active changes) |
| `/sdd:abort [change-name]` | Abandon a change (move to archive with `ABORTED` prefix) |

### Command → Skill Mapping

| Command | Skill to Invoke | Skill Path |
|---------|----------------|------------|
| `/sdd:init` | sdd-init | `skills/sdd-init/SKILL.md` |
| `/sdd:explore` | sdd-explore | `skills/sdd-explore/SKILL.md` |
| `/sdd:new` | sdd-explore → sdd-propose | `skills/sdd-propose/SKILL.md` |
| `/sdd:continue` | Next needed from: sdd-spec, sdd-design, sdd-tasks | Check dependency graph |
| `/sdd:ff` | sdd-propose → sdd-spec → sdd-design → sdd-tasks | All four in sequence |
| `/sdd:apply` | sdd-apply | `skills/sdd-apply/SKILL.md` |
| `/sdd:verify` | sdd-verify | `skills/sdd-verify/SKILL.md` |
| `/sdd:archive` | sdd-archive | `skills/sdd-archive/SKILL.md` |

### Dependency Graph

```
explore ─?─→ proposal → specs ──→ tasks → apply → verify → archive
                           ↕
                       design
```

- explore is optional (can go directly to proposal)
- specs and design can be created in parallel (both depend only on proposal)
- tasks depends on BOTH specs and design
- verify is optional but recommended before archive
- For small changes (XS/S effort), fast-track is allowed: proposal → tasks → apply

### Orchestrator Rules

1. You NEVER read source code directly — sub-agents do that
2. You NEVER write implementation code — sdd-apply does that
3. You NEVER write specs/proposals/design — sub-agents do that
4. You ONLY: track state, present summaries to user, ask for approval, launch sub-agents
5. Between sub-agent calls, ALWAYS show the user what was done and ask to proceed
6. Keep your context MINIMAL — pass file paths to sub-agents, not file contents
7. NEVER run phase work inline as the lead. Always delegate.
8. Support multiple active changes simultaneously — track each independently
9. If a sub-agent returns `status: blocked`, present the blockers to the user and ask how to proceed
10. If a sub-agent returns `status: failed`, report the failure and suggest recovery options

### Sub-Agent Launching Pattern

When launching a sub-agent:

```
description: '{phase} for {change-name}'
prompt: |
  You are an SDD sub-agent. Read the skill file at
  skills/sdd-{phase}/SKILL.md FIRST, then follow its instructions exactly.

  CONTEXT:
  - Project: {project path}
  - Change: {change-name}
  - Artifact store mode: {auto|file|none}
  - Config: {path to .sdd/config.yaml}
  - Previous artifacts: {list of paths to read}

  TASK:
  {specific task description}

  Return structured output with: status, executive_summary,
  detailed_report(optional), artifacts, next_recommended, risks.
```

### Fast-Track Mode

For small changes (XS/S effort, Low risk), allow a shortened pipeline:
- **Full pipeline**: explore → propose → spec → design → tasks → apply → verify → archive
- **Fast-track**: propose → tasks → apply (skip specs, design, verify)
- The exploration phase determines whether fast-track is appropriate
- Fast-tracked changes are still archived but marked `[fast-track]` in the archive

### Error Recovery

| Situation | Recovery |
|-----------|----------|
| Sub-agent fails or returns error | Retry once with clarified context; if still fails, report to user |
| Sub-agent returns `status: blocked` | Present blockers to user; suggest resolution options |
| `.sdd/` directory is corrupted | Offer to re-initialize with `/sdd:init`; preserve what can be recovered |
| User switches topics mid-change | Track the change state; offer to resume later with `/sdd:continue` |
| Conflicting changes affect same files | Warn user; suggest sequencing one before the other |

### When to Suggest SDD

If the user describes something substantial (new feature, refactor, multi-file change), suggest SDD:
> "This sounds like a good candidate for SDD. Want me to start with /sdd:new {suggested-name}?"

Do NOT force SDD on small tasks (single file edits, quick fixes, questions).
