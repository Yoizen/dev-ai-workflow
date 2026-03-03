# engram-setup

Base install-step extension that integrates [Engram](https://github.com/Gentleman-Programming/engram)
for all project types.

What it does:

- Creates `.ywai/engram/README.md` with usage notes
- Creates `.ywai/engram/status.txt`
- If the `engram` CLI is missing, attempts automatic installation (`brew` first, then GitHub release binary)
- After `engram` is available, attempts to run:
  - `engram setup opencode`
  - `engram setup codex`
  - `engram setup gemini-cli`
- Ensures `.vscode/mcp.json` includes the `engram` MCP server for Copilot

Notes:

- This extension makes `engram` mandatory for setup.
- If automatic installation fails, the extension exits with error and setup stops.
- For OpenCode session tracking, users will still typically want to run `engram serve`.
