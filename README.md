# Guardian Agent


---

## Workflow Copilot

Seleccioná **Agent mode** y usá OpenSpec:

```
/opsx:new dark-mode      # Crear feature
/opsx:ff                 # Generar plan
/opsx:apply              # Implementar
git commit               # GGA hace review automático
```

---

## Cuándo usar cada modo

No siempre necesitás OpenSpec. Usá el modo correcto según la complejidad:

### Tarea simple → Agent directo

Para fixes rápidos, refactors pequeños, o tareas claras:

```
[Agent mode]
> Agregá validación de email en el form de registro
```

Copilot lo implementa directo.

### Tarea compleja → Plan + Agent

Para features que necesitan pensar primero:

```
[Plan mode]
> Necesito agregar autenticación con OAuth.
> Soportar Google y GitHub. Guardar sesión en cookies httpOnly.
> El usuario tiene que poder deslogearse desde cualquier página.
```

Copilot escribe el plan. Vos lo revisás. Después:

```
[Agent mode]
> Implementá el plan
```

### Feature grande → OpenSpec completo

Para features que cruzan múltiples archivos/sistemas:

```
/opsx:new sistema-de-pagos
/opsx:ff
/opsx:apply
```

OpenSpec genera specs formales, tareas, y trackea el progreso.

### Resumen

| Complejidad | Modo | Ejemplo |
|-------------|------|---------|
| Fix/tweak | Agent | "Arreglá el typo en el header" |
| Feature clara | Agent | "Agregá botón de logout" |
| Feature que hay que pensar | Plan → Agent | "Sistema de notificaciones" |
| Feature grande/multi-día | OpenSpec | "Migrar auth a OAuth2" |

### Qué modelo usar

| Tarea | Modelo recomendado | Por qué |
|-------|-------------------|---------|
| Planning / diseño | **Opus 4.6** | Mejor razonamiento, piensa antes de actuar |
| Implementación (Agent) | **Codex 5.3** | Optimizado para código, rápido y preciso |
| Commits, PRs, docs | **Gemini 3 Flash** | Barato, rápido, suficiente para texto |
| Ajustes de UI/CSS | **Gemini 3 Pro** | Buen balance costo/calidad para visual |
| Code review básica | **Gemini 3 Flash** / **Haiku 4.5** | Económico para checks rutinarios |
| Code review crítica | **Codex 5.3** | Detecta bugs sutiles, entiende contexto |

**Regla general:**
- Modelo caro → pensar, planificar, revisar código crítico
- Modelo barato → ejecutar, commits, reviews rutinarias

---

## Comandos OpenSpec

| Comando | Qué hace |
|---------|----------|
| `/opsx:new nombre` | Crea una nueva feature/change |
| `/opsx:ff nombre` | Fast-forward: genera toda la planificación |
| `/opsx:apply nombre` | Implementa las tareas |
| `/opsx:continue` | Crea el siguiente artefacto |
| `/opsx:explore` | Pensá ideas antes de commitear a una dirección |
| `/opsx:sync` | Sincroniza specs antes de archivar |
| `/opsx:archive` | Archiva una feature terminada |

---

## Ejemplo Completo

```
> /opsx:new login-con-google

Copilot: Creando change 'login-con-google'...
         Generado openspec/changes/login-con-google/

> /opsx:ff

Copilot: Fast-forward completado. Artefactos generados:
         - proposal.md
         - tasks.md
         - spec.md

> /opsx:apply

Copilot: Implementando tarea 1/3: Agregar botón de login...
         [edita archivos]
         Implementando tarea 2/3: Configurar OAuth...
         [edita archivos]
         Implementando tarea 3/3: Manejar callback...
         [edita archivos]
         Todas las tareas completadas.

> git commit -m "feat: login con google"

GGA Review: PASS
[main abc1234] feat: login con google
```

---

## Instalación

### Quick Install

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.sh | bash

# Windows (PowerShell)
irm https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.ps1 | iex
```

### Con OpenCode Hooks

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.sh | bash -s -- --hooks

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.ps1))) -Hooks
```

### Con baseline opcional de Biome

```bash
# macOS / Linux
curl -sSL https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.sh | bash -s -- --biome

# Windows (PowerShell)
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/Yoizen/gga-copilot/main/auto/quick-setup.ps1))) -Biome
```

Ver [instalación avanzada](auto/README.md) para más opciones.

---

## Review Automático (GGA)

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
├── .gga                    # Config de GGA
├── REVIEW.md               # Reglas de review
├── openspec/               # OpenSpec
│   ├── project.md          # Reglas del proyecto
│   └── changes/            # Features en progreso
├── skills/                 # Skills de IA
│   ├── git-commit/
│   └── biome/
└── .vscode/
    └── settings.json
```

---

## Providers de IA

GGA puede usar diferentes providers. Editá `.gga`:

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

**"Quiero desactivar GGA temporalmente"**
```bash
git commit --no-verify -m "mensaje"
```

---

## Links

- [Instalación avanzada](auto/README.md)
- [OpenSpec docs](https://github.com/Fission-AI/OpenSpec)
- [Issues](https://github.com/Yoizen/gga-copilot/issues)

---

MIT © 2026
