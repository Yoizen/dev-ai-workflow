package installer

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
)

func TestInferProjectType(t *testing.T) {
	tests := []struct {
		name     string
		files    map[string]string
		expected string
	}{
		{
			name: "nestjs project",
			files: map[string]string{
				"package.json": `{"dependencies": {"@nestjs/core": "^10.0.0"}}`,
			},
			expected: "nest",
		},
		{
			name: "nestjs + angular project",
			files: map[string]string{
				"package.json": `{"dependencies": {"@nestjs/core": "^10.0.0", "@angular/core": "^16.0.0"}}`,
			},
			expected: "nest-angular",
		},
		{
			name: "nestjs + react project",
			files: map[string]string{
				"package.json": `{"dependencies": {"@nestjs/core": "^10.0.0", "react": "^18.0.0"}}`,
			},
			expected: "nest-react",
		},
		{
			name: "python project",
			files: map[string]string{
				"pyproject.toml": `[tool.poetry]\nname = "test"`,
			},
			expected: "python",
		},
		{
			name: "dotnet project",
			files: map[string]string{
				"test.csproj": `<Project Sdk="Microsoft.NET.Sdk"></Project>`,
			},
			expected: "dotnet",
		},
		{
			name: "docker node project",
			files: map[string]string{
				"Dockerfile": `FROM node:18-alpine`,
			},
			expected: "nest",
		},
		{
			name: "docker python project",
			files: map[string]string{
				"Dockerfile": `FROM python:3.11-alpine`,
			},
			expected: "python",
		},
		{
			name: "docker dotnet project",
			files: map[string]string{
				"Dockerfile": `FROM mcr.microsoft.com/dotnet/sdk:7.0`,
			},
			expected: "dotnet",
		},
		{
			name: "generic project",
			files: map[string]string{
				"README.md": "# Generic Project",
			},
			expected: "generic",
		},
	}
	
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpdir, err := os.MkdirTemp("", "test-project-*")
			if err != nil {
				t.Fatal("Failed to create temp directory")
			}
			defer os.RemoveAll(tmpdir)
			
			// Create test files
			for filename, content := range tt.files {
				fullPath := filepath.Join(tmpdir, filename)
				if err := os.MkdirAll(filepath.Dir(fullPath), 0755); err != nil {
					t.Fatal("Failed to create directory")
				}
				if err := os.WriteFile(fullPath, []byte(content), 0644); err != nil {
					t.Fatal("Failed to write file")
				}
			}
			
			inst := &Installer{targetDir: tmpdir}
			result := inst.inferProjectType()
			
			if result != tt.expected {
				t.Errorf("Expected project type %s, got %s", tt.expected, result)
			}
		})
	}
}

func TestUpdateGitignore(t *testing.T) {
	tmpdir, err := os.MkdirTemp("", "test-gitignore-*")
	if err != nil {
		t.Fatal("Failed to create temp directory")
	}
	defer os.RemoveAll(tmpdir)
	
	inst := &Installer{
		targetDir: tmpdir,
		logger:    ui.NewLogger(true),
	}
	
	// Test creating new .gitignore
	err = inst.updateGitignore()
	if err != nil {
		t.Fatalf("Failed to update gitignore: %v", err)
	}
	
	gitignorePath := filepath.Join(tmpdir, ".gitignore")
	if !inst.fileExists(gitignorePath) {
		t.Error("Expected .gitignore to be created")
	}
	
	content, err := os.ReadFile(gitignorePath)
	if err != nil {
		t.Fatal("Failed to read .gitignore")
	}
	
	contentStr := string(content)
	expectedPatterns := []string{
		"node_modules/",
		".env",
		".ga",
		".opencode/",
		".DS_Store",
	}
	
	for _, pattern := range expectedPatterns {
		if !contains(contentStr, pattern) {
			t.Errorf("Expected pattern %s to be in .gitignore", pattern)
		}
	}
}

func TestSetupVSCodeSettings(t *testing.T) {
	tmpdir, err := os.MkdirTemp("", "test-vscode-*")
	if err != nil {
		t.Fatal("Failed to create temp directory")
	}
	defer os.RemoveAll(tmpdir)
	
	inst := &Installer{
		targetDir: tmpdir,
		logger:    ui.NewLogger(true),
	}
	
	err = inst.setupVSCodeSettings()
	if err != nil {
		t.Fatalf("Failed to setup VS Code settings: %v", err)
	}
	
	settingsPath := filepath.Join(tmpdir, ".vscode", "settings.json")
	if !inst.fileExists(settingsPath) {
		t.Error("Expected VS Code settings to be created")
	}
	
	content, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatal("Failed to read settings.json")
	}
	
	contentStr := string(content)
	if !contains(contentStr, "github.copilot.chat.useAgentsMdFile") {
		t.Error("Expected copilot setting to be in settings.json")
	}
}

func TestSetupVSCodeSettingsForce(t *testing.T) {
	tmpdir, err := os.MkdirTemp("", "test-vscode-force-*")
	if err != nil {
		t.Fatal("Failed to create temp directory")
	}
	defer os.RemoveAll(tmpdir)
	
	inst := &Installer{
		targetDir: tmpdir,
		logger:    ui.NewLogger(true),
		flags:     &Flags{Force: true},
	}
	
	vscodeDir := filepath.Join(tmpdir, ".vscode")
	if err := os.MkdirAll(vscodeDir, 0755); err != nil {
		t.Fatal("Failed to create .vscode directory")
	}
	
	settingsPath := filepath.Join(vscodeDir, "settings.json")
	existingContent := `{"existing": "setting"}`
	if err := os.WriteFile(settingsPath, []byte(existingContent), 0644); err != nil {
		t.Fatal("Failed to write existing settings")
	}
	
	err = inst.setupVSCodeSettings()
	if err != nil {
		t.Fatalf("Failed to setup VS Code settings: %v", err)
	}
	
	content, err := os.ReadFile(settingsPath)
	if err != nil {
		t.Fatal("Failed to read settings.json")
	}
	
	contentStr := string(content)
	if contains(contentStr, "existing") {
		t.Error("Expected existing content to be overwritten")
	}
	
	if !contains(contentStr, "github.copilot.chat.useAgentsMdFile") {
		t.Error("Expected copilot setting to be in settings.json")
	}
}

func contains(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > len(substr) && 
		(s[:len(substr)] == substr || s[len(s)-len(substr):] == substr || 
		 findSubstring(s, substr)))
}

func findSubstring(s, substr string) bool {
	for i := 0; i <= len(s)-len(substr); i++ {
		if s[i:i+len(substr)] == substr {
			return true
		}
	}
	return false
}
