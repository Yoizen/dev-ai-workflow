package installer

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
)

func (i *Installer) runAll() error {
	if err := i.installGA(); err != nil {
		return err
	}

	if err := i.installSDD(); err != nil {
		return err
	}

	if err := i.installVSCodeExtensions(); err != nil {
		return err
	}

	if err := i.installOpenCode(); err != nil {
		return err
	}

	if err := i.configureProject(); err != nil {
		return err
	}

	if err := i.installExtensions(); err != nil {
		return err
	}

	return nil
}

func (i *Installer) runSelected() error {
	// ALWAYS install GA and extensions - these are base components
	if !i.flags.SkipGA {
		if err := i.installGA(); err != nil {
			return err
		}
	}

	if i.flags.InstallSDD && !i.flags.SkipSDD {
		if err := i.installSDD(); err != nil {
			return err
		}
	}

	if i.flags.InstallVSCode && !i.flags.SkipVSCode {
		if err := i.installVSCodeExtensions(); err != nil {
			return err
		}
	}

	if err := i.installOpenCode(); err != nil {
		return err
	}

	if err := i.configureProject(); err != nil {
		return err
	}

	// ALWAYS install extensions (Context7, Engram, etc.)
	if err := i.installExtensions(); err != nil {
		return err
	}

	return nil
}

func (i *Installer) updateAll() error {
	i.logger.LogStep("Updating YWAI installation...")

	if err := i.updateGA(); err != nil {
		return err
	}

	if i.flags.InstallSDD || i.flags.All {
		if err := i.installSDD(); err != nil {
			return err
		}
	}

	if i.flags.InstallVSCode && !i.flags.SkipVSCode {
		if err := i.installVSCodeExtensions(); err != nil {
			return err
		}
	}

	if err := i.installOpenCode(); err != nil {
		return err
	}

	if err := i.configureProject(); err != nil {
		return err
	}

	if err := i.installExtensions(); err != nil {
		return err
	}

	i.logger.LogSuccess("YWAI update complete")
	return nil
}

func (i *Installer) checkForUpdates() error {
	currentVersion, err := i.versionResolver.GetInstalledVersion()
	if err != nil {
		return fmt.Errorf("failed to get installed version: %w", err)
	}

	if currentVersion == "" {
		i.logger.LogInfo("GA is not installed")
		return nil
	}

	hasUpdate, latestVersion, err := i.versionResolver.CheckForUpdates(currentVersion, i.channel)
	if err != nil {
		return fmt.Errorf("failed to check for updates: %w", err)
	}

	if hasUpdate {
		i.logger.LogSuccess(fmt.Sprintf("Update available: %s → %s", currentVersion, latestVersion))
	} else {
		i.logger.LogInfo(fmt.Sprintf("GA is up to date: %s", currentVersion))
	}

	return nil
}

func (i *Installer) listTypes() error {
	types := i.loadTypesConfig()

	fmt.Println("Available project types:")
	fmt.Println("")

	for name, config := range types.Types {
		marker := " "
		if name == types.Default {
			marker = "*"
		}
		fmt.Printf("%s %s - %s\n", marker, name, config.Description)
	}

	fmt.Println("")
	fmt.Printf("Default: %s\n", types.Default)
	fmt.Println("")
	fmt.Println("Use with --type=<name>")

	return nil
}

func (i *Installer) listExtensions() error {
	types := i.loadTypesConfig()

	pt := i.projectType
	if pt == "" {
		pt = types.Default
	}

	typeConfig, ok := types.Types[pt]
	if !ok {
		return fmt.Errorf("project type '%s' not found", pt)
	}

	fmt.Printf("Extensions for project type '%s':\n", pt)
	fmt.Println("")

	if len(typeConfig.Extensions) == 0 {
		fmt.Println("No extensions configured for this type")
		return nil
	}

	for extType, extNames := range typeConfig.Extensions {
		fmt.Printf("%s:\n", extType)
		for _, extName := range extNames {
			fmt.Printf("  - %s\n", extName)
		}
		fmt.Println("")
	}

	return nil
}

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

	biomeContent := `{
  "$schema": "https://biomejs.dev/schemas/2.3.2/schema.json",
  "files": {
    "ignoreUnknown": true,
    "includes": [
      "**",
      "!!**/node_modules", "!!**/dist", "!!**/build",
      "!!**/coverage", "!!**/.next", "!!**/.nuxt",
      "!!**/.svelte-kit", "!!**/.turbo", "!!**/.vercel",
      "!!**/.cache", "!!**/__generated__",
      "!!**/*.generated.*", "!!**/*.gen.*",
      "!!**/generated", "!!**/codegen"
    ]
  },
  "formatter": {
    "enabled": true,
    "formatWithErrors": true,
    "indentStyle": "space",
    "indentWidth": 2,
    "lineEnding": "lf",
    "lineWidth": 80,
    "bracketSpacing": true
  },
  "assist": {
    "actions": {
      "source": {
        "organizeImports": "on",
        "useSortedAttributes": "on",
        "noDuplicateClasses": "on",
        "useSortedInterfaceMembers": "on",
        "useSortedProperties": "on"
      }
    }
  },
  "linter": {
    "enabled": true,
    "rules": {
      "correctness": {
        "noUnusedImports": { "fix": "safe", "level": "error" },
        "noUnusedVariables": "error",
        "noUnusedFunctionParameters": "error",
        "noUndeclaredVariables": "error",
        "useParseIntRadix": "warn",
        "useValidTypeof": "error",
        "noUnreachable": "error"
      },
      "style": {
        "useBlockStatements": { "fix": "safe", "level": "error" },
        "useConst": "error",
        "useImportType": "warn",
        "noNonNullAssertion": "error",
        "useTemplate": "warn"
      },
      "security": { "noGlobalEval": "error" },
      "suspicious": {
        "noExplicitAny": "error",
        "noImplicitAnyLet": "error",
        "noDoubleEquals": "warn",
        "noGlobalIsNan": "error",
        "noPrototypeBuiltins": "error"
      },
      "complexity": {
        "useOptionalChain": "error",
        "useLiteralKeys": "warn",
        "noForEach": "warn"
      },
      "nursery": {
        "useSortedClasses": {
          "fix": "safe",
          "level": "error",
          "options": {
            "attributes": ["className"],
            "functions": ["clsx","cva","tw","twMerge","cn","twJoin","tv"]
          }
        }
      }
    }
  },
  "javascript": {
    "formatter": {
      "arrowParentheses": "always",
      "semicolons": "always",
      "trailingCommas": "es5"
    }
  },
  "organizeImports": { "enabled": true },
  "vcs": {
    "enabled": true,
    "clientKind": "git",
    "useIgnoreFile": true,
    "defaultBranch": "main"
  }
}
`

	if err := os.WriteFile(biomeConfig, []byte(biomeContent), 0644); err != nil {
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
