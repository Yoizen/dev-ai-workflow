package config

import (
	"os"
	"testing"
)

func TestLoadDefaults(t *testing.T) {
	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.FilePatterns != "*" {
		t.Errorf("Expected FilePatterns '*', got %s", cfg.FilePatterns)
	}
	if cfg.RulesFile != "REVIEW.md" {
		t.Errorf("Expected RulesFile 'REVIEW.md', got %s", cfg.RulesFile)
	}
	if cfg.StrictMode != true {
		t.Errorf("Expected StrictMode true, got %v", cfg.StrictMode)
	}
	if cfg.Timeout != 300 {
		t.Errorf("Expected Timeout 300, got %d", cfg.Timeout)
	}
}

func TestLoadWithConfigFile(t *testing.T) {
	content := `PROVIDER="claude"
FILE_PATTERNS="*.go,*.ts"
EXCLUDE_PATTERNS="*_test.go"
RULES_FILE="CODING_STANDARDS.md"
STRICT_MODE="false"
TIMEOUT="600"
`
	tmpfile, err := os.CreateTemp("", ".ga")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmpfile.Name())

	if _, err := tmpfile.Write([]byte(content)); err != nil {
		t.Fatal(err)
	}
	tmpfile.Close()

	// Change to temp directory
	origDir, _ := os.Getwd()
	os.Chdir(os.TempDir())
	defer os.Chdir(origDir)

	// Rename to .ga
	os.Rename(tmpfile.Name(), ".ga")
	defer os.Remove(".ga")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Provider != "claude" {
		t.Errorf("Expected Provider 'claude', got %s", cfg.Provider)
	}
	if cfg.FilePatterns != "*.go,*.ts" {
		t.Errorf("Expected FilePatterns '*.go,*.ts', got %s", cfg.FilePatterns)
	}
	if cfg.ExcludePatterns != "*_test.go" {
		t.Errorf("Expected ExcludePatterns '*_test.go', got %s", cfg.ExcludePatterns)
	}
	if cfg.RulesFile != "CODING_STANDARDS.md" {
		t.Errorf("Expected RulesFile 'CODING_STANDARDS.md', got %s", cfg.RulesFile)
	}
	if cfg.StrictMode != false {
		t.Errorf("Expected StrictMode false, got %v", cfg.StrictMode)
	}
	if cfg.Timeout != 600 {
		t.Errorf("Expected Timeout 600, got %d", cfg.Timeout)
	}
}

func TestLoadWithComments(t *testing.T) {
	content := `# This is a comment
PROVIDER="opencode"
# Another comment
`
	tmpfile, err := os.CreateTemp("", ".ga")
	if err != nil {
		t.Fatal(err)
	}
	defer os.Remove(tmpfile.Name())

	if _, err := tmpfile.Write([]byte(content)); err != nil {
		t.Fatal(err)
	}
	tmpfile.Close()

	// Change to temp directory
	origDir, _ := os.Getwd()
	os.Chdir(os.TempDir())
	defer os.Chdir(origDir)

	os.Rename(tmpfile.Name(), ".ga")
	defer os.Remove(".ga")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}

	if cfg.Provider != "opencode" {
		t.Errorf("Expected Provider 'opencode', got %s", cfg.Provider)
	}
}
