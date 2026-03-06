package installer

import (
	"fmt"
	"path/filepath"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
)

func (i *Installer) checkPrerequisites() error {
	i.logger.Log("Checking prerequisites...")

	checks := []PrerequisiteCheck{
		{Name: "Git", Available: i.commandExists("git"), Required: true},
		{Name: "Node.js", Available: i.commandExists("node"), Required: false},
		{Name: "npm", Available: i.commandExists("npm"), Required: false},
		{Name: "VS Code CLI", Available: i.commandExists("code"), Required: false},
	}

	for _, check := range checks {
		if check.Available {
			version := i.getVersion(check.Name)
			if version != "" {
				i.logger.Log(fmt.Sprintf("  %s: %s%s%s", check.Name, ui.ColorGreen, version, ui.ColorReset))
			} else {
				i.logger.Log(fmt.Sprintf("  %s: %savailable%s", check.Name, ui.ColorGreen, ui.ColorReset))
			}
		} else {
			if check.Required {
				i.logger.LogError(fmt.Sprintf("%s not found (required)", check.Name))
				return fmt.Errorf("required prerequisite %s not found", check.Name)
			} else {
				i.logger.Log(fmt.Sprintf("  %s: %snot available%s", check.Name, ui.ColorYellow, ui.ColorReset))
			}
		}
	}

	i.logger.Log("")
	return nil
}

func (i *Installer) getVersion(tool string) string {
	switch tool {
	case "git":
		out := i.commandOutput("git", "--version")
		return strings.TrimSpace(strings.Replace(out, "git version ", "", 1))
	case "node":
		out := i.commandOutput("node", "--version")
		return strings.TrimPrefix(strings.TrimSpace(out), "v")
	case "npm":
		out := i.commandOutput("npm", "--version")
		return strings.TrimSpace(out)
	default:
		return ""
	}
}

func (i *Installer) ensureGitRepo() error {
	if i.flags.DryRun {
		i.logger.LogInfo("DRY RUN: Would initialize git repository")
		return nil
	}

	gitDir := filepath.Join(i.targetDir, ".git")
	if i.dirExists(gitDir) {
		return nil
	}

	i.logger.LogInfo("Initializing git repository...")
	if err := i.runCommand("git", "init"); err != nil {
		return err
	}
	i.logger.LogSuccess("Git repository initialized")
	return nil
}
