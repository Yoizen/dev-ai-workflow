package sync

import (
	"fmt"
	"path/filepath"
	"strings"
)

func (s *Sync) generateSyncReport(skills *SkillsReport, agents *AgentsMDChanges, review *ReviewMDChanges) string {
	var buf strings.Builder

	buf.WriteString(fmt.Sprintf("# YWAI Sync Report: %s\n\n", s.projectType))

	buf.WriteString("## 📊 Resumen\n")
	buf.WriteString(fmt.Sprintf("- Tipo detectado: `%s`\n", s.projectType))
	buf.WriteString(fmt.Sprintf("- Skills faltantes: %d\n", len(skills.Missing)))
	buf.WriteString(fmt.Sprintf("- Skills actualizables: %d\n", len(skills.Updated)))
	buf.WriteString(fmt.Sprintf("- Cambios en AGENTS.md: %d secciones\n", len(agents.NewSections)))
	buf.WriteString(fmt.Sprintf("- Cambios en REVIEW.md: %d reglas\n", len(review.NewRules)))
	buf.WriteString("\n")

	if len(skills.Missing) > 0 {
		buf.WriteString("## 📥 Skills Faltantes\n")
		buf.WriteString("| Skill | Descripción |\n")
		buf.WriteString("|-------|-------------|\n")
		for _, skill := range skills.Missing {
			buf.WriteString(fmt.Sprintf("| `%s` | %s |\n", skill.Name, skill.Description))
		}
		buf.WriteString("\n")
	}

	if len(skills.Updated) > 0 {
		buf.WriteString("## 🔄 Skills Actualizables\n")
		buf.WriteString("| Skill | Cambios |\n")
		buf.WriteString("|-------|--------|\n")
		for _, skill := range skills.Updated {
			buf.WriteString(fmt.Sprintf("| `%s` | %s |\n", skill.Name, skill.Description))
		}
		buf.WriteString("\n")
	}

	if len(agents.NewSections) > 0 || len(agents.UpdatedTables) > 0 {
		buf.WriteString("## 📝 AGENTS.md - Cambios\n")

		if len(agents.NewSections) > 0 {
			buf.WriteString("### Secciones nuevas:\n")
			for _, sec := range agents.NewSections {
				buf.WriteString(fmt.Sprintf("- \"%s\"", sec.Title))
				if sec.After != "" {
					buf.WriteString(fmt.Sprintf(" (después de \"%s\")", sec.After))
				}
				buf.WriteString("\n")
				if sec.Content != "" {
					buf.WriteString("  ```markdown\n")
					indented := indentMarkdown(sec.Content, "  ")
					buf.WriteString(indented)
					buf.WriteString("  ```\n")
				}
			}
			buf.WriteString("\n")
		}

		if len(agents.UpdatedTables) > 0 {
			buf.WriteString("### Tablas a actualizar:\n")
			for _, table := range agents.UpdatedTables {
				buf.WriteString(fmt.Sprintf("- \"%s\" → agregar %d filas\n", table.Name, len(table.AddRows)))
			}
			buf.WriteString("\n")
		}
	}

	if len(review.NewRules) > 0 {
		buf.WriteString("## 📋 REVIEW.md - Reglas Nuevas\n")
		for _, rule := range review.NewRules {
			buf.WriteString(fmt.Sprintf("- \"%s\"\n", rule.Description))
			if rule.Description != "" && rule.Description != rule.Title {
				buf.WriteString("  ```markdown\n")
				buf.WriteString(fmt.Sprintf("  - %s\n", rule.Description))
				buf.WriteString("  ```\n")
			}
		}
		buf.WriteString("\n")
	}

	buf.WriteString("## 🔧 Instrucciones\n\n")

	if len(skills.Missing) > 0 {
		buf.WriteString("### Opción A: Instalar skills faltantes\n")
		buf.WriteString("```bash\n")
		for _, skill := range skills.Missing {
			buf.WriteString(fmt.Sprintf("ywai --install-skill %s\n", skill.Name))
		}
		buf.WriteString("```\n\n")
	}

	buf.WriteString("### Opción B: Sync manual\n")
	instructions := s.generateInstructions(skills, agents, review)
	buf.WriteString(instructions)

	buf.WriteString("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")
	buf.WriteString("📌 **Prompt for LLM**:\n")
	buf.WriteString("   \"Review the sync report above. Install missing skills with \n")
	buf.WriteString("    `ywai --install-skill <name>` and update AGENTS.md/REVIEW.md \n")
	buf.WriteString("    as instructed.\"\n")
	buf.WriteString("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	return buf.String()
}

func (s *Sync) generateInstructions(skills *SkillsReport, agents *AgentsMDChanges, review *ReviewMDChanges) string {
	var buf strings.Builder
	step := 1

	if len(skills.Missing) > 0 {
		buf.WriteString(fmt.Sprintf("%d. **Crear directorios de skills**:\n", step))
		buf.WriteString("   ```bash\n")
		for _, skill := range skills.Missing {
			buf.WriteString(fmt.Sprintf("   mkdir -p skills/%s\n", skill.Name))
		}
		buf.WriteString("   ```\n\n")
		step++

		buf.WriteString(fmt.Sprintf("%d. **Copiar contenido de skills**:\n", step))
		for _, skill := range skills.Missing {
			buf.WriteString(fmt.Sprintf("   - Copy `%s/*` → `skills/%s/`\n", skill.Path, skill.Name))
		}
		buf.WriteString("\n")
		step++
	}

	if len(agents.NewSections) > 0 || len(agents.UpdatedTables) > 0 {
		buf.WriteString(fmt.Sprintf("%d. **Actualizar AGENTS.md**:\n", step))
		for _, sec := range agents.NewSections {
			buf.WriteString(fmt.Sprintf("   - Agregar sección \"%s\"", sec.Title))
			if sec.After != "" {
				buf.WriteString(fmt.Sprintf(" después de \"%s\"", sec.After))
			}
			buf.WriteString("\n")
			if sec.Content != "" {
				buf.WriteString("     ```markdown\n")
				buf.WriteString(indentMarkdown(sec.Content, "     "))
				buf.WriteString("     ```\n")
			}
		}
		for _, table := range agents.UpdatedTables {
			buf.WriteString(fmt.Sprintf("   - Actualizar tabla \"%s\" con nuevos skills\n", table.Name))
		}
		buf.WriteString("\n")
		step++
	}

	if len(review.NewRules) > 0 {
		buf.WriteString(fmt.Sprintf("%d. **Actualizar REVIEW.md**:\n", step))
		for _, rule := range review.NewRules {
			buf.WriteString(fmt.Sprintf("   - Agregar regla \"%s\"\n", rule.Title))
		}
		buf.WriteString("\n")
		step++
	}

	buf.WriteString(fmt.Sprintf("%d. **Ejecutar skills setup**:\n", step))
	buf.WriteString("   ```bash\n")
	buf.WriteString("   bash skills/setup.sh --all\n")
	buf.WriteString("   ```\n\n")
	step++

	buf.WriteString(fmt.Sprintf("%d. **Sincronizar metadata**:\n", step))
	buf.WriteString("   ```bash\n")
	buf.WriteString("   bash skills/skill-sync/assets/sync.sh\n")
	buf.WriteString("   ```\n")

	return buf.String()
}

func (s *Sync) generateInstallReport(skillName, srcPath string, deps []SkillInfo) string {
	var buf strings.Builder

	buf.WriteString("# YWAI: Install Skill\n\n")
	buf.WriteString(fmt.Sprintf("## Skill: `%s`\n\n", skillName))

	files := s.listSkillFiles(srcPath)

	buf.WriteString("### Archivos a copiar:\n")
	buf.WriteString("| Archivo | Destino |\n")
	buf.WriteString("|---------|----------|\n")
	for _, file := range files {
		buf.WriteString(fmt.Sprintf("| `%s` | `skills/%s/%s` |\n",
			file.Destination, skillName, file.Destination))
	}
	buf.WriteString("\n")

	if len(deps) > 0 {
		buf.WriteString(fmt.Sprintf("### Dependencias a instalar (%d):\n", len(deps)))
		buf.WriteString("| Skill | Motivo |\n")
		buf.WriteString("|-------|--------|\n")
		for _, dep := range deps {
			buf.WriteString(fmt.Sprintf("| `%s` | Requerido por %s |\n", dep.Name, skillName))
		}
		buf.WriteString("\n")
	}

	buf.WriteString("### Resumen:\n")
	totalSkills := 1 + len(deps)
	buf.WriteString(fmt.Sprintf("- Skills a instalar: %d\n", totalSkills))
	buf.WriteString(fmt.Sprintf("- Directorios a crear: %d\n", totalSkills))
	buf.WriteString(fmt.Sprintf("- Archivos a copiar: %d\n", len(files)))
	buf.WriteString("\n")

	buf.WriteString("### Instrucciones paso a paso:\n\n")

	buf.WriteString("1. **Crear directorios**:\n")
	buf.WriteString("   ```bash\n")
	buf.WriteString(fmt.Sprintf("   mkdir -p skills/%s\n", skillName))
	for _, dep := range deps {
		buf.WriteString(fmt.Sprintf("   mkdir -p skills/%s\n", dep.Name))
	}
	buf.WriteString("   ```\n\n")

	buf.WriteString("2. **Copiar archivos**:\n")
	for _, file := range files {
		buf.WriteString(fmt.Sprintf("   - `%s` → `skills/%s/%s`\n",
			file.Destination, skillName, file.Destination))
	}
	for _, dep := range deps {
		depFiles := s.listSkillFiles(dep.Path)
		for _, file := range depFiles {
			buf.WriteString(fmt.Sprintf("   - `%s` → `skills/%s/%s`\n",
				file.Destination, dep.Name, file.Destination))
		}
	}
	buf.WriteString("\n")

	buf.WriteString("3. **Actualizar AGENTS.md**:\n")
	buf.WriteString("   - Agregar a tabla \"Available Skills\":\n")
	buf.WriteString(fmt.Sprintf("     - `%s` - %s\n", skillName, s.getSkillInfo(skillName).Description))
	for _, dep := range deps {
		buf.WriteString(fmt.Sprintf("     - `%s` - %s\n", dep.Name, dep.Description))
	}
	buf.WriteString("\n")

	buf.WriteString("4. **Ejecutar skills setup**:\n")
	buf.WriteString("   ```bash\n")
	buf.WriteString("   bash skills/setup.sh --all\n")
	buf.WriteString("   ```\n\n")

	buf.WriteString("5. **Sincronizar metadata**:\n")
	buf.WriteString("   ```bash\n")
	buf.WriteString("   bash skills/skill-sync/assets/sync.sh\n")
	buf.WriteString("   ```\n\n")

	buf.WriteString("### Source paths:\n")
	buf.WriteString(fmt.Sprintf("- `%s/`: `%s`\n", skillName, srcPath))
	for _, dep := range deps {
		buf.WriteString(fmt.Sprintf("- `%s/`: `%s`\n", dep.Name, dep.Path))
	}

	buf.WriteString("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n")
	buf.WriteString("✅ Skills listas para instalar.\n\n")
	buf.WriteString("📌 **Next step for LLM**:\n")
	buf.WriteString("   \"Run `ywai --sync` after copying the files to update \n")
	buf.WriteString("    AGENTS.md and REVIEW.md with the newly installed skills\"\n")
	buf.WriteString("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")

	return buf.String()
}

func (s *Sync) getRelativePath(absPath string) string {
	if s.repoRoot != "" {
		rel, err := filepath.Rel(s.repoRoot, absPath)
		if err == nil {
			return rel
		}
	}
	return absPath
}

func indentMarkdown(content, prefix string) string {
	lines := strings.Split(content, "\n")
	var result []string
	for i, line := range lines {
		if i == 0 {
			result = append(result, line)
		} else if strings.TrimSpace(line) == "" {
			result = append(result, "")
		} else {
			result = append(result, prefix+line)
		}
	}
	return strings.Join(result, "\n")
}
