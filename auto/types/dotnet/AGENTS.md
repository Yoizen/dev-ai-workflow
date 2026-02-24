# .NET / C# Engineering Constitution & AI Agent Directives

## Part 1: Core Principles (NON-NEGOTIABLE)

### I. Architecture (Clean Architecture)
- **Layers**: `Domain` → `Application` → `Infrastructure` → `Presentation`. Dependencies point **inward only**.
- Domain entities have **no framework dependencies** — no EF Core annotations in domain models.
- Application layer defines interfaces; Infrastructure implements them.
- No business logic in controllers, minimal-api handlers, or data access classes.

### II. C# Code Quality
- **Nullable reference types ON**: `<Nullable>enable</Nullable>` in every project.
- `async`/`await` all the way down — never `.Result` or `.Wait()` on tasks.
- Use `record` for immutable value objects and DTOs.
- Use primary constructors where it reduces boilerplate without hiding intent.
- Prefer `ImmutableList<T>` / `IReadOnlyList<T>` for collections exposed from domain.

### III. Security-First
- **Never** store secrets in `appsettings.json` — use environment variables or Azure Key Vault / AWS Secrets Manager.
- Always use parameterized queries or EF Core — **no raw SQL string interpolation**.
- Validate all input at the API boundary using FluentValidation or DataAnnotations.
- Use `[Authorize]` + policy-based authorization — no ad-hoc permission checks in service layers.
- Enable HTTPS redirection and HSTS in production.

### IV. Observability
- Use `ILogger<T>` — no `Console.WriteLine` in production code.
- Structured logging: log at the right level (`Debug`, `Information`, `Warning`, `Error`, `Critical`).
- Correlate requests with `Activity` / OpenTelemetry trace IDs.
- No sensitive data (PII, tokens) in logs.

### V. Containers & Deployment
- Use multi-stage Docker builds with `mcr.microsoft.com/dotnet/sdk` for build, `mcr.microsoft.com/dotnet/aspnet` for runtime.
- Implement health checks using `IHealthCheck` + `app.MapHealthChecks("/health")`.
- Store connection strings and secrets in Azure Key Vault, AWS Secrets Manager, or environment variables — never in `appsettings.json`.
- Use `.dockerignore` to exclude `bin/`, `obj/`, and `.git/`.

---

## Part 2: Coding Standards

### Complexity Limits

| Element | Max Limit | Recommended |
|:---|:---:|:---:|
| **File Length** | **400 lines** | 100-200 |
| **Method Length** | **60 lines** | 15-30 |
| **Parameters** | 5 | 1-3 |
| **Cyclomatic Complexity** | 10 | < 5 |
| **Nesting Depth** | 3 | 2 |

### Naming Conventions (Microsoft standard)
- Types, methods, properties: `PascalCase`
- Local variables, parameters: `camelCase`
- Private fields: `_camelCase`
- Constants: `PascalCase` (not `UPPER_SNAKE`)
- Interfaces: `IEntityName`
- Async methods: suffix `Async` — `GetUserAsync()`

### Formatting
- Use `dotnet format` before every commit.
- EditorConfig file at repo root must define `indent_style`, `indent_size`, `end_of_line`, `charset`.
- Prefer `var` when the type is obvious from the right-hand side; use explicit types otherwise.

### General Rules
- Early returns / guard clauses to reduce nesting.
- Avoid `this.` prefix unless resolving ambiguity.
- Delete dead code — no commented-out blocks committed.
- One class per file. File name matches class name exactly.

---

## Part 3: ASP.NET Core Standards

### Controllers / Minimal APIs
- Keep handlers thin: validate → call Application service → return result.
- Use `[ProducesResponseType]` attributes or typed results (`Results.Ok<T>`) for clear OpenAPI docs.
- Return `ProblemDetails` for errors (use `app.UseExceptionHandler` / `IProblemDetailsService`).
- Do not inject `DbContext` directly into controllers — use repositories or use-case services.

### Dependency Injection
- Register services with the correct lifetime: `Transient`, `Scoped`, `Singleton`.
- **Never inject `IServiceProvider` to manually resolve dependencies** — that's a service-locator anti-pattern.
- Use `IOptions<T>` for configuration binding, never raw `IConfiguration` in application services.

### Entity Framework Core
- Migrations live in `Infrastructure` project, never in domain or app layers.
- Configure entities via `IEntityTypeConfiguration<T>` — no data annotations on domain models.
- Always dispose or scope `DbContext` correctly (never a singleton DbContext).
- Use `AsNoTracking()` for read-only queries.

---

## Part 4: Testing

- **Unit**: xUnit + Moq (or NSubstitute). Test one class in isolation — mock all dependencies.
- **Integration**: `WebApplicationFactory<TProgram>` for API integration tests with a test database.
- **E2E**: Playwright or Selenium for critical user journeys (use sparingly).
- Minimum coverage: **80%** on Application layer (use-cases / services).
- Arrange / Act / Assert structure — one logical assertion per test.
- Test method naming: `MethodName_StateUnderTest_ExpectedBehavior`.
- No `Thread.Sleep` in tests — use `Task.Delay` only with proper cancellation, or mock time providers.
- Use `Respawn` or `Testcontainers` for integration test database management.
- Use `Bogus` for test data generation.

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
