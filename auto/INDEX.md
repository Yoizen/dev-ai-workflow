# 📁 Auto Scripts - Índice

## 📖 Qué hay aquí

Scripts para automatizar el setup de GGA y SpecKit/OpenSpec en cualquier repo.

## 🗂 Archivos

### 🚀 Setup Principal

| Archivo | Uso |
|---------|-----|
| **[bootstrap.ps1](bootstrap.ps1)** | Setup completo (Windows) |
| **[bootstrap.sh](bootstrap.sh)** | Setup completo (Linux/macOS) |
| **[quick-setup.ps1](quick-setup.ps1)** | Instalación rápida desde URL (Windows) |
| **[quick-setup.sh](quick-setup.sh)** | Instalación rápida desde URL (Unix) |

### 📋 Configuración

| Archivo | Propósito |
|---------|-----------|
| **[AGENTS.MD](AGENTS.MD)** | Directivas para AI agents |
| **[REVIEW.md](REVIEW.md)** | Checklist de code review |
| **[CONSTITUTION.md](CONSTITUTION.md)** | Reglas arquitectónicas |

### ✅ Validación

| Archivo | Uso |
|---------|-----|
| **[validate.ps1](validate.ps1)** | Verificar setup (Windows) |
| **[validate.sh](validate.sh)** | Verificar setup (Unix) |
| **[update-all.ps1](update-all.ps1)** | Actualizar múltiples repos (Windows) |
| **[update-all.sh](update-all.sh)** | Actualizar múltiples repos (Unix) |

### 📚 Docs

| Archivo | Para |
|---------|------|
| **[README.md](README.md)** | Guía principal |
| **[WORKFLOW.md](WORKFLOW.md)** | Workflows y ejemplos |

## 🎯 Uso Rápido

### Setup inicial

```bash
# Windows
.\bootstrap.ps1

# Linux/macOS
./bootstrap.sh
```

Instala GGA, SpecKit/OpenSpec, VS Code extensions, y configura el repo.

### Otro repo

```bash
.\bootstrap.ps1 /ruta/otro-proyecto  # Windows
./bootstrap.sh /ruta/otro-proyecto   # Unix
```

### Validar

```bash
.\validate.ps1   # Windows
./validate.sh    # Unix
```

### Múltiples repos

```bash
# Unix
./update-all.sh ~/repo1 ~/repo2 ~/repo3

# Windows
.\update-all.ps1 -Repositories 'C:\repo1','C:\repo2'
```

## 🔧 Opciones Comunes

### bootstrap.ps1 / bootstrap.sh

```powershell
# Opciones principales
-SkipCopilotApi / --skip-copilot-api    # No instalar Copilot API
-SkipSpecKit / --skip-speckit           # No instalar SpecKit
-SkipGGA / --skip-gga                   # No instalar GGA
-SkipVSCode / --skip-vscode             # No instalar extensiones
-Force / --force                         # Sobrescribir configs existentes
```

### validate.ps1 / validate.sh

```powershell
# Validar específico
.\validate.ps1 C:\ruta\al\proyecto
./validate.sh /ruta/al/proyecto
```

### update-all.ps1 / update-all.sh


**bootstrap:**
- `-SkipSpecKit` / `--skip-speckit` - No instalar SpecKit
- `-SkipGGA` / `--skip-gga` - No instalar GGA
- `-SkipVSCode` / `--skip-vscode` - No instalar extensiones
- `-Force` / `--force` - Sobrescribir configs

**update-all:**
- `--dry-run` - Preview sin ejecutar
- `--force` - Forzar actualización🎓 Orden de Lectura Recomendado

Para nuevos usuarios:

1. **[README.md](README.md)** - Empezar aquí
2. **Ejecutar bootstrap** - Instalación práctica
3. **[AGENTS.MD](AGENTS.MD)** - Entender las directivas del AI
4. **[REVIEW.md](REVIEW.md)** - Conocer el checklist
5. **[WORKFLOW.md](WORKFLOW.md)** - Workflows completos

Para team leads:

1. **[README.md](README.md)** - Overview
2. **[WORKFLOW.md](WORKFLOW.md)** - Todos los escenarios
3. **[bootstrap.config.example.ps1](bootstrap.config.example.ps1)** - Personalización
4. **Personalizar AGENTS.MD, REVIEW.md, CONSTITUTION.md**
5. **Crear script de update-all para el equipo**

## 🔄 Mantenimiento

### Actualizar scripts en todos los proyectos
� Orden de Lectura

1. [README.md](README.md) - Empezar aquí
2. Ejecutar bootstrap
3. [AGENTS.MD](AGENTS.MD) - Directivas del AI
4. [REVIEW.md](REVIEW.md) - Checklist
5. [WORKFLOW.md](WORKFLOW.md) - Ejemplos completos
1. Crear script en este directorio
2. Actualizar este INDEX.md
3. Agregar sección en README.md
4. Agregar ejemplo en WORKFLOW.md
5. Probar en proyecto limpio
6. Commit y PR

## 🔗 Links Útiles

- [README Principal del GGA](../README.md)
- [SpecKit en GitHub](https://github.com/github/spec-kit)
- [Copilot API](https://github.com/Yoizen/copilot-api)

## 📞 Soporte

- **Issues**: [GitHub Issues](https://github.com/tu-org/gga-copilot/issues)
- **Docs**: Este directorio
- **Ejemplos**: Ver [WORKFLOW.md](WORKFLOW.md)

---

**Última actualización**: 2026-01-03  
**Versión**: 1.0.0
**PowerShell no ejecuta:**
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

**Permission denied:**
```bash
chmod +x *.sh
```

**Más ayuda:** Ver [README.md](README.md)