package cmd

import (
	"os"
	"strings"

	"github.com/yoizen/ga/internal/git"
	"github.com/yoizen/ga/internal/ui"

	"github.com/spf13/cobra"
)

var uninstallCmd = &cobra.Command{
	Use:   "uninstall",
	Short: "Remove git hooks from current repo",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runUninstall()
	},
}

func init() {
	rootCmd.AddCommand(uninstallCmd)
}

func runUninstall() error {
	ui.PrintBanner("dev")

	if !git.IsGitRepo() {
		ui.Error("Not a git repository")
		return nil
	}

	hooksDir, err := git.GetHooksDir()
	if err != nil {
		ui.Error("Failed to get hooks directory: %v", err)
		return err
	}

	found := false
	for _, hook := range []string{"pre-commit", "commit-msg"} {
		hookPath := hooksDir + "/" + hook
		if _, err := os.Stat(hookPath); err == nil {
			data, _ := os.ReadFile(hookPath)
			content := string(data)
			if strings.Contains(content, "GA START") || strings.Contains(content, "ga run") {
				if err := os.Remove(hookPath); err != nil {
					ui.Error("Failed to remove %s: %v", hookPath, err)
				} else {
					ui.Success("Removed %s hook", hook)
					found = true
				}
			}
		}
	}

	if !found {
		ui.Warning("No GA hooks found")
	}
	return nil
}
