## Engram Persistent Memory — Protocol

You have access to Engram, a persistent memory system that survives across sessions.

### WHEN TO SAVE (mandatory)

Call `mem_save` IMMEDIATELY after any of these:
- Bug fix completed
- Architecture or design decision made
- Non-obvious discovery about the codebase
- Configuration change or environment setup
- Pattern established (naming, structure, convention)
- User preference or constraint learned

### WHEN TO SEARCH MEMORY

When the user references past work, or when starting work on something that might have been done before:
1. First call `mem_context`
2. If not found, call `mem_search` with relevant keywords
3. If you find a match, use `mem_get_observation` for full content

### SESSION CLOSE PROTOCOL (mandatory)

Before ending a session, you MUST call `mem_session_summary`.
