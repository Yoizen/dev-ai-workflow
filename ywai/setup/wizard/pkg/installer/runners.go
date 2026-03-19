package installer

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
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

func (i *Installer) UpdateGA() error {
	return i.installGA()
}

func (i *Installer) UpdateSDD() error {
	return i.installSDD()
}

func (i *Installer) UpdateGlobalAgents() error {
	home, _ := os.UserHomeDir()
	agentsDir := filepath.Join(home, ".config", "opencode")

	srcDir := i.firstExistingDir(
		filepath.Join(i.getRepoRoot(), "ywai", "extensions", "install-steps", "global-agents"),
		filepath.Join(i.getRepoRoot(), "extensions", "install-steps", "global-agents"),
	)
	if srcDir == "" {
		return fmt.Errorf("global-agents extension not found")
	}

	tplDir := filepath.Join(srcDir, "templates")
	if !i.dirExists(tplDir) {
		return fmt.Errorf("global agent templates not found")
	}

	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		return err
	}

	entries, err := os.ReadDir(tplDir)
	if err != nil {
		return err
	}

	installed := 0
	for _, e := range entries {
		if e.IsDir() || !strings.HasSuffix(e.Name(), ".md") {
			continue
		}
		dest := filepath.Join(agentsDir, e.Name())
		if err := i.copyFile(filepath.Join(tplDir, e.Name()), dest); err != nil {
			i.logger.LogWarning(fmt.Sprintf("Failed to copy %s: %v", e.Name(), err))
			continue
		}
		installed++
	}

	if installed > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Updated %d global agent(s)", installed))
	}
	return nil
}

func (i *Installer) UpdateEngram() error {
	extDir := i.firstExistingDir(
		filepath.Join(i.getRepoRoot(), "ywai", "extensions", "install-steps", "engram-setup"),
		filepath.Join(i.getRepoRoot(), "extensions", "install-steps", "engram-setup"),
	)
	if extDir == "" {
		return fmt.Errorf("engram-setup extension not found")
	}

	return i.executeExtensionScriptWithArgs(extDir, "")
}

func (i *Installer) UpdateContext7() error {
	if !i.commandExists("npm") {
		return fmt.Errorf("npm not available")
	}

	home, _ := os.UserHomeDir()
	mcpDir := filepath.Join(home, ".config", "opencode")
	os.MkdirAll(mcpDir, 0755)

	mcpFile := filepath.Join(mcpDir, "mcp.json")

	if err := i.runCommand("npm", "install", "-g", "context7-mcp"); err != nil {
		i.logger.LogWarning("Global install failed, trying user prefix")
		if err2 := i.runCommand("npm", "install", "-g", "context7-mcp", "--prefix", filepath.Join(home, ".local")); err2 != nil {
			return fmt.Errorf("failed to install context7-mcp: %w", err2)
		}
	}

	if i.fileExists(mcpFile) {
		data, err := os.ReadFile(mcpFile)
		if err == nil && strings.Contains(string(data), "context7") {
			i.logger.LogInfo("Context7 already configured in MCP config")
			return nil
		}
	}

	config := `{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
`
	if err := os.WriteFile(mcpFile, []byte(config), 0644); err != nil {
		return err
	}

	i.logger.LogSuccess("Context7 MCP configured")
	return nil
}
