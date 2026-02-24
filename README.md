## Workflow
Selecciona **Agent mode** y usa SDD Orchestrator (SDD):
~~~
/sdd:init                  # Inicializa SDD en el repo (una sola vez)
/sdd:new dark-mode         # Crea feature/change
/sdd:ff dark-mode          # Genera plan completo
/sdd:apply                 # Implementa tareas pendientes
git commit                 # GA hace review automatico
~~~
Para retomar trabajo de un change ya creado:
~~~
/sdd:continue dark-mode
~~~
---
## Cuando usar cada modo
No siempre necesitas SDD Orchestrator. Usa el modo correcto segun la complejidad:
### Tarea simple -> Agent directo
Para fixes rapidos, refactors pequenos, o tareas claras:
~~~
[Agent mode]
> Agrega validacion de email en el form de registro
~~~
Copilot lo implementa directo.
### Tarea compleja -> Plan + Agent
Para features que necesitan pensar primero:
~~~
[Plan mode]
> Necesito agregar autenticación con OAuth.
> Soportar Google y GitHub. Guardar sesión en cookies httpOnly.
> El usuario tiene que poder deslogearse desde cualquier página.
~~~
Copilot escribe el plan. Vos lo revisas. Después:
~~~
[Agent mode]
> Implementa el plan
~~~
### Feature grande -> SDD Orchestrator (SDD)
Para features que cruzan multiples archivos/sistemas:
~~~
/sdd:new sistema-de-pagos
/sdd:ff sistema-de-pagos
/sdd:apply
~~~
SDD Orchestrator genera specs formales, tareas, y trackea el progreso con sub-agents especializados.
### Resumen
| Complejidad | Modo | Ejemplo |
|-------------|------|---------|
| Fix/tweak | Agent | "Arregla el typo en el header" |
| Feature clara | Agent | "Agrega boton de logout" |
| Feature que hay que pensar | Plan -> Agent | "Sistema de notificaciones" |
| Feature grande/multi-dia | SDD Orchestrator | "Migrar auth a OAuth2" |
### Que modelo usar
| Tarea | Modelo recomendado | Por que |
|-------|-------------------|---------|
| Planning / diseño | **Opus 4.6** | Mejor razonamiento, piensa antes de actuar |
| Implementación (Agent) | **Codex 5.3** / **Sonnet 4.6**(lento pero misma performance que codex) | Optimizado para codigo, rapido y preciso |
| Commits, PRs, docs | **Gemini 3 Flash** | Barato, rapido, suficiente para texto |
| Ajustes de UI/CSS | **Gemini 3.1 Pro** | Buen balance costo/calidad para visual |
| Code review básica | **Gemini 3 Flash** / **Haiku 4.5** | Economico para checks rutinarios |
| Code review crítica | **Codex 5.3** | Detecta bugs sutiles, entiende contexto |
**Regla general:**
- Modelo caro -> pensar, planificar, revisar codigo critico
- Modelo barato -> ejecutar, commits, reviews rutinarias
---
## Comandos SDD Orchestrator (SDD)
| Comando | Que hace |
|---------|----------|
| /sdd:init | Inicializa el flujo SDD en el proyecto |
| /sdd:explore idea | Explora una idea antes de crear el change |
| /sdd:new nombre | Crea un nuevo change/feature |
| /sdd:continue nombre | Retoma un change existente |
| /sdd:ff nombre | Fast-forward: genera propuesta, spec y tareas |
| /sdd:apply | Implementa tareas del change activo |
| /sdd:verify | Verifica implementación contra la spec |
| /sdd:archive | Archiva un change terminado |
---
## Ejemplo Completo
~~~
> /sdd:init
Copilot: SDD inicializado para este repositorio.
> /sdd:new login-con-google
Copilot: Creando change 'login-con-google'...
         Inicializando sub-agents SDD...
> /sdd:ff login-con-google
Copilot: Fast-forward completado. Artefactos generados:
         - proposal.md
         - tasks.md
         - spec.md
> /sdd:apply
Copilot: Implementando tarea 1/3: Agregar boton de login...
         [edita archivos]
         Implementando tarea 2/3: Configurar OAuth...
         [edita archivos]
         Implementando tarea 3/3: Manejar callback...
         [edita archivos]
         Todas las tareas completadas.
> git commit -m "feat: login con google"
GA Review: PASS
[main abc1234] feat: login con google
~~~
---

## Instalación

### Quick Install

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1 | iex
```

### Con tipo de proyecto

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=nest
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=python
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --type=dotnet

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type nest
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type python
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Type dotnet
```

### Con OpenCode Hooks

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --hooks

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Hooks
```

### Con baseline opcional de Biome

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --biome

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Biome
```

### Con OpenCode Hooks + Biome

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.sh | bash -s -- --hooks --biome

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/auto/quick-setup.ps1))) -Hooks -Biome
```

Ver [instalación avanzada](auto/README.md) para más opciones.

---

## Tipos de Proyecto (`--type`)

Al instalar podés especificar el tipo de proyecto para obtener un `AGENTS.md` y `REVIEW.md` adaptados, más las skills correspondientes:

```bash
bash auto/bootstrap.sh --install-sdd --type=nest      # NestJS / TypeScript
bash auto/bootstrap.sh --install-sdd --type=python    # Python / FastAPI / Django
bash auto/bootstrap.sh --install-sdd --type=dotnet    # .NET / C# / ASP.NET Core
bash auto/bootstrap.sh --install-sdd --type=generic   # Genérico (default)
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
| `nest` | NestJS backend (TypeScript, Clean Architecture) | git-commit, biome, skill-creator, skill-sync |
| `python` | Python backend / scripts (FastAPI, Django) | git-commit, skill-creator, skill-sync |
| `dotnet` | .NET / C# (ASP.NET Core, Clean Architecture) | git-commit, skill-creator, skill-sync |
| `generic` | Genérico — language-agnostic (default) | git-commit, skill-creator, skill-sync |

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

```
mi-proyecto/
├── .ga                    # Config de GA
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

**"Quiero desactivar GA temporalmente"**
```bash
git commit --no-verify -m "mensaje"
```

---

## Links

- [Instalación avanzada](auto/README.md)
- [Issues](https://github.com/Yoizen/dev-ai-workflow/issues)

---





