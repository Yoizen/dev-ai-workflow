# Workflow de desarrollo asistido por IA

Features:
- **Agent / Plan mode** para tareas chicas y medianas
- **SDD Orchestrator (SDD, Spec Driven Development)** para features grandes (spec + diseño + tasks + apply)
- **GA Review (GA, Guardian Agent)** para review automático en cada commit

---

## Pre-requisitos

### Común
- Un repo Git inicializado (o un proyecto donde vayas a instalarlo).
- `git` instalado y disponible en PATH.
- Acceso a GitHub (para descargar scripts desde `raw.githubusercontent.com`).

### macOS / Linux
- `bash`
- `curl`

### Windows
- PowerShell (recomendado PowerShell 5.1+ o PowerShell 7+).
- Permisos para ejecutar el comando de instalación (si tu política lo restringe, ajustá Execution Policy según tus prácticas internas).

---

## Instalación

### Quick Install (recomendado)

```bash
# macOS / Linux (NestJS default)
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --all --type=nest
```

```powershell
# Windows (PowerShell - NestJS default)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -All -Type nest
```

### Instalacion seleccionando el tipo de proyecto

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=nest
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=python
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=dotnet
```

```powershell
# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type nest
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type python
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type dotnet
```

### Opcionales

**OpenCode Hooks**
```bash
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --hooks
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Hooks
```

**Baseline opcional de Biome**
```bash
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --biome
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Biome
```

**OpenCode Hooks + Biome**
```bash
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --hooks --biome
```

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Hooks -Biome
```

Ver **instalación avanzada** en `auto/README.md`.

---

## Primer uso (SDD) en un repo

Seleccioná **Agent mode** y usá SDD Orchestrator:

```text
/sdd-init                  # Inicializa SDD en el repo (una sola vez)
sdd:new dark-mode          # Crea propuesta del change
sdd:ff dark-mode           # Fast-forward: genera spec + diseño + tareas
/sdd-apply                 # Implementa tareas pendientes
git commit                 # GA hace review automático
```

---

## Elegir el modo correcto

No siempre necesitás SDD. Usá el modo según complejidad:

### Tarea simple → Agent directo
Fixes rápidos, refactors chicos o tareas claras:

```text
[Agent mode]
> Agrega validación de email en el form de registro
```

### Tarea compleja → Plan → Agent
Cuando conviene pensar primero:

```text
[Plan mode]
> Necesito agregar autenticación con OAuth.
> Soportar Google y GitHub. Guardar sesión en cookies httpOnly.
> El usuario tiene que poder deslogearse desde cualquier página.
```

Luego:

```text
[Agent mode]
> Implementa el plan
```

### Feature grande → SDD Orchestrator
Cuando cruza múltiples archivos/sistemas o es multi-día:

```text
sdd:new sistema-de-pagos
sdd:ff sistema-de-pagos
/sdd-apply
```

SDD genera specs formales, diseño técnico, tareas, y trackea el progreso.

### Resumen

| Complejidad | Modo | Ejemplo |
|-------------|------|---------|
| Fix / tweak | Agent | "Arregla el typo en el header" |
| Feature clara | Agent | "Agrega botón de logout" |
| Feature que hay que pensar | Plan → Agent | "Sistema de notificaciones" |
| Feature grande / multi-día | SDD Orchestrator | "Migrar auth a OAuth2" |

---

## Qué modelo usar

| Tarea | Modelo recomendado | Por qué |
|------|-------------------|---------|
| Planning / diseño | **Opus 4.6** | Mejor razonamiento; piensa antes de actuar |
| Implementación (Agent) | **Codex 5.3** / **Sonnet 4.6** | Optimizado para código; rápido y preciso |
| Commits, PRs, docs | **Gemini 3 Flash** | Barato; suficiente para texto |
| Ajustes de UI/CSS | **Gemini 3.1 Pro** | Buen balance costo/calidad para visual |
| Code review básica | **Gemini 3 Flash** / **Haiku 4.5** | Económico para checks rutinarios |
| Code review crítica | **Codex 5.3** | Detecta bugs sutiles; entiende contexto |

Regla general:
- Modelo caro → pensar, planificar, revisar código crítico
- Modelo barato → ejecutar, commits, reviews rutinarias

---

## Comandos SDD Orchestrator (SDD)

### Atajos (recomendado)

| Comando | Qué hace |
|---------|----------|
| `sdd:new <nombre>` | Crea propuesta para un nuevo change (equivale a `/sdd-propose`) |
| `sdd:ff <nombre>` | Fast-forward: propuesta + spec + diseño + tasks |

### Slash commands individuales

| Comando | Qué hace |
|---------|----------|
| `/sdd-init` | Inicializa el flujo SDD en el proyecto |
| `/sdd-explore` | Explora una idea antes de crear el change |
| `/sdd-propose` | Crea propuesta del change |
| `/sdd-spec` | Genera specs y requerimientos |
| `/sdd-design` | Genera diseño técnico y decisiones de arquitectura |
| `/sdd-tasks` | Breakdown en tareas de implementación |
| `/sdd-apply` | Implementa tareas del change activo |
| `/sdd-verify` | Verifica implementación contra la spec |
| `/sdd-archive` | Archiva un change terminado |

