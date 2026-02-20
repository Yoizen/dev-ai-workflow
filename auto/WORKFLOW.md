# Workflow: GGA Setup y Uso

## 🎯 Qué hace

Configura automáticamente repositorios con:
- **GGA** - Code review automatizado con AI
- **SpecKit/OpenSpec** - Metodología Spec-First
- **Estándares** - AGENTS.MD, REVIEW.md, CONSTITUTION.md
- **VS Code** - Extensiones y configuración

## 🚀 Quick Start

### Proyecto nuevo

```bash
# 1. Setup
mkdir mi-proyecto && cd mi-proyecto
git init
./bootstrap.sh

# 2. Configurar
code .gga         # Elegir provider (opencode, claude, etc)
code REVIEW.md    # Personalizar reglas

# 3. Trabajar
git add . && git commit -m "feat: ..."
# GGA revisa automáticamente antes del commit
```

### Proyecto existente

```bash
cd mi-proyecto-existente
./bootstrap.sh --force  # Sobrescribe configs
```

### Múltiples proyectos

```bash
for repo in ~/proyectos/*; do
  cd "$repo" && ./bootstrap.sh --force
done
```

## 📝 Workflow Diario

```bash
# 1. Crear spec (opcional)
mkdir -p specs/features/auth
code specs/features/auth/spec.md

# 2. Implementar
# ...tu código...

# 3. Commit (review automático)
git add .
git commit -m "feat: authentication"

# 4. Si falla, ver detalles
gga run

# 5. Push
git push
```

## 🏢 CI/CD

### GitHub Actions

```yaml
name: GGA Review
on: [pull_request]
jobs:
  review:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: |
          curl -sSL https://raw.githubusercontent.com/.../bootstrap.sh | bash
          echo "PROVIDER=opencode" >> .gga
      - run: gga run --no-cache
```

### GitLab CI

```yaml
gga-review:
  stage: test
  script:
    - bash <(curl -sSL https://.../bootstrap.sh)
    - echo "PROVIDER=opencode" >> .gga
    - gga run --no-cache
```

## 🔐 Seguridad

**NO hacer:**
```bash
echo "API_KEY=sk-123..." > .gga
```

**Hacer:**
```bash
# 1. Variables de entorno
export GGA_PROVIDER=opencode
gga run

# 2. Gitignore
echo ".gga" >> .gitignore
```

## 🎓 Para Equipos

### Personalizar para tu organización

```bash
# 1. Fork este repo
git clone https://github.com/tu-org/gga-copilot.git

# 2. Editar estándares
code auto/AGENTS.MD      # Guías de tu stack
code auto/REVIEW.md      # Checklist de tu equipo
code auto/CONSTITUTION.md # Arquitectura

# 3. Distribuir
# Los devs clonan tu fork y ejecutan bootstrap
```

### Onboarding

```bash
# Día 1: Setup (30 min)
./bootstrap.sh
code .gga REVIEW.md

# Día 2: Uso (1 hora)  
# - Crear spec simple
# - Implementar con GGA
# - Personalizar REVIEW.md

# Día 3: CI/CD (30 min)
# - Integrar en GitHub/GitLab
```

## 📞 Ayuda

- **Docs**: [README.md](../README.md)
- **Issues**: GitHub Issues
- **Commands**: `gga help`
