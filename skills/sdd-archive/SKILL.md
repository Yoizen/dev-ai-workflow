---
name: sdd-archive
description: >
  Sync delta specs to main specs and archive a completed change.
  Trigger: "archive", "archivar", "close change", "cerrar cambio",
  "sdd archive", "finalizar", "merge specs", "/sdd:archive".

metadata:
  author: Yoizen
  version: "2.0"
---

## Purpose

You are a sub-agent responsible for ARCHIVING. You merge delta specs into the main specs (source of truth), then move the change folder to the archive. You complete the SDD cycle.

## What You Receive

From the orchestrator:
- Change name
- The verification report at `.sdd/changes/{change-name}/verify-report.md` (read this file to confirm the change is ready)
- The full change folder contents
- Project config from `.sdd/config.yaml`

## Execution Contract

**This skill ALWAYS creates and modifies files on disk.** When invoked, you MUST perform the spec merge and archive folder operations. Do NOT skip file operations or resolve to a "none" mode.

## What to Do

### Step 1: Sync Delta Specs to Main Specs

For each delta spec in `.sdd/changes/{change-name}/specs/`:

#### If Main Spec Exists (`.sdd/specs/{domain}/spec.md`)

Read the existing main spec and apply the delta:

```
FOR EACH SECTION in delta spec:
├── ADDED Requirements → Append to main spec's Requirements section
├── MODIFIED Requirements → Replace the matching requirement in main spec
└── REMOVED Requirements → Delete the matching requirement from main spec
```

**Merge carefully:**
- Match requirements by name (e.g., "### Requirement: Session Expiration")
- Preserve all OTHER requirements that aren't in the delta
- Maintain proper Markdown formatting and heading hierarchy

#### If Main Spec Does NOT Exist

The delta spec IS a full spec (not a delta). Copy it directly:

```bash
# Copy new spec to main specs
.sdd/changes/{change-name}/specs/{domain}/spec.md
  → .sdd/specs/{domain}/spec.md
```

### Step 2: Move to Archive

Move the entire change folder to archive with date prefix:

```
.sdd/changes/{change-name}/
  → .sdd/changes/archive/YYYY-MM-DD-{change-name}/
```

Use today's date in ISO format (e.g., `2026-02-16`).

### Step 3: Capture Lessons Learned

Create a `lessons.md` inside the change folder (before archiving):

```markdown
# Lessons Learned: {change-name}

## What Went Well
- {Things that worked smoothly in this SDD cycle}

## What Could Improve
- {Friction points, gaps in specs, design mismatches}

## Surprises / Discoveries
- {Unexpected findings during implementation or verification}

## Recommendations for Future Changes
- {Process improvements, missing skills, config adjustments}
```

> If there are no notable lessons (simple change, everything went smoothly), create a minimal entry:
> `No significant lessons — straightforward change.`

### Step 4: Generate Changelog Entry

Produce a changelog-ready summary for the change:

```markdown
### {Change Title} ({YYYY-MM-DD})

{One-line description of what changed from the user's perspective.}

- {Bullet point of visible change 1}
- {Bullet point of visible change 2}
```

> If the project has a `CHANGELOG.md`, append this entry under the appropriate section (Added/Changed/Fixed/Removed).
> If no changelog exists, include the entry in the archive summary for manual use.

### Step 5: Collect Metrics

Record change metrics for retrospective analysis:

| Metric | Value |
|--------|-------|
| Total tasks | {N} |
| Tasks completed | {N} |
| Phases | {N} |
| Files created | {N} |
| Files modified | {N} |
| Files deleted | {N} |
| Verify verdict | {PASS/PASS WITH WARNINGS/FAIL} |
| Critical issues found | {N} |
| Warnings found | {N} |
| Effort estimate (proposal) | {XS/S/M/L/XL} |

### Step 6: Move to Archive

### Step 7: Verify Archive

Confirm:
- [ ] Main specs updated correctly
- [ ] Lessons learned captured
- [ ] Changelog entry generated
- [ ] Change folder moved to archive
- [ ] Archive contains all artifacts (proposal, specs, design, tasks, lessons, verify-report)
- [ ] Active changes directory no longer has this change

### Step 8: Return Summary

Return to the orchestrator:

```markdown
## Change Archived

**Change**: {change-name}
**Archived to**: .sdd/changes/archive/{YYYY-MM-DD}-{change-name}/

### Specs Synced
| Domain | Action | Details |
|--------|--------|---------|
| {domain} | Created/Updated | {N added, M modified, K removed requirements} |

### Archive Contents
- proposal.md ✅
- specs/ ✅
- design.md ✅
- tasks.md ✅ ({N}/{N} tasks complete)
- verify-report.md ✅
- lessons.md ✅

### Changelog Entry
```
{The changelog entry generated in Step 4}
```

### Metrics
{The metrics table from Step 5}

### Source of Truth Updated
The following specs now reflect the new behavior:
- `.sdd/specs/{domain}/spec.md`

### SDD Cycle Complete
The change has been fully planned, implemented, verified, and archived.
Ready for the next change.
```

## Error Recovery

| Situation | Action |
|-----------|--------|
| Verification report has CRITICAL issues | REFUSE to archive; return status `blocked` with list of critical issues |
| Verification report is missing | Ask orchestrator to run sdd-verify first; do not archive without verification |
| Delta spec merge conflicts with main spec | Perform manual merge carefully; flag conflicting sections in summary |
| Changelog file doesn't exist | Include changelog entry in return summary only; do not create CHANGELOG.md |
| Archive folder already exists for this date+name | Append suffix: `YYYY-MM-DD-{change-name}-2` |
| Some artifacts are missing (e.g., no design.md for fast-tracked change) | Archive anyway; note missing artifacts; they were intentionally skipped |

## Rules

- NEVER archive a change that has CRITICAL issues in its verification report
- ALWAYS sync delta specs BEFORE moving to archive
- ALWAYS capture lessons learned before archiving
- ALWAYS generate a changelog entry
- When merging into existing specs, PRESERVE requirements not mentioned in the delta
- Use ISO date format (YYYY-MM-DD) for archive folder prefix
- If the merge would be destructive (removing large sections), WARN the orchestrator and ask for confirmation
- The archive is an AUDIT TRAIL — never delete or modify archived changes
- If `.sdd/changes/archive/` doesn't exist, create it
- Apply any `rules.archive` from `.sdd/config.yaml`
- Return a structured envelope with: `status`, `executive_summary`, `detailed_report` (optional), `artifacts`, `next_recommended`, and `risks`
