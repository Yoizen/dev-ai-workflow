package templates

import (
	"fmt"
	"os"
	"path/filepath"
)

// Installer handles template installation
type Installer struct {
	templatesDir string
	targetDir    string
}

// NewInstaller creates a new template installer
func NewInstaller(templatesDir, targetDir string) *Installer {
	return &Installer{
		templatesDir: templatesDir,
		targetDir:    targetDir,
	}
}

// InstallTemplates installs all templates to the target directory
func (ti *Installer) InstallTemplates() error {
	if !ti.dirExists(ti.templatesDir) {
		return fmt.Errorf("templates directory not found: %s", ti.templatesDir)
	}

	// Create docs directory in target
	docsDir := filepath.Join(ti.targetDir, "docs")
	if err := ti.ensureDir(docsDir); err != nil {
		return fmt.Errorf("failed to create docs directory: %w", err)
	}

	// Install specific templates
	templates := map[string]string{
		"engram-protocol.md":  "engram-protocol.md",
		"sdd-orchestrator.md": "sdd-orchestrator.md",
	}

	for templateFile, targetFile := range templates {
		if err := ti.installTemplate(templateFile, filepath.Join(docsDir, targetFile)); err != nil {
			return fmt.Errorf("failed to install template %s: %w", templateFile, err)
		}
	}

	return nil
}

// installTemplate installs a single template file
func (ti *Installer) installTemplate(templateFile, targetPath string) error {
	sourcePath := filepath.Join(ti.templatesDir, templateFile)
	
	if !ti.fileExists(sourcePath) {
		return fmt.Errorf("template file not found: %s", sourcePath)
	}

	// Read template content
	content, err := os.ReadFile(sourcePath)
	if err != nil {
		return fmt.Errorf("failed to read template: %w", err)
	}

	// Process template content (if needed)
	processedContent := ti.processTemplate(string(content))

	// Write to target
	if err := os.WriteFile(targetPath, []byte(processedContent), 0644); err != nil {
		return fmt.Errorf("failed to write template: %w", err)
	}

	return nil
}

// processTemplate processes template content (placeholder for future expansion)
func (ti *Installer) processTemplate(content string) string {
	// For now, return content as-is
	// In the future, we could add variable substitution here
	return content
}

// dirExists checks if a directory exists
func (ti *Installer) dirExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

// fileExists checks if a file exists
func (ti *Installer) fileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

// ensureDir creates a directory if it doesn't exist
func (ti *Installer) ensureDir(path string) error {
	return os.MkdirAll(path, 0755)
}
