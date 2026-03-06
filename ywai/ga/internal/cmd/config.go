package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/yoizen/ga/internal/config"
	"github.com/yoizen/ga/internal/ui"

	"github.com/spf13/cobra"
)

var configCmd = &cobra.Command{
	Use:   "config",
	Short: "Show current configuration",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runConfig()
	},
}

func init() {
	rootCmd.AddCommand(configCmd)
}

func runConfig() error {
	ui.PrintBanner("dev")

	cfg, err := config.Load()
	if err != nil {
		ui.Error("Failed to load config: %v", err)
		return err
	}

	ui.Info("Current Configuration:")
	fmt.Println("")

	globalConfig := filepath.Join(os.Getenv("HOME"), ".config", "ga", "config")
	projectConfig := ".ga"

	ui.Info("Config Files:")
	if _, err := os.Stat(globalConfig); err == nil {
		ui.Info("  Global:  %s", globalConfig)
	} else {
		ui.Info("  Global:  Not found")
	}
	if _, err := os.Stat(projectConfig); err == nil {
		ui.Info("  Project: %s", projectConfig)
	} else {
		ui.Info("  Project: Not found")
	}
	fmt.Println("")

	ui.Info("Values:")
	if cfg.Provider != "" {
		ui.Info("  PROVIDER:          %s", cfg.Provider)
	} else {
		ui.Error("  PROVIDER:          Not configured")
	}
	ui.Info("  FILE_PATTERNS:     %s", cfg.FilePatterns)
	if cfg.ExcludePatterns != "" {
		ui.Info("  EXCLUDE_PATTERNS:  %s", cfg.ExcludePatterns)
	}
	ui.Info("  RULES_FILE:        %s", cfg.RulesFile)
	ui.Info("  STRICT_MODE:       %v", cfg.StrictMode)
	ui.Info("  TIMEOUT:           %ds", cfg.Timeout)
	if cfg.PRBaseBranch != "" {
		ui.Info("  PR_BASE_BRANCH:    %s", cfg.PRBaseBranch)
	}
	fmt.Println("")

	if _, err := os.Stat(cfg.RulesFile); err == nil {
		ui.Success("Rules File: Found")
	} else {
		ui.Error("Rules File: Not found (%s)", cfg.RulesFile)
	}

	return nil
}
