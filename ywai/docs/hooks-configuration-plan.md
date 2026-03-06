# Plan: Sistema de Configuración de Hooks por Proyecto

## 🎯 Objetivo

Crear un sistema flexible que permita seleccionar qué hooks de OpenCode activar o desactivar por proyecto, reemplazando la configuración actual basada únicamente en tipo de proyecto.

## 📋 Problema Actual

- Los hooks se activan automáticamente por tipo de proyecto (`types.json`)
- No hay forma granular de activar/desactivar hooks específicos
- Los usuarios no pueden personalizar hooks sin modificar el sistema core

## 🏗️ Arquitectura Propuesta

### 1. Archivo de Configuración por Proyecto

**Archivo:** `.hooks-config.yml` (en raíz del proyecto)

```yaml
# Configuración de hooks para este proyecto
project_hooks:
  # Hooks explícitamente activados
  enabled:
    - name: "typescript-lint"
      command: "npm run lint"
      files: ["**/*.ts", "**/*.tsx"]
      trigger: "after"
      inject: "Lint Results:\n```\n{stdout}\n{stderr}\n```"
      
    - name: "python-format"
      command: "ruff format ."
      files: ["**/*.py"]
      trigger: "before"
      
    - name: "test-coverage"
      command: "npm test -- --coverage"
      files: ["**/*.test.*", "**/*.spec.*"]
      trigger: "after"
      when: "files include '**/*.test.*'"
  
  # Hooks explícitamente desactivados
  disabled:
    - "opencode-command-hooks"
    - "eslint-heavy"
    - "precommit-docker"
  
  # Configuración global
  settings:
    truncation_limit: 30000
    parallel_execution: true
    fail_fast: false

# Herencia de configuración base
inherit_from:
  - "typescript"     # Hereda hooks base de TypeScript
  - "nodejs"         # Hereda hooks base de Node.js
  - "!eslint-heavy"  # Excluye hooks específicos
```

### 2. Sistema de Detección y Configuración

**Componente:** `hooks-configurator`

**Responsabilidades:**
- Detectar archivo `.hooks-config.yml` en el proyecto
- Merge de configuraciones (base + proyecto + overrides)
- Generar archivos de configuración de OpenCode
- Validar sintaxis y dependencias

**Flujo:**
1. Buscar `.hooks-config.yml` en directorio actual y padres
2. Cargar configuración base del tipo de proyecto (si existe)
3. Aplicar herencia y overrides
4. Validar configuración final
5. Generar `opencode.json` y/o `.opencode/command-hooks.jsonc`

### 3. Integración con Setup Wizard

**Nuevos parámetros:**
```bash
# Interactivo
./setup/setup-wizard --configure-hooks

# Usar config específica
./setup/setup-wizard --hooks-config=.hooks-custom.yml

# Desactivar todos los hooks
./setup/setup-wizard --no-hooks

# Hooks predefinidos
./setup/setup-wizard --hooks-preset=minimal
./setup/setup-wizard --hooks-preset=strict
```

**Preguntas interactivas:**
```
¿Qué tipo de hooks quieres activar?
[ ] TypeScript linting y formatting
[ ] Python linting (ruff)
[ ] Tests unitarios
[ ] Build verification
[ ] Custom hooks desde .hooks-config.yml

¿Quieres desactivar algún hook específico?
[ ] opencode-command-hooks
[ ] biome formatting
[ ] git hooks
```

### 4. Comandos de Gestión

**Script:** `hooks-manager`

```bash
# Ver configuración actual
hooks-manager status

# Activar hook específico
hooks-manager enable typescript-lint

# Desactivar hook específico
hooks-manager disable opencode-command-hooks

# Crear template de configuración
hooks-manager init --template=typescript

# Validar configuración
hooks-manager validate

# Sincronizar con OpenCode
hooks-manager sync
```

### 5. Templates de Configuración

**Directorio:** `ywai/templates/hooks/`

**Templates disponibles:**
- `minimal.yml` - Solo hooks esenciales
- `typescript.yml` - Hooks para proyectos TypeScript
- `python.yml` - Hooks para proyectos Python
- `fullstack.yml` - Hooks para proyectos full-stack
- `custom.yml` - Template vacío para personalizar

### 6. Validación y Errores

**Validaciones:**
- Sintaxis YAML correcta
- Comandos ejecutables existentes
- Patrones de archivos válidos
- Sin duplicados en nombres de hooks
- Dependencias entre hooks resueltas

**Mensajes de error:**
```
❌ Error en .hooks-config.yml:
   • Hook 'typescript-lint': comando 'npm run lint' no encontrado
   • Patrón '**/*.ts' inválido: usar glob syntax
   • Hook duplicado: 'test-runner'
```

## 📁 Estructura de Archivos

```
ywai/
├── hooks-configurator/
│   ├── config/
│   │   ├── loader.go          # Carga y merge de configs
│   │   ├── validator.go       # Validación de sintaxis
│   │   └── generator.go       # Generación de opencode.json
│   ├── templates/
│   │   ├── minimal.yml
│   │   ├── typescript.yml
│   │   └── python.yml
│   └── cli/
│       └── hooks-manager.go   # CLI de gestión
├── setup/
│   └── wizard/
│       └── hooks.go           # Integración con setup wizard
└── templates/hooks/           # Templates para usuarios
    ├── minimal.yml
    ├── typescript.yml
    └── custom.yml
```

## 🔄 Flujo de Usuario

### Opción A: Proyecto Nuevo
```bash
# 1. Inicializar proyecto
./setup/setup-wizard --type=nest

# 2. Configurar hooks interactivamente
./setup/setup-wizard --configure-hooks

# 3. O crear config manualmente
hooks-manager init --template=typescript

# 4. Editar .hooks-config.yml
vim .hooks-config.yml

# 5. Aplicar configuración
hooks-manager sync
```

### Opción B: Proyecto Existente
```bash
# 1. Agregar configuración de hooks
hooks-manager init

# 2. Editar según necesidades
vim .hooks-config.yml

# 3. Validar y aplicar
hooks-manager validate && hooks-manager sync
```

### Opción C: Override Temporal
```bash
# Usar config específica sin modificar proyecto
./setup/setup-wizard --hooks-config=.hooks-dev.yml

# O desactivar todos temporalmente
export OPENCODE_CONFIG_CONTENT='{"plugin":[]}'
```

## 🎛es de Configuración

### Niveles de Precedencia
1. **Variables de entorno** (más alto)
2. **`.hooks-config.yml` local**
3. **Configuración por tipo de proyecto** (`types.json`)
4. **Configuración base** (más bajo)

### Herencia
- Los proyectos pueden heredar de múltiples configuraciones base
- Se pueden excluir hooks específicos con prefijo `!`
- Los overrides locales siempre prevalecen

### Condicionales
- Hooks pueden activarse solo si ciertos archivos existen
- Hooks pueden ejecutarse condicionalmente según tipo de archivo
- Soporte para expresiones complejas (file changes, git status, etc.)

## 🧪 Testing y Validación

### Tests Unitarios
- Validación de sintaxis YAML
- Merge de configuraciones
- Generación de opencode.json
- Detección de dependencias circulares

### Tests de Integración
- Setup wizard con hooks personalizados
- CLI commands en proyectos reales
- Compatibilidad con OpenCode

### Tests E2E
- Proyectos completos con diferentes configuraciones
- Verificación de que los hooks se ejecutan correctamente
- Validación de errores y mensajes

## 📈 Métricas y Monitoreo

### Métricas de Uso
- Qué hooks son más utilizados
- Configuraciones más comunes
- Errores frecuentes de configuración

### Monitoreo
- Tiempo de ejecución de hooks
- Fallos y timeouts
- Impacto en performance del workflow

## 🚀 Rollout Plan

### Fase 1: Core Infrastructure
- Implementar loader y validator
- Crear templates básicos
- CLI commands básicos

### Fase 2: Setup Integration
- Integrar con setup wizard
- Modo interactivo
- Compatibilidad con `types.json`

### Fase 3: Advanced Features
- Herencia y condicionales
- Templates complejos
- Validación avanzada

### Fase 4: Polish & Documentation
- Mejorar mensajes de error
- Documentación completa
- Ejemplos y best practices

## 🎯 Success Criteria

- ✅ Los usuarios pueden activar/desactivar hooks por proyecto
- ✅ Configuración intuitiva vía YAML
- ✅ Integración transparente con setup wizard
- ✅ Backward compatibility con `types.json`
- ✅ Validación robusta con errores claros
- ✅ Templates para casos comunes
- ✅ CLI para gestión diaria

## 🔄 Alternativas Consideradas

### JSON Configuration
- **Pros:** Nativo en OpenCode
- **Cons:** Más verboso, menos legible para humanos

### Solo Variables de Entorno
- **Pros:** Simple, no requiere archivos
- **Cons:** Difícil de mantener, no versionable

### UI/Interactive Setup
- **Pros:** Muy user-friendly
- **Cons:** Más complejo de implementar, menos flexible para power users

## 📝 Decisiones de Diseño

1. **YAML sobre JSON:** Más legible para configuración humana
2. **Archivo local sobre variables:** Permite versionamiento y compartir
3. **Herencia sobre copia:** Evita duplicación, facilita mantenimiento
4. **CLI sobre UI:** Más flexible para automatización y scripts
5. **Validación estricta:** Mejor experiencia de usuario con errores claros
