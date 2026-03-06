package tests

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestSkillsInstallation(t *testing.T) {
	t.Log("▶ Testing skills installation")

	skillsDir := filepath.Join(getRepoRoot(), "ywai", "skills")

	// Check skills directory exists
	if _, err := os.Stat(skillsDir); os.IsNotExist(err) {
		t.Skip("Skills directory not found")
	}

	// Read skills directory
	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		t.Fatalf("Failed to read skills directory: %v", err)
	}

	skillCount := 0
	for _, entry := range entries {
		if entry.IsDir() {
			skillPath := filepath.Join(skillsDir, entry.Name())

			// Check for SKILL.md
			skillFile := filepath.Join(skillPath, "SKILL.md")
			if _, err := os.Stat(skillFile); err == nil {
				t.Logf("  ✅ Found skill: %s", entry.Name())
				skillCount++

				// Validate skill.md structure
				validateSkillFile(t, skillFile, entry.Name())
			}
		}
	}

	if skillCount == 0 {
		t.Error("No skills found")
		return
	}

	t.Logf("  ✅ Validated %d skills", skillCount)
}

func validateSkillFile(t *testing.T, skillFile, skillName string) {
	content, err := os.ReadFile(skillFile)
	if err != nil {
		t.Errorf("Failed to read skill file %s: %v", skillName, err)
		return
	}

	contentStr := string(content)

	// Check for required frontmatter sections
	requiredSections := []string{
		"---",
		"description:",
		"---",
	}

	for _, section := range requiredSections {
		if !strings.Contains(contentStr, section) {
			t.Errorf("Skill %s missing required section: %s", skillName, section)
		}
	}
}

func TestSkillsSyntax(t *testing.T) {
	t.Log("▶ Testing skills syntax validation")

	skillsDir := filepath.Join(getRepoRoot(), "ywai", "skills")

	// Walk through all skill files
	err := filepath.Walk(skillsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Only validate root skill definitions
		if !strings.HasSuffix(path, "SKILL.md") {
			return nil
		}

		// Read and validate markdown syntax
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read %s: %v", path, err)
			return nil
		}

		contentStr := string(content)

		// Basic markdown validation
		if !strings.Contains(contentStr, "#") {
			t.Errorf("File %s appears to lack proper markdown headers", path)
		}

		// Check frontmatter
		if !strings.HasPrefix(contentStr, "---") {
			t.Errorf("File %s appears to lack frontmatter", path)
		}

		return nil
	})

	if err != nil {
		t.Fatalf("Error walking skills directory: %v", err)
	}

	t.Log("  ✅ Skills syntax validation completed")
}

func TestGlobalSkillsStructure(t *testing.T) {
	t.Log("▶ Testing global skills structure")

	globalSkillsDir := filepath.Join(getRepoRoot(), "ywai", "extensions", "install-steps", "global-agents")

	// Check if global skills directory exists
	if _, err := os.Stat(globalSkillsDir); os.IsNotExist(err) {
		t.Skip("Global skills directory not found")
	}

	// Check for required files
	requiredFiles := []string{
		"install.sh",
		"templates/",
	}

	for _, file := range requiredFiles {
		filePath := filepath.Join(globalSkillsDir, file)
		if _, err := os.Stat(filePath); os.IsNotExist(err) {
			t.Errorf("Missing global skills component: %s", file)
		} else {
			t.Logf("  ✅ Found global skills component: %s", file)
		}
	}

	// Validate templates directory
	templatesDir := filepath.Join(globalSkillsDir, "templates")
	if entries, err := os.ReadDir(templatesDir); err == nil {
		templateCount := 0
		for _, entry := range entries {
			if !entry.IsDir() && strings.HasSuffix(entry.Name(), ".md") {
				templateCount++
			}
		}
		t.Logf("  ✅ Found %d global skill templates", templateCount)
	}
}

func TestSkillDependencies(t *testing.T) {
	t.Log("▶ Testing skill dependencies")

	// Test that skills reference valid parameters and structure
	skillsDir := filepath.Join(getRepoRoot(), "ywai", "skills")

	err := filepath.Walk(skillsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil || !strings.HasSuffix(path, "SKILL.md") {
			return nil
		}

		content, err := os.ReadFile(path)
		if err != nil {
			return err
		}

		contentStr := string(content)

		// Check for common parameter patterns
		if strings.Contains(contentStr, "parameters:") {
			// Extract parameters section (basic validation)
			lines := strings.Split(contentStr, "\n")
			inParams := false
			for _, line := range lines {
				line = strings.TrimSpace(line)
				if line == "parameters:" {
					inParams = true
					continue
				}
				if inParams && line == "---" {
					break
				}
				if inParams && strings.HasPrefix(line, "-") {
					// Found a parameter definition
					t.Logf("    Parameter found in %s", filepath.Base(filepath.Dir(path)))
				}
			}
		}

		return nil
	})

	if err != nil {
		t.Errorf("Error validating skill dependencies: %v", err)
	}

	t.Log("  ✅ Skill dependencies validation completed")
}
