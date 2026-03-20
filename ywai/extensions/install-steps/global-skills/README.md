# global-skills

Instala los skills de OpenCode/Copilot/Claude en las ubicaciones correctas de cada plataforma.

## Ubicaciones

### Windows
```
C:\Users\<username>\.config\opencode\skills\<skill>\SKILL.md
C:\Users\<username>\.copilot\skills\<skill>\SKILL.md
C:\Users\<username>\.claude\skills\<skill>\SKILL.md
C:\Users\<username>\.agents\skills\<skill>\SKILL.md
```

### Linux/macOS
```
~/.config/opencode/skills/<skill>/SKILL.md
~/.copilot/skills/<skill>/SKILL.md
~/.claude/skills/<skill>/SKILL.md
~/.agents/skills/<skill>/SKILL.md
```

## Skills instalados

- `sdd-*` (sdd-init, sdd-propose, sdd-spec, sdd-design, sdd-tasks, sdd-apply, sdd-verify, sdd-archive, sdd-explore)
- `skill-creator`, `skill-sync`
- `devops`, `playwright`, `typescript`, `tailwind-4`, `react-19`, `biome`, `dotnet`, `git-commit`
- `angular/*` (core, forms, performance, architecture)

## Notas

- Los skills se copian desde `ywai/skills/`
- Cada skill debe tener un archivo `SKILL.md` en su directorio
- Assets y references también se copian si existen
- No ejecuta scripts de setup - copia directa
