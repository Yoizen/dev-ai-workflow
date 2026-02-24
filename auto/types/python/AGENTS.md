# Python Engineering Constitution & AI Agent Directives

## Part 1: Core Principles (NON-NEGOTIABLE)

### I. Technology & Version Lock
- **Runtime**: Python 3.11+ (defined in `.python-version` or `pyproject.toml`).
- **Type Hints**: Mandatory. All functions and methods must have full type annotations.
- **Package Manager**: `uv` preferred. `pip` acceptable. Never mix both.
- **Legacy Code Policy**: Untyped or non-PEP8 code is considered "Legacy". Refactor, don't extend.

### II. Architecture Strategy
- Follow **Clean Architecture** or **Hexagonal Architecture** depending on project size.
- **Domain Layer**: Pure Python classes, no framework dependencies (no FastAPI, Django ORM).
- **Application Layer**: Use cases / services. Depends only on domain interfaces.
- **Infrastructure Layer**: FastAPI routes, Django views, SQLAlchemy models, external APIs.

### III. Security-First
- **Zero Trust**: All external calls over HTTPS.
- **Secrets Management**: Use `python-dotenv` or environment variables. Never hardcode.
- ❌ `API_KEY = "sk-1234"` → Immediate BLOCK.
- **Input Validation**: Use `pydantic` models for all external input.
- **SQL Injection**: Always use parameterized queries or ORM — never f-strings in SQL.
- **Dependency Audit**: Run `pip audit` or `safety check` periodically.

### IV. Code Quality
- **Linter**: `ruff` (replaces flake8 + isort + black).
- **Formatter**: `ruff format`.
- **Max Line Length**: 100 characters.
- **No bare `except:`** — always catch specific exceptions.
- **Type checking**: Use `mypy` or `pyright` in strict mode when available.

### V. Environment Management
- **Virtual environments**: Always use `venv`, `uv venv`, or `conda` — never install globally.
- **Lock files**: Maintain `requirements.lock`, `uv.lock`, or `poetry.lock` for reproducibility.
- **Python version**: Pin in `.python-version` or `pyproject.toml`'s `requires-python`.
- **Docker**: Use multi-stage builds with pinned base images (`python:3.12-slim`).

---

## Part 2: Coding Standards

### File & Complexity Limits

| Element | Max Limit | Recommended |
|:---|:---:|:---:|
| **File Length** | **400 lines** | 150-200 |
| **Function Length** | **60 lines** | 15-30 |
| **Parameters** | 4 args | 1-3 |
| **Cyclomatic Complexity** | 10 | < 5 |

### Naming Conventions

| Type | Convention | Example |
|:---|:---|:---|
| **Files/Modules** | `snake_case` | `user_service.py` |
| **Classes** | `PascalCase` | `UserService` |
| **Functions/Methods** | `snake_case` | `find_active_user()` |
| **Constants** | `SCREAMING_SNAKE` | `MAX_RETRY_COUNT` |
| **Private** | `_` prefix | `_internal_helper()` |

---

## Part 3: FastAPI Specifics (if applicable)

- All route parameters must use `pydantic` `BaseModel` for request/response.
- Use `Annotated` for dependency injection.
- Always define `response_model` on endpoints.
- Use `AsyncSession` for async database operations.
- Group routes in routers (`APIRouter`), never define all routes in `main.py`.
- Return proper HTTP status codes (201 for creation, 204 for deletion, etc.).
- Use `BackgroundTasks` for fire-and-forget operations.

### Async Patterns
- Prefer `async def` for I/O-bound routes.
- Use `sync_to_async` or thread pools for CPU-bound work inside async handlers.
- Never use `time.sleep()` in async code — use `asyncio.sleep()`.
- Use `asyncio.gather()` for concurrent I/O operations.
- Use `AsyncContextManager` for resource cleanup.

---

## Part 4: Testing & Reliability

- **Framework**: `pytest` + `pytest-asyncio` for async.
- All external calls must be mockable (use interfaces/protocols).
- Minimum coverage: **80%** for business logic.
- No `time.sleep()` in tests — use `asyncio.sleep` or fixtures.
- Use `factory_boy` or `faker` for test data generation.
- Use `pytest.mark.parametrize` for testing multiple scenarios from specs.
- Prefer `httpx.AsyncClient` over `TestClient` for async FastAPI tests.

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
