# Plan de Migración: GA (bash) → Go

## Estado: ✅ COMPLETADO

## Visión General

| Métrica | Actual | Meta |
|---------|--------|------|
| Archivos | 4 scripts bash | 1 binary Go |
| Líneas código | ~2500 | ~1500 (más legible) |
| Dependencias externas | bash, curl, python3, git | solo Go stdlib + Cobra |
| Testing | shellspec | Go testing |

## Problemas que Resuelve

- **Doble implementación**: Hoy hay lógica duplicada entre scripts
- **Difícil de mantener**: 2500 líneas en bash dispersas en múltiples archivos
- **Cross-platform**: Bash no corre nativamente en Windows
- **Testing**: Sin tests unitarios reales para la lógica de negocio

## Estructura del Proyecto Go

```
ywai/ga/
├── cmd/ga/main.go              # Entry point
├── internal/
│   ├── cmd/                     # Comandos (run, install, cache, etc.)
│   ├── config/                  # Carga y parseo de .ga
│   ├── providers/               # AI providers (claude, opencode, etc.)
│   │   ├── provider.go          # Interfaz + factory
│   │   ├── cli.go               # Claude, Gemini, Codex, OpenCode
│   │   ├── ollama.go            # Ollama API
│   │   ├── lmstudio.go          # LM Studio API
│   │   └── github.go            # GitHub Models API
│   ├── git/                     # Operaciones git
│   │   ├── staged.go            # Archivos staged
│   │   ├── ci.go                # Modo CI
│   │   ├── pr.go                # Modo PR
│   │   └── hooks.go             # Install/uninstall hooks
│   ├── cache/                   # Sistema de cache
│   │   └── cache.go             # Hash + cache metadata
│   ├── review/                  # Lógica de review
│   │   ├── prompt.go            # Build prompts
│   │   └── result.go            # Parseo de resultados
│   └── ui/                      # Output formatting
│       └── colors.go            # Colores + logging
└── go.mod
```

## Dependencias

| Paquete | Uso | Notas |
|---------|-----|-------|
| github.com/spf13/cobra | CLI framework | Solo dependencia externa |
| - | go.stdlib | Todo lo demás: flag, exec, hash, json, filepath |

## Fases de Implementación

### Fase 1: Foundation
- [ ] Inicializar `go.mod`
- [ ] Crear estructura de paquetes
- [ ] Implementar `config/` - cargar `.ga` (compatibilidad total)
- [ ] Implementar `ui/` - colores, logging

### Fase 2: Git Operations
- [ ] `git/staged.go` - obtener archivos staged
- [ ] `git/ci.go` - modo CI (`HEAD~1..HEAD`)
- [ ] `git/pr.go` - modo PR (detectar base branch, diff)
- [ ] `git/hooks.go` - install/uninstall hooks

### Fase 3: Providers
- [ ] `providers/provider.go` - interfaz + factory
- [ ] `providers/cli.go` - Claude, Gemini, Codex, OpenCode
- [ ] `providers/ollama.go` - REST API
- [ ] `providers/lmstudio.go` - REST API
- [ ] `providers/github.go` - GitHub Models (usa `gh auth token`)

### Fase 4: Cache
- [ ] `cache/cache.go` - hash SHA256 archivos
- [ ] Cache metadata (rules + config hash)
- [ ] Invalidación automática

### Fase 5: Review Logic
- [ ] `review/prompt.go` - construir prompts
- [ ] `review/result.go` - parsear STATUS: PASSED/FAILED
- [ ] Timeout con spinner

### Fase 6: CLI Commands
- [ ] `cmd/run` - comando principal
- [ ] `cmd/install` - instalar hooks
- [ ] `cmd/uninstall` - remover hooks
- [ ] `cmd/cache` - clear/status
- [ ] `cmd/config` - mostrar config
- [ ] `cmd/init` - crear .ga ejemplo
- [ ] `cmd/version` - versión

### Fase 7: Integración y Tests
- [ ] Tests unitarios para cada paquete
- [ ] Tests de integración (comparar output con bash)
- [ ] Build y distribución

## Compatibilidad hacia atrás

| Aspecto | Acción |
|---------|--------|
| `.ga` config | Parsear exactamente igual (formato bash export) |
| Flags CLI | Identicos: `--no-cache`, `--ci`, `--pr-mode`, `--diff-only` |
| Output | Colores ANSI iguales, mismo formato |
| Git hooks | Mismo formato de markers (`# ======== GA START ========`) |
| Cache location | `$HOME/.cache/ga/` (mismo path) |

## Commands

```bash
ga run [flags]           # Run review (alias: review)
ga install [flags]       # Install git hook (default: pre-commit)
ga uninstall             # Remove hooks
ga config                # Show config
ga init                  # Create sample .ga
ga cache <subcmd>        # clear, clear-all, status
ga version               # Show version
ga help                  # Help
```

## Providers Soportados

| Provider | Tipo | Implementación |
|----------|------|-----------------|
| claude | CLI | `claude --print` |
| gemini | CLI | `gemini -p` |
| codex | CLI | `codex exec` |
| opencode | CLI | `opencode run` |
| ollama | API REST | `http://localhost:11434/api/generate` |
| lmstudio | API REST | `http://localhost:1234/v1/chat/completions` |
| github | API REST | `models.inference.ai.azure.com` (con gh auth) |

## Notas de Implementación

### Providers CLI
- Validar que el comando existe antes de ejecutar
- Manejar errores de autenticación (ej: `gemini whoami`)
- Soportar modelos opcionales para opencode, lmstudio

### Providers API
- Ollama: mismo validation de `OLLAMA_HOST`
- LM Studio: mismo validation de `LMSTUDIO_HOST`
- GitHub: usar `gh auth token` para obtener Bearer token

### Cache
- Usar SHA256 hasher de stdlib `crypto/sha256`
- Misma estructura: `$HOME/.cache/ga/{project_hash}/`
- Metadata: archivo `metadata` con hash de rules+config

### Git Hooks
- Soportar tanto `pre-commit` como `commit-msg`
- Mismos markers para idempotencia: `# ======== GA START ========`
- Soporte para macOS (BSD sed) y Linux (GNU sed)

## Timeline Estimado

| Fase | Días |
|------|------|
| Foundation | 1 |
| Git Operations | 1-2 |
| Providers | 2-3 |
| Cache | 3 |
| Review Logic | 3-4 |
| CLI Commands | 4 |
| Tests | 5 |

**Total: ~5 días**
