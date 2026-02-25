---
name: sdd-tasks
description: >
  Break down a change into an implementation task checklist.
  Trigger: "tasks", "breakdown", "task list", "desglosar", "tareas",
  "sdd tasks", "plan de implementación", "/sdd:continue (when design exists but tasks don't)".

metadata:
  author: Yoizen
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for creating the TASK BREAKDOWN. You take the proposal, specs, and design, then produce a `tasks.md` with concrete, actionable implementation steps organized by phase.

## What You Receive

From the orchestrator:
- Change name
- The `proposal.md` content
- The delta specs from `specs/`
- The `design.md` content
- Project config from `.sdd/config.yaml`

## Execution Contract

**This skill ALWAYS creates files on disk.** When invoked, you MUST create the `tasks.md` file in the change directory. Do NOT skip file creation or resolve to a "none" mode.

## What to Do

### Step 1: Analyze the Design

From the design document, identify:
- All files that need to be created/modified/deleted
- The dependency order (what must come first)
- Testing requirements per component

### Step 2: Write tasks.md

Create the task file:

```
.sdd/changes/{change-name}/
├── proposal.md
├── specs/
├── design.md
└── tasks.md               ← You create this
```

#### Task File Format

```markdown
# Tasks: {Change Title}

**Total Effort**: {sum of estimates} | **Critical Path**: Phase 1 → Phase 2 → Phase 3

## Phase 1: {Phase Name} (e.g., Infrastructure / Foundation)

- [ ] 1.1 {Concrete action — what file, what change} `[S]`
- [ ] 1.2 {Concrete action} `[S]`
- [ ] 1.3 {Concrete action} `[M]`

## Phase 2: {Phase Name} (e.g., Core Implementation)

- [ ] 2.1 {Concrete action} `[M]`
- [ ] ⊕ 2.2 {Concrete action — parallelizable with 2.3} `[S]`
- [ ] ⊕ 2.3 {Concrete action — parallelizable with 2.2} `[S]`
- [ ] 2.4 {Concrete action — depends on 2.2 + 2.3} `[M]`

## Phase 3: {Phase Name} (e.g., Testing / Verification)

- [ ] 3.1 {Write tests for REQ-XXX-001: scenario name} `[S]`
- [ ] 3.2 {Write tests for REQ-XXX-002: scenario name} `[S]`
- [ ] 3.3 {Verify integration between ...} `[M]`

## Phase 4: {Phase Name} (e.g., Cleanup / Documentation)

- [ ] 4.1 {Update docs/comments} `[XS]`
- [ ] 4.2 {Remove temporary code} `[XS]`
```

### Estimation Guide

| Size | Tag | Guideline |
|------|-----|----------|
| **XS** | `[XS]` | Trivial: rename, config change, comment update |
| **S** | `[S]` | Small: single function, simple test, one-file change |
| **M** | `[M]` | Medium: new module, complex function, integration work |
| **L** | `[L]` | Large: multi-file feature, complex algorithm. Consider splitting. |

> If a task is `[L]`, it should almost always be split into 2-3 `[S]`/`[M]` tasks.

### Parallelism Markers

- **⊕** prefix = task can run in parallel with adjacent ⊕ tasks in same phase
- No prefix = task is sequential (depends on the previous task)
- When multiple tasks are parallelizable, the orchestrator can assign them to separate sub-agent batches

### Task Writing Rules

Each task MUST be:

| Criteria | Example ✅ | Anti-example ❌ |
|----------|-----------|----------------|
| **Specific** | "Create `internal/auth/middleware.go` with JWT validation" | "Add auth" |
| **Actionable** | "Add `ValidateToken()` method to `AuthService`" | "Handle tokens" |
| **Verifiable** | "Test: `POST /login` returns 401 without token" | "Make sure it works" |
| **Small** | One file or one logical unit of work | "Implement the feature" |

### Definition of Done (per task)

A task is complete when:
1. The code change is written and saved
2. The code matches the relevant spec scenarios
3. The code follows the design decisions
4. The code passes linting (if configured)
5. The task is marked `[x]` in tasks.md

### Phase Organization Guidelines

```
Phase 1: Foundation / Infrastructure
  └─ New types, interfaces, database changes, config
  └─ Things other tasks depend on

Phase 2: Core Implementation
  └─ Main logic, business rules, core behavior
  └─ The meat of the change

Phase 3: Integration / Wiring
  └─ Connect components, routes, UI wiring
  └─ Make everything work together

Phase 4: Testing
  └─ Unit tests, integration tests, e2e tests
  └─ Verify against spec scenarios

Phase 5: Cleanup (if needed)
  └─ Documentation, remove dead code, polish
```

### Step 3: Return Summary

Return to the orchestrator:

```markdown
## Tasks Created

**Change**: {change-name}
**Location**: .sdd/changes/{change-name}/tasks.md

### Breakdown
| Phase | Tasks | Parallelizable | Effort | Focus |
|-------|-------|---------------|--------|-------|
| Phase 1 | {N} | {P} | {sum} | {Phase name} |
| Phase 2 | {N} | {P} | {sum} | {Phase name} |
| Phase 3 | {N} | {P} | {sum} | {Phase name} |
| Total | {N} | {P} | {sum} | |

### Critical Path
{The sequence of dependent tasks that determines the minimum number of implementation batches}

### Implementation Order
{Brief description of the recommended order and why}

### Next Step
Ready for implementation (sdd-apply).
```

## Error Recovery

| Situation | Action |
|-----------|--------|
| Design or specs are incomplete | Create tasks for known parts; add placeholder tasks marked `[BLOCKED]` for unclear parts |
| Task count exceeds 30 | Suggest splitting the change into multiple sequential changes |
| Dependencies form a cycle | Refactor the task structure to break the cycle; report to orchestrator |
| Cannot estimate a task size | Mark as `[M]` (default) and add a note that it may need splitting |
| Specs reference domains not in the design | Flag the gap; create a task to address it or report as blocker |

## Rules

- ALWAYS reference concrete file paths in tasks
- ALWAYS include effort estimates `[XS]`/`[S]`/`[M]`/`[L]` on each task
- Tasks MUST be ordered by dependency — Phase 1 tasks shouldn't depend on Phase 2
- Testing tasks should reference specific spec requirement IDs and scenarios
- Each task should be completable in ONE session (if tagged `[L]`, split it)
- Mark parallelizable tasks with ⊕ prefix
- Use hierarchical numbering: 1.1, 1.2, 2.1, 2.2, etc.
- NEVER include vague tasks like "implement feature" or "add tests"
- Apply any `rules.tasks` from `.sdd/config.yaml`
- If the project uses TDD, integrate test-first tasks: RED task (write failing test) → GREEN task (make it pass) → REFACTOR task (clean up)
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
