# Installation Guide (LLM-Driven)

This guide is designed to be consumed by coding chats (Copilot, Claude Code, etc.) so they can configure an existing repository with smart rule sync.

## 1) Fetch this guide

```bash
curl -s https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/docs/guide/installation.md
```

## 2) Detect project type from the current repo

Use the repository context and map to one of:

- `nest`
- `nest-angular`
- `nest-react`
- `python`
- `dotnet`
- `qa-playwright`
- `devops`
- `generic`

If uncertain, use `generic`.

## 3) Run smart sync

Preferred (auto-detect type):

```bash
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/latest/ywai/setup/setup.sh | bash -s -- --llm-sync
```

Explicit type:

```bash
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/latest/ywai/setup/setup.sh | bash -s -- --llm-sync --type=nest-react
```

## 4) What `--llm-sync` updates

- Smart update for `AGENTS.md` using managed blocks (preserves custom content outside managed block)
- Smart update for `REVIEW.md` using managed blocks
- Sync project `skills/` (type skills + SDD skills without clobbering existing custom skills)
- Runs skill metadata sync for Auto-invoke tables when `skills/skill-sync/assets/sync.sh` is present
- Applies/updates `biome.json` and package scripts when `package.json` exists

## 5) Validate

After running sync, review:

- `AGENTS.md`
- `REVIEW.md`
- `skills/`
- `biome.json` (if applicable)

Then commit normally.

## 6) Prompt template for chats

```text
Fetch and follow this installation guide:
curl -s https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/docs/guide/installation.md

Then run smart sync for the current repo with --llm-sync.
If type inference is ambiguous, choose the best matching type and explain why.
After applying changes, summarize AGENTS.md / REVIEW.md / skills / biome.json updates.
```
