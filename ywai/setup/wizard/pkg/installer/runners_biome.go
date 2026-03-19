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
