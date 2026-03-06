package templates

import (
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestNewInstaller(t *testing.T) {
	templatesDir := t.TempDir()
	targetDir := t.TempDir()
	
	installer := NewInstaller(templatesDir, targetDir)
	
	if installer.templatesDir != templatesDir {
		t.Errorf("Expected templatesDir to be '%s', got '%s'", templatesDir, installer.templatesDir)
	}
	
	if installer.targetDir != targetDir {
		t.Errorf("Expected targetDir to be '%s', got '%s'", targetDir, installer.targetDir)
	}
}

func TestInstallTemplates(t *testing.T) {
	// Create temporary directories
	templatesDir := t.TempDir()
	targetDir := t.TempDir()
	
	// Create template files
	engramContent := "# Engram Protocol\nTest content"
	sddContent := "# SDD Orchestrator\nTest content"
	
	if err := os.WriteFile(filepath.Join(templatesDir, "engram-protocol.md"), []byte(engramContent), 0644); err != nil {
		t.Fatal(err)
	}
	
	if err := os.WriteFile(filepath.Join(templatesDir, "sdd-orchestrator.md"), []byte(sddContent), 0644); err != nil {
		t.Fatal(err)
	}
	
	// Install templates
	installer := NewInstaller(templatesDir, targetDir)
	if err := installer.InstallTemplates(); err != nil {
		t.Fatal(err)
	}
	
	// Check that docs directory was created
	docsDir := filepath.Join(targetDir, "docs")
	if _, err := os.Stat(docsDir); os.IsNotExist(err) {
		t.Error("Expected docs directory to be created")
	}
	
	// Check that template files were copied
	engramPath := filepath.Join(docsDir, "engram-protocol.md")
	if _, err := os.Stat(engramPath); os.IsNotExist(err) {
		t.Error("Expected engram-protocol.md to be copied")
	}
	
	sddPath := filepath.Join(docsDir, "sdd-orchestrator.md")
	if _, err := os.Stat(sddPath); os.IsNotExist(err) {
		t.Error("Expected sdd-orchestrator.md to be copied")
	}
	
	// Check content
	content, err := os.ReadFile(engramPath)
	if err != nil {
		t.Fatal(err)
	}
	
	if string(content) != engramContent {
		t.Error("Expected engram content to match")
	}
	
	content, err = os.ReadFile(sddPath)
	if err != nil {
		t.Fatal(err)
	}
	
	if string(content) != sddContent {
		t.Error("Expected SDD content to match")
	}
}

func TestInstallTemplatesMissingDir(t *testing.T) {
	templatesDir := filepath.Join(t.TempDir(), "nonexistent")
	targetDir := t.TempDir()
	
	installer := NewInstaller(templatesDir, targetDir)
	err := installer.InstallTemplates()
	
	if err == nil {
		t.Error("Expected error for missing templates directory")
	}
	
	expectedError := "templates directory not found:"
	if !strings.Contains(err.Error(), expectedError) {
		t.Errorf("Expected error to contain '%s', got '%s'", expectedError, err.Error())
	}
}

func TestInstallTemplate(t *testing.T) {
	templatesDir := t.TempDir()
	targetDir := t.TempDir()
	
	// Create template file
	templateContent := "# Test Template\nThis is a test"
	templateFile := filepath.Join(templatesDir, "test.md")
	
	if err := os.WriteFile(templateFile, []byte(templateContent), 0644); err != nil {
		t.Fatal(err)
	}
	
	// Install template
	installer := NewInstaller(templatesDir, targetDir)
	targetFile := filepath.Join(targetDir, "installed.md")
	
	if err := installer.installTemplate("test.md", targetFile); err != nil {
		t.Fatal(err)
	}
	
	// Check that file was created
	if _, err := os.Stat(targetFile); os.IsNotExist(err) {
		t.Error("Expected template file to be installed")
	}
	
	// Check content
	content, err := os.ReadFile(targetFile)
	if err != nil {
		t.Fatal(err)
	}
	
	if string(content) != templateContent {
		t.Error("Expected template content to match")
	}
}

func TestInstallTemplateMissingFile(t *testing.T) {
	templatesDir := t.TempDir()
	targetDir := t.TempDir()
	
	installer := NewInstaller(templatesDir, targetDir)
	targetFile := filepath.Join(targetDir, "installed.md")
	
	err := installer.installTemplate("nonexistent.md", targetFile)
	if err == nil {
		t.Error("Expected error for missing template file")
	}
	
	expectedError := "template file not found:"
	if !strings.Contains(err.Error(), expectedError) {
		t.Errorf("Expected error to contain '%s', got '%s'", expectedError, err.Error())
	}
}

func TestProcessTemplate(t *testing.T) {
	installer := NewInstaller("", "")
	
	content := "# Test Template\nThis is a test"
	processed := installer.processTemplate(content)
	
	if processed != content {
		t.Error("Expected processTemplate to return content as-is")
	}
}

func TestDirExists(t *testing.T) {
	installer := NewInstaller("", "")
	
	// Test existing directory
	tempDir := t.TempDir()
	if !installer.dirExists(tempDir) {
		t.Error("Expected dirExists to return true for existing directory")
	}
	
	// Test non-existent directory
	if installer.dirExists(filepath.Join(tempDir, "nonexistent")) {
		t.Error("Expected dirExists to return false for non-existent directory")
	}
	
	// Test file instead of directory
	file := filepath.Join(tempDir, "test.txt")
	if err := os.WriteFile(file, []byte("test"), 0644); err != nil {
		t.Fatal(err)
	}
	
	if installer.dirExists(file) {
		t.Error("Expected dirExists to return false for file")
	}
}

func TestFileExists(t *testing.T) {
	installer := NewInstaller("", "")
	
	// Test existing file
	tempDir := t.TempDir()
	file := filepath.Join(tempDir, "test.txt")
	if err := os.WriteFile(file, []byte("test"), 0644); err != nil {
		t.Fatal(err)
	}
	
	if !installer.fileExists(file) {
		t.Error("Expected fileExists to return true for existing file")
	}
	
	// Test non-existent file
	if installer.fileExists(filepath.Join(tempDir, "nonexistent.txt")) {
		t.Error("Expected fileExists to return false for non-existent file")
	}
	
	// Test directory instead of file
	if installer.fileExists(tempDir) {
		t.Error("Expected fileExists to return false for directory")
	}
}

func TestEnsureDir(t *testing.T) {
	installer := NewInstaller("", "")
	
	// Test creating new directory
	tempDir := t.TempDir()
	newDir := filepath.Join(tempDir, "new", "nested", "dir")
	
	if err := installer.ensureDir(newDir); err != nil {
		t.Fatal(err)
	}
	
	if _, err := os.Stat(newDir); os.IsNotExist(err) {
		t.Error("Expected ensureDir to create directory")
	}
	
	// Test existing directory (should not error)
	if err := installer.ensureDir(tempDir); err != nil {
		t.Errorf("Expected ensureDir to not error for existing directory: %v", err)
	}
}
