---
name: sdd-propose
description: >
  Create a change proposal with intent, scope, and approach.
  Trigger: "propose", "propuesta", "proposal", "new change",
  "nuevo cambio", "sdd new", "sdd propose", "/sdd:new",
  "sdd:ff", "fast-forward", "fast forward".

  When triggered by "sdd:ff" or "fast-forward": after creating the proposal,
  AUTOMATICALLY continue by executing sdd-spec, sdd-design, and sdd-tasks
  in sequence (do NOT stop after the proposal).

metadata:
  author: Yoizen
  version: "2.1"
---

## Purpose

You are a sub-agent responsible for creating PROPOSALS. You take the exploration analysis (or direct user input) and produce a structured `proposal.md` document inside the change folder.

## What You Receive

From the orchestrator:
- Change name (e.g., "add-dark-mode")
- Exploration analysis (from sdd-explore) OR direct user description
- Project config from `.sdd/config.yaml` (if exists)
- Any existing specs from `.sdd/specs/` relevant to this change

## Execution Contract

**This skill ALWAYS creates files on disk.** When invoked, you MUST create the `proposal.md` file in the change directory. Do NOT skip file creation or resolve to a "none" mode.
- Never force `.sdd/` creation unless user requested file-based persistence or project already uses it.

## What to Do

### Step 1: Create Change Directory

Create the change folder structure:

```
.sdd/changes/{change-name}/
└── proposal.md
```

### Step 2: Read Existing Specs

If `.sdd/specs/` has relevant specs, read them to understand current behavior that this change might affect.

### Step 3: Write proposal.md

```markdown
# Proposal: {Change Title}

## Intent

{What problem are we solving? Why does this change need to happen?
Be specific about the user need or technical debt being addressed.}

## Scope

### In Scope
- {Concrete deliverable 1}
- {Concrete deliverable 2}
- {Concrete deliverable 3}

### Out of Scope
- {What we're explicitly NOT doing}
- {Future work that's related but deferred}

## Approach

{High-level technical approach. How will we solve this?
Reference the recommended approach from exploration if available.}

### Alternatives Considered

| Approach | Summary | Why Rejected |
|----------|---------|-------------|
| {Alternative 1} | {brief description} | {reason} |
| {Alternative 2} | {brief description} | {reason} |

## Effort Estimation

- **Size**: {XS / S / M / L / XL}
- **Estimated files**: {N new, M modified, K deleted}
- **Complexity drivers**: {what makes this easy/hard}
- **Suggested SDD depth**: {full pipeline / fast-track(proposal→tasks→apply)}

> | Size | Guideline |
> |------|----------|
> | XS | Single file, < 50 lines changed |
> | S | 1-3 files, straightforward |
> | M | 4-10 files, some design decisions |
> | L | 10+ files, cross-module, needs design |
> | XL | Architecture change, multi-phase |

## Affected Areas

| Area | Impact | Description |
|------|--------|-------------|
| `path/to/area` | New/Modified/Removed | {What changes} |

## Risks

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| {Risk description} | Low/Med/High | {How we mitigate} |

## Rollback Plan

{How to revert if something goes wrong. Be specific.}

## Dependencies

- {External dependency or prerequisite, if any}

## Success Criteria

- [ ] {Specific, measurable outcome — e.g., "API returns 200 for valid requests"}
- [ ] {Testable condition — e.g., "All new endpoints have >80% test coverage"}
- [ ] {Observable result — e.g., "Dashboard loads in <2s with 1000 records"}
```

### Step 4: Return Summary

Return to the orchestrator:

```markdown
## Proposal Created

**Change**: {change-name}
**Location**: .sdd/changes/{change-name}/proposal.md

### Summary
- **Intent**: {one-line summary}
- **Scope**: {N deliverables in, M items deferred}
- **Approach**: {one-line approach}
- **Effort**: {XS/S/M/L/XL}
- **Risk Level**: {Low/Medium/High}

### Next Step
Ready for specs (sdd-spec) or design (sdd-design).
```

## Error Recovery

| Situation | Action |
|-----------|--------|
| Exploration was not done first | Read the codebase yourself to fill gaps; note assumptions |
| Change name conflicts with existing change | Suggest alternative name or ask orchestrator to continue/replace |
| Scope is too large for one proposal | Suggest splitting into sequential changes; create the first one |
| User requirements are contradictory | List contradictions and ask orchestrator for resolution |
| Cannot determine rollback strategy | Flag as HIGH risk; suggest feature flags or phased rollout |

## Rules

- ALWAYS create the `proposal.md` file
- If the change directory already exists with a proposal, READ it first and UPDATE it
- Keep the proposal CONCISE — it's a thinking tool, not a novel
- Every proposal MUST have a rollback plan
- Every proposal MUST have measurable success criteria
- Every proposal MUST have an effort estimation
- Use concrete file paths in "Affected Areas" when possible
- If effort is XL, recommend breaking into smaller changes
- Apply any `rules.proposal` from `.sdd/config.yaml`
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
