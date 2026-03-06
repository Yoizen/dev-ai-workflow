package cmd

import (
	"fmt"
	"os"

	"github.com/yoizen/ga/internal/git"
	"github.com/yoizen/ga/internal/ui"

	"github.com/spf13/cobra"
)

var installCmd = &cobra.Command{
	Use:   "install [flags]",
	Short: "Install git pre-commit hook",
	Long: `Install Guardian Agent as a git hook.
By default installs pre-commit hook. Use --commit-msg for commit-msg hook.`,
	RunE: func(cmd *cobra.Command, args []string) error {
		return runInstall(commitMsgHook)
	},
}

var commitMsgHook bool

func init() {
	installCmd.Flags().BoolVar(&commitMsgHook, "commit-msg", false, "Install commit-msg hook instead of pre-commit")
	rootCmd.AddCommand(installCmd)
}

func runInstall(commitMsg bool) error {
	ui.PrintBanner("dev")

	if !git.IsGitRepo() {
		ui.Error("Not a git repository")
		return nil
	}

	hookType := "pre-commit"
	if commitMsg {
		hookType = "commit-msg"
	}

	hooksDir, err := git.GetHooksDir()
	if err != nil {
		ui.Error("Failed to get hooks directory: %v", err)
		return err
	}

	if err := os.MkdirAll(hooksDir, 0755); err != nil {
		ui.Error("Failed to create hooks directory: %v", err)
		return err
	}

	hookPath := hooksDir + "/" + hookType

	var gaCmd string
	if commitMsg {
		gaCmd = `ga run --commit-msg-file "$1" || exit 1`
	} else {
		gaCmd = `ga run || exit 1`
	}

	hookContent := fmt.Sprintf(`#!/usr/bin/env bash

# ======== GA START ========
# Guardian Agent - Code Review
%s
# ======== GA END ========
`, gaCmd)

	if _, err := os.Stat(hookPath); err == nil {
		ui.Warning("Hook already exists: %s", hookPath)
		ui.Info("Appending GA to existing hook...")

		existing, _ := os.ReadFile(hookPath)
		hookContent = string(existing) + "\n" + hookContent
	}

	if err := os.WriteFile(hookPath, []byte(hookContent), 0755); err != nil {
		ui.Error("Failed to write hook: %v", err)
		return err
	}

	ui.Success("Installed %s hook: %s", hookType, hookPath)
	return nil
}
