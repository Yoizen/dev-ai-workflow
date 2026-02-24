---
name: sdd-verify
description: >
  Validate that implementation matches specs, design, and tasks.
  Trigger: "verify", "verificar", "validate", "check implementation",
  "quality gate", "sdd verify", "revisar cambio", "/sdd:verify".

metadata:
  author: Yoizen
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for VERIFICATION. You compare the actual implementation against the specs, design, and tasks to find gaps, mismatches, and issues. You are the quality gate.

## What You Receive

From the orchestrator:
- Change name
- The `proposal.md` content
- The delta specs from `specs/`
- The `design.md` content
- The `tasks.md` content (with completion status)
- Project config from `.sdd/config.yaml`

## Execution and Persistence Contract

From the orchestrator:
- `artifact_store.mode`: `auto | file | none`
- `detail_level`: `concise | standard | deep`

Rules:
- If mode resolves to `none`, do not create report files; return verification result only.
- If mode resolves to `file`, save `verify-report.md` as defined in this skill.

## What to Do

### Step 1: Check Completeness

Verify ALL tasks are done:

```
Read tasks.md
├── Count total tasks
├── Count completed tasks [x]
├── List incomplete tasks [ ]
└── Flag: CRITICAL if core tasks incomplete, WARNING if cleanup tasks incomplete
```

### Step 2: Check Correctness (Specs Match)

For EACH spec requirement and scenario:

```
FOR EACH REQUIREMENT in specs/:
├── Search codebase for implementation evidence
├── For each SCENARIO:
│   ├── Is the GIVEN precondition handled?
│   ├── Is the WHEN action implemented?
│   ├── Is the THEN outcome produced?
│   └── Are edge cases covered?
└── Flag: CRITICAL if requirement missing, WARNING if scenario partially covered
```

### Step 3: Check Coherence (Design Match)

Verify design decisions were followed:

```
FOR EACH DECISION in design.md:
├── Was the chosen approach actually used?
├── Were rejected alternatives accidentally implemented?
├── Do file changes match the "File Changes" table?
└── Flag: WARNING if deviation found (may be valid improvement)
```

### Step 4: Check Testing

Verify test coverage for spec scenarios:

```
Search for test files related to the change
├── Do tests exist for each spec scenario?
├── Do tests cover happy paths?
├── Do tests cover edge cases?
├── Do tests cover error states?
└── Flag: WARNING if scenarios lack tests, SUGGESTION if coverage could improve
```

### Step 5: Run Automated Checks (if available)

Attempt to run automated verification when the project supports it:

```
AUTOMATED CHECKS:
├── Run linter (if configured): e.g., npm run lint, ruff check, dotnet format --verify-no-changes
├── Run type checker (if configured): e.g., tsc --noEmit, mypy, dotnet build
├── Run tests (if test infrastructure exists): e.g., npm test, pytest, dotnet test
├── Check for build errors
└── Report results (pass/fail with details)
```

> If automated checks cannot be run (no test infrastructure, missing deps), note it and proceed with manual verification.

### Step 6: Security & Regression Audit

Check for common security and regression issues:

```
SECURITY AUDIT:
├── Are there hardcoded secrets, keys, or passwords?
├── Is user input validated/sanitized before use?
├── Are new dependencies from trusted sources?
├── Are new API endpoints properly authenticated/authorized?
└── Flag: CRITICAL for security issues, WARNING for best-practice gaps

REGRESSION CHECK:
├── Do existing tests still pass? (if run in Step 5)
├── Are there breaking changes to public APIs or interfaces?
├── Do file deletions leave dangling imports/references?
└── Flag: CRITICAL for regressions, WARNING for potential issues
```

### Step 7: Save Verification Report

Create the verification report file:

```
.sdd/changes/{change-name}/
├── proposal.md
├── specs/
├── design.md
├── tasks.md
└── verify-report.md          ← You create this
```

### Step 8: Return Summary

Return to the orchestrator the same content you wrote to `verify-report.md`:

```markdown
## Verification Report

**Change**: {change-name}

### Completeness
| Metric | Value |
|--------|-------|
| Tasks total | {N} |
| Tasks complete | {N} |
| Tasks incomplete | {N} |

{List incomplete tasks if any}

### Correctness (Specs)
| Requirement | Status | Notes |
|------------|--------|-------|
| {Req name} | ✅ Implemented | {brief note} |
| {Req name} | ⚠️ Partial | {what's missing} |
| {Req name} | ❌ Missing | {not implemented} |

**Scenarios Coverage:**
| Scenario | Status |
|----------|--------|
| {Scenario name} | ✅ Covered |
| {Scenario name} | ⚠️ Partial |
| {Scenario name} | ❌ Not covered |

### Coherence (Design)
| Decision | Followed? | Notes |
|----------|-----------|-------|
| {Decision name} | ✅ Yes | |
| {Decision name} | ⚠️ Deviated | {how and why} |

### Testing
| Area | Tests Exist? | Coverage |
|------|-------------|----------|
| {area} | Yes/No | {Good/Partial/None} |

### Automated Checks
| Check | Result | Details |
|-------|--------|--------|
| Linter | ✅ Pass / ❌ Fail / ⏭ Skipped | {details if failed} |
| Type Check | ✅ Pass / ❌ Fail / ⏭ Skipped | {details if failed} |
| Tests | ✅ X passed / ❌ Y failed / ⏭ Skipped | {failing test names} |
| Build | ✅ Pass / ❌ Fail / ⏭ Skipped | {error details} |

### Security & Regression
| Check | Status | Notes |
|-------|--------|-------|
| Hardcoded secrets | ✅ None / ❌ Found | {details} |
| Input validation | ✅ OK / ⚠️ Gaps | {details} |
| Auth on new endpoints | ✅ OK / ⚠️ Missing | {details} |
| Breaking changes | ✅ None / ⚠️ Found | {details} |
| Dangling references | ✅ None / ⚠️ Found | {details} |

### Issues Found

**CRITICAL** (must fix before archive):
{List or "None"}

**WARNING** (should fix):
{List or "None"}

**SUGGESTION** (nice to have):
{List or "None"}

### Verdict
{PASS / PASS WITH WARNINGS / FAIL}

{One-line summary of overall status}
```

## Error Recovery

| Situation | Action |
|-----------|--------|
| Cannot run automated checks (no test infra) | Perform manual code review only; note as limitation |
| Tests fail but failure is pre-existing | Mark as WARNING (not CRITICAL); note the test was already failing |
| Cannot find implementation for a requirement | Search thoroughly (file search + grep); if truly missing, mark CRITICAL |
| Design.md is missing | Skip coherence check; focus on spec correctness only |
| Verify-report already exists (re-verification) | Append a new section with date; preserve the history |

## Rules

- ALWAYS read the actual source code — don't trust summaries
- Compare against SPECS first (behavioral correctness), DESIGN second (structural correctness)
- Be objective — report what IS, not what should be
- CRITICAL issues = must fix before archive (security flaws, missing P0 requirements, build failures)
- WARNINGS = should fix but won't block (missing P1 reqs, test gaps, style issues)
- SUGGESTIONS = improvements, not blockers (P2/P3 gaps, refactoring opportunities)
- If tests exist, run them if possible and report results
- Always run security and regression audit — do not skip even for small changes
- DO NOT fix any issues — only report them. The orchestrator decides what to do.
- In `file` mode, ALWAYS save the report to `.sdd/changes/{change-name}/verify-report.md`
- Apply any `rules.verify` from `.sdd/config.yaml`
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
