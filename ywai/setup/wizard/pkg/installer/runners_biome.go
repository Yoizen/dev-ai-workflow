package installer

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func (i *Installer) installBiome() error {
	if !i.commandExists("node") {
		i.logger.LogInfo("Node.js not available, skipping Biome")
		return nil
	}

	biomeConfig := filepath.Join(i.targetDir, "biome.json")
	packageJson := filepath.Join(i.targetDir, "package.json")

	if i.fileExists(biomeConfig) && !i.flags.Force {
		i.logger.LogInfo("biome.json already exists, skipping")
		return nil
	}

	if i.flags.DryRun {
		i.logger.Log("DRY RUN: Would create biome.json baseline")
		return nil
	}

	templatePath := i.firstExistingFile(
		i.ywaiCandidates(false, "extensions/install-steps/biome-baseline/biome.json")...,
	)
	if templatePath == "" {
		return fmt.Errorf("biome.json template not found")
	}

	data, err := os.ReadFile(templatePath)
	if err != nil {
		return fmt.Errorf("failed to read biome template: %w", err)
	}

	if err := os.WriteFile(biomeConfig, data, 0644); err != nil {
		return err
	}

	i.logger.LogSuccess("Created biome.json baseline")

	if i.fileExists(packageJson) {
		if err := i.addBiomeToPackageJson(packageJson); err != nil {
			i.logger.LogWarning(fmt.Sprintf("Failed to update package.json: %v", err))
		}
	}

	return nil
}

func (i *Installer) addBiomeToPackageJson(packageJsonPath string) error {
	content, err := os.ReadFile(packageJsonPath)
	if err != nil {
		return err
	}

	var pkg map[string]interface{}
	if err := json.Unmarshal(content, &pkg); err != nil {
		return err
	}

	modified := false

	scripts, ok := pkg["scripts"].(map[string]interface{})
	if !ok {
		scripts = make(map[string]interface{})
		pkg["scripts"] = scripts
		modified = true
	}

	scriptsToAdd := map[string]string{
		"lint":         "biome check .",
		"lint:fix":     "biome check --write .",
		"format":       "biome format --write .",
		"format:check": "biome format .",
	}

	for key, value := range scriptsToAdd {
		if _, exists := scripts[key]; !exists {
			scripts[key] = value
			modified = true
		}
	}

	deps, ok := pkg["devDependencies"].(map[string]interface{})
	if !ok {
		deps = make(map[string]interface{})
		pkg["devDependencies"] = deps
		modified = true
	}

	if _, exists := deps["@biomejs/biome"]; !exists {
		deps["@biomejs/biome"] = "^1.0.0"
		modified = true
	}

	if modified {
		output, err := json.MarshalIndent(pkg, "", "  ")
		if err != nil {
			return err
		}
		output = append(output, '\n')

		if err := os.WriteFile(packageJsonPath, output, 0644); err != nil {
			return err
		}

		i.logger.LogSuccess("Added Biome scripts and dependency to package.json")

		if err := i.runCommand("npm", "install"); err != nil {
			i.logger.LogWarning("Failed to install @biomejs/biome")
		} else {
			i.logger.LogSuccess("Installed @biomejs/biome")
		}
	} else {
		i.logger.LogInfo("Biome already configured in package.json")
	}

	return nil
}
