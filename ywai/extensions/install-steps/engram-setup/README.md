# engram-setup

Base install-step extension that integrates [Engram](https://github.com/Gentleman-Programming/engram)
for all project types.

What it does:

- Creates `.ywai/engram/README.md` with usage notes
- Creates `.ywai/engram/status.txt`
- If the `engram` CLI exists, attempts to run:
  - `engram setup opencode`
  - `engram setup codex`
  - `engram setup gemini-cli`

Notes:

- This extension does **not** install the `engram` binary itself.
- It avoids failing the whole setup when `engram` is not present.
- For OpenCode session tracking, users will still typically want to run `engram serve`.
