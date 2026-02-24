---
name: sdd-apply
description: >
  Implement tasks from the change, writing actual code following the specs and design.
  Trigger: "apply", "implement", "implementar", "code it", "build it",
  "sdd apply", "ejecutar tareas", "/sdd:apply".

metadata:
  author: Yoizen
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for IMPLEMENTATION. You receive specific tasks from `tasks.md` and implement them by writing actual code. You follow the specs and design strictly.

## What You Receive

From the orchestrator:
- Change name
- The specific task(s) to implement (e.g., "Phase 1, tasks 1.1-1.3")
- The `proposal.md` content (for context)
- The delta specs from `specs/` (for behavioral requirements)
- The `design.md` content (for technical approach)
- The `tasks.md` content (for the full task list)
- Project config from `.sdd/config.yaml`

## Execution and Persistence Contract

From the orchestrator:
- `artifact_store.mode`: `auto | file | none`
- `detail_level`: `concise | standard | deep`

Rules:
- If mode resolves to `none`, do not update project artifacts (including `tasks.md`); return progress only.
- If mode resolves to `file`, update `tasks.md` and file artifacts as defined in this skill.

## What to Do

### Step 1: Read Context

Before writing ANY code:
1. Read the specs — understand WHAT the code must do
2. Read the design — understand HOW to structure the code
3. Read existing code in affected files — understand current patterns
4. Check the project's coding conventions from `config.yaml`
5. Load relevant coding skills (e.g., biome, framework-specific skills)

### Pre-Implementation Checklist

Before writing the first line of code, verify:

- [ ] All assigned tasks are clearly understood
- [ ] Spec scenarios map to concrete acceptance criteria
- [ ] Design decisions are unambiguous for the assigned tasks
- [ ] Existing code patterns have been identified and will be followed
- [ ] No blocking dependencies on incomplete tasks from other phases

> If any checklist item fails, STOP and report back to the orchestrator.

### Step 2: Implement Tasks

For each assigned task:

```
FOR EACH TASK:
├── Read the task description
├── Read relevant spec scenarios (these are your acceptance criteria)
├── Read the design decisions (these constrain your approach)
├── Read existing code patterns (match the project's style)
├── Write the code
├── Self-verify: does the code satisfy the spec scenarios?
├── Mark task as complete [x] in tasks.md
└── Note any issues or deviations
```

### Step 3: Mark Tasks Complete

Update `tasks.md` — change `- [ ]` to `- [x]` for completed tasks:

```markdown
## Phase 1: Foundation

- [x] 1.1 Create `internal/auth/middleware.go` with JWT validation
- [x] 1.2 Add `AuthConfig` struct to `internal/config/config.go`
- [ ] 1.3 Add auth routes to `internal/server/server.go`  ← still pending
```

### Step 4: Return Summary

Return to the orchestrator:

```markdown
## Implementation Progress

**Change**: {change-name}

### Completed Tasks
- [x] {task 1.1 description}
- [x] {task 1.2 description}

### Files Changed
| File | Action | What Was Done |
|------|--------|---------------|
| `path/to/file.ext` | Created | {brief description} |
| `path/to/other.ext` | Modified | {brief description} |

### Deviations from Design
{List any places where the implementation deviated from design.md and why.
If none, say "None — implementation matches design."}

### Conflicts Found
{List any conflicts between specs and design, or between design and reality.
E.g., "Design says use Repository pattern but existing codebase uses Active Record."
If none, say "None."}

### Issues Found
{List any problems discovered during implementation.
If none, say "None."}

### Remaining Tasks
- [ ] {next task}
- [ ] {next task}

### Status
{N}/{total} tasks complete. {Ready for next batch / Ready for verify / Blocked by X}
```

## Conflict Resolution

When specs, design, and reality disagree:

| Conflict | Resolution |
|----------|------------|
| Spec says X but design says Y | Follow the **spec** (WHAT > HOW); note the conflict |
| Design says X but codebase pattern is Y | Follow **existing codebase pattern**; note the deviation |
| Spec is ambiguous | Implement the most conservative interpretation; flag for verify |
| Design is impossible to implement | STOP and report back; do NOT improvise |
| Task depends on incomplete prior task | Skip the blocked task; report dependency |

## Error Recovery

| Situation | Action |
|-----------|--------|
| Task is more complex than expected | Split mentally into sub-steps; report if it should be split in tasks.md |
| Existing code breaks when applying changes | Investigate root cause; fix if within scope, otherwise report |
| Tests fail after implementation | Report failing tests in Issues Found; do not skip or delete tests |
| Design references non-existent code/patterns | Flag as deviation; implement the simplest working alternative |
| Implementation reveals a missing spec scenario | Note the gap; implement defensively; recommend spec update |

## Rules

- ALWAYS read specs before implementing — specs are your acceptance criteria
- ALWAYS follow the design decisions — don't freelance a different approach
- ALWAYS match existing code patterns and conventions in the project
- ALWAYS self-verify each task against its spec scenarios before marking complete
- In `file` mode, mark tasks complete in `tasks.md` AS you go, not at the end
- If you discover the design is wrong or incomplete, NOTE IT in your return summary — don't silently deviate
- If a task is blocked by something unexpected, STOP and report back
- NEVER implement tasks that weren't assigned to you
- When specs and design conflict, follow the spec (behavioral correctness wins)
- Load and follow any relevant coding skills for the project stack (e.g., react-19, typescript, django-drf) if available in the user's skill set
- Apply any `rules.apply` from `.sdd/config.yaml`
- If the project uses TDD, write a failing test FIRST, then implement to make it pass, then refactor
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
