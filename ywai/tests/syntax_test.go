package tests

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"gopkg.in/yaml.v3"
)

func TestYAMLSyntax(t *testing.T) {
	t.Log("▶ Testing YAML syntax validation")

	yamlDir := filepath.Join(getRepoRoot(), "ywai")

	// Walk through all YAML files
	err := filepath.Walk(yamlDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Only check .yml and .yaml files
		if !strings.HasSuffix(path, ".yml") && !strings.HasSuffix(path, ".yaml") {
			return nil
		}

		// Skip node_modules and other vendor directories
		if strings.Contains(path, "node_modules") || strings.Contains(path, ".git") {
			return nil
		}

		// Read and validate YAML syntax
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read %s: %v", path, err)
			return nil
		}

		var data interface{}
		if err := yaml.Unmarshal(content, &data); err != nil {
			t.Errorf("Invalid YAML syntax in %s: %v", path, err)
			return nil
		}

		t.Logf("  ✅ Valid YAML: %s", strings.TrimPrefix(path, getRepoRoot()+"/"))
		return nil
	})

	if err != nil {
		t.Fatalf("Error walking directory for YAML files: %v", err)
	}

	t.Log("  ✅ YAML syntax validation completed")
}

func TestJSONSyntax(t *testing.T) {
	t.Log("▶ Testing JSON syntax validation")

	repoRoot := getRepoRoot()

	// Walk through all JSON files
	err := filepath.Walk(repoRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Only check .json files
		if !strings.HasSuffix(path, ".json") {
			return nil
		}

		// Skip node_modules and other vendor directories
		if strings.Contains(path, "node_modules") || strings.Contains(path, ".git") {
			return nil
		}

		// Read and validate JSON syntax
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read %s: %v", path, err)
			return nil
		}

		var data interface{}
		if err := json.Unmarshal(content, &data); err != nil {
			t.Errorf("Invalid JSON syntax in %s: %v", path, err)
			return nil
		}

		t.Logf("  ✅ Valid JSON: %s", strings.TrimPrefix(path, repoRoot+"/"))
		return nil
	})

	if err != nil {
		t.Fatalf("Error walking directory for JSON files: %v", err)
	}

	t.Log("  ✅ JSON syntax validation completed")
}

func TestConfigFiles(t *testing.T) {
	t.Log("▶ Testing configuration files")

	configFiles := map[string]string{
		"opencode.json": filepath.Join(getRepoRoot(), "ywai", "config", "opencode.json"),
		"types.json":    filepath.Join(getRepoRoot(), "ywai", "types", "types.json"),
	}

	for configFile, configPath := range configFiles {
		content, err := os.ReadFile(configPath)
		if err != nil {
			t.Errorf("Failed to read config file %s: %v", configFile, err)
			continue
		}

		var data interface{}
		if err := json.Unmarshal(content, &data); err != nil {
			t.Errorf("Invalid JSON in config file %s: %v", configFile, err)
			continue
		}

		t.Logf("  ✅ Valid config file: %s", configFile)
	}

	// Validate types.json structure
	typesPath := filepath.Join(getRepoRoot(), "ywai", "types", "types.json")
	if content, err := os.ReadFile(typesPath); err == nil {
		var types struct {
			Types map[string]interface{} `json:"types"`
		}
		if err := json.Unmarshal(content, &types); err == nil {
			requiredTypes := []string{"generic", "nest", "nest-angular", "nest-react", "python", "dotnet", "devops"}
			for _, reqType := range requiredTypes {
				if _, exists := types.Types[reqType]; exists {
					t.Logf("    Found project type: %s", reqType)
				} else {
					t.Errorf("Missing required project type: %s", reqType)
				}
			}
		}
	}
}