---

## Ejemplo completo

```text
> /sdd-init
Copilot: SDD inicializado para este repositorio.

> sdd:new login-con-google
Copilot: Creando propuesta 'login-con-google'...
         → .sdd/changes/login-con-google/proposal.md

> sdd:ff login-con-google
Copilot: Fast-forward: generando spec, diseño y tareas...
         → .sdd/changes/login-con-google/specs/auth/spec.md
         → .sdd/changes/login-con-google/design.md
         → .sdd/changes/login-con-google/tasks.md

> /sdd-apply
Copilot: Implementando tarea 1.1: Agregar botón de login...
         [edita archivos]
         Implementando tarea 2.1: Configurar OAuth...
         [edita archivos]
         Implementando tarea 2.2: Manejar callback...
         [edita archivos]
         Todas las tareas completadas.

> git commit -m "feat: login con google"
GA Review: PASS
[main abc1234] feat: login con google
```

---

## Tipos de Proyecto (`--type`)

Al instalar podés especificar el tipo para obtener `AGENTS.md` y `REVIEW.md` adaptados, más skills correspondientes:

```bash
bash auto/bootstrap.sh --install-sdd --type=nest      # NestJS / TypeScript (default)
bash auto/bootstrap.sh --install-sdd --type=python    # Python / FastAPI / Django
bash auto/bootstrap.sh --install-sdd --type=dotnet    # .NET / C# / ASP.NET Core
bash auto/bootstrap.sh --install-sdd --type=generic   # Genérico
```

```powershell
# Windows
.\auto\bootstrap.ps1 -InstallSDD -Type nest
.\auto\bootstrap.ps1 -InstallSDD -Type python
.\auto\bootstrap.ps1 -InstallSDD -Type dotnet
```

Para ver todos los tipos disponibles:

```bash
bash auto/bootstrap.sh --list-types
```

| Tipo | Descripción | Skills incluidas |
|------|-------------|-----------------|
| `nest` | NestJS backend (TypeScript, Clean Architecture) (default) | git-commit, biome, skill-creator, skill-sync |
| `python` | Python backend / scripts (FastAPI, Django) | git-commit, skill-creator, skill-sync |
| `dotnet` | .NET / C# (ASP.NET Core, Clean Architecture) | git-commit, skill-creator, skill-sync |
| `generic` | Genérico — language-agnostic | git-commit, skill-creator, skill-sync |

Cada tipo instala un `AGENTS.md` con reglas específicas del stack y un `REVIEW.md` con checklist de code review adaptado. Si no especificás `--type`, se usa `generic`.

---

## Sincronizar Skills con AGENTS.md

Si agregaste o modificaste skills, podés pedirle al agente que regenere la sección de Auto-invoke en tus `AGENTS.md`.

Prompt sugerido (Agent mode):

```text
Sincronizá las skills con los AGENTS.md del repo.
Usá la skill `skill-sync` y regenerá las tablas de Auto-invoke según el metadata actual de `skills/*/SKILL.md`.
```

---

## Review Automático (GA)

Cada commit pasa por review automático. Si querés skippearlo:

```bash
git commit --no-verify -m "wip: trabajo en progreso"
```

### Configurar las reglas de review

Editá `REVIEW.md` en la raíz de tu proyecto:

```markdown
# Reglas de Code Review

## TypeScript
- No usar `any`
- Usar `const` en vez de `let`

## React
- Solo componentes funcionales
- Todas las imágenes con alt

## Testing
- Toda feature nueva necesita tests
```

---

## Estructura del Proyecto

Después de instalar:

```text
mi-proyecto/
├── .ga                     # Config de GA
├── REVIEW.md               # Reglas de review
├── skills/                 # Skills de IA + SDD skills
│   ├── git-commit/
│   ├── biome/
│   ├── sdd-init/
│   ├── sdd-explore/
│   ├── sdd-propose/
│   ├── sdd-spec/
│   ├── sdd-design/
│   ├── sdd-tasks/
│   ├── sdd-apply/
│   ├── sdd-verify/
│   └── sdd-archive/
└── .vscode/
    └── settings.json
```

---

## Providers de IA

GA puede usar diferentes providers. Editá `.ga`:

```bash
PROVIDER="opencode"   # Default - OpenCode
PROVIDER="claude"     # Anthropic Claude
PROVIDER="gemini"     # Google Gemini
PROVIDER="ollama"     # Modelos locales
```

---

## Troubleshooting

**"Provider not found"**
```bash
which opencode  # Verificá que esté en PATH
```

**"Review falla siempre"**
- Simplificá tu `REVIEW.md`
- Probá con `PROVIDER="claude"`

---

## Links

- Instalación avanzada: `auto/README.md`
- Issues: https://github.com/Yoizen/dev-ai-workflow/issues