func TestTemplatesSyntax(t *testing.T) {
	t.Log("▶ Testing template files syntax")

	templatesDir := filepath.Join(getRepoRoot(), "ywai", "templates")

	// Check templates directory exists
	if _, err := os.Stat(templatesDir); os.IsNotExist(err) {
		t.Skip("Templates directory not found")
	}

	// Walk through template files
	err := filepath.Walk(templatesDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Skip directories
		if info.IsDir() {
			return nil
		}

		// Read file
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read template file %s: %v", path, err)
			return nil
		}

		contentStr := string(content)

		// Basic template validation
		if strings.HasSuffix(path, ".md") && !strings.Contains(contentStr, "#") {
			t.Errorf("Template file %s appears to lack proper markdown headers", path)
		}

		// Check for template variables (optional)
		if strings.Contains(contentStr, "{{") && strings.Contains(contentStr, "}}") {
			t.Logf("    Found template variables in: %s", strings.TrimPrefix(path, getRepoRoot()+"/"))
		}

		t.Logf("  ✅ Valid template: %s", strings.TrimPrefix(path, getRepoRoot()+"/"))
		return nil
	})

	if err != nil {
		t.Fatalf("Error walking templates directory: %v", err)
	}

	t.Log("  ✅ Template syntax validation completed")
}

func TestExtensionConfigs(t *testing.T) {
	t.Log("▶ Testing extension configurations")

	extensionsDir := filepath.Join(getRepoRoot(), "ywai", "extensions")

	// Check extensions directory exists
	if _, err := os.Stat(extensionsDir); os.IsNotExist(err) {
		t.Skip("Extensions directory not found")
	}

	// Test extension configuration files
	err := filepath.Walk(extensionsDir, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		// Only check config files
		if !strings.HasSuffix(path, ".json") && !strings.HasSuffix(path, ".yml") && !strings.HasSuffix(path, ".yaml") {
			return nil
		}

		// Skip node_modules
		if strings.Contains(path, "node_modules") {
			return nil
		}

		// Validate syntax based on file extension
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read extension config %s: %v", path, err)
			return nil
		}

		if strings.HasSuffix(path, ".json") {
			var data interface{}
			if err := json.Unmarshal(content, &data); err != nil {
				t.Errorf("Invalid JSON in extension config %s: %v", path, err)
				return nil
			}
		} else {
			var data interface{}
			if err := yaml.Unmarshal(content, &data); err != nil {
				t.Errorf("Invalid YAML in extension config %s: %v", path, err)
				return nil
			}
		}

		t.Logf("  ✅ Valid extension config: %s", strings.TrimPrefix(path, getRepoRoot()+"/"))
		return nil
	})

	if err != nil {
		t.Fatalf("Error walking extensions directory: %v", err)
	}

	t.Log("  ✅ Extension configuration validation completed")
}

func TestPackageJSONFiles(t *testing.T) {
	t.Log("▶ Testing package.json files")

	repoRoot := getRepoRoot()

	// Find all package.json files
	err := filepath.Walk(repoRoot, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		if info.Name() != "package.json" {
			return nil
		}

		// Skip node_modules
		if strings.Contains(path, "node_modules") {
			return nil
		}

		// Validate package.json
		content, err := os.ReadFile(path)
		if err != nil {
			t.Errorf("Failed to read package.json %s: %v", path, err)
			return nil
		}

		var packageJSON struct {
			Name         string            `json:"name"`
			Version      string            `json:"version"`
			Scripts      map[string]string `json:"scripts"`
			Dependencies map[string]string `json:"dependencies"`
		}

		if err := json.Unmarshal(content, &packageJSON); err != nil {
			t.Errorf("Invalid package.json syntax in %s: %v", path, err)
			return nil
		}

		// Basic validation
		if packageJSON.Name == "" {
			t.Errorf("package.json %s missing name field", path)
		}

		if packageJSON.Version == "" {
			t.Errorf("package.json %s missing version field", path)
		}

		t.Logf("  ✅ Valid package.json: %s (%s@%s)",
			strings.TrimPrefix(path, repoRoot+"/"),
			packageJSON.Name,
			packageJSON.Version)

		return nil
	})

	if err != nil {
		t.Fatalf("Error walking directory for package.json files: %v", err)
	}

	t.Log("  ✅ package.json validation completed")
}
