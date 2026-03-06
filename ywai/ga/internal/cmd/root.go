package cmd

import (
	"fmt"
	"os"

	"github.com/yoizen/ga/internal/ui"
	"github.com/yoizen/ga/internal/version"

	"github.com/spf13/cobra"
)

var (
	commit = ""
	date   = ""
)

var rootCmd = &cobra.Command{
	Use:   "ga",
	Short: "Guardian Agent - Provider-agnostic code review using AI",
	Long: `Guardian Agent is a CLI tool that validates staged files against your project's
coding standards using any AI provider (Claude, Gemini, Codex, Ollama, etc.)`,
	PersistentPreRun: func(cmd *cobra.Command, args []string) {
		// UI doesn't need initialization with current implementation
	},
}

func Execute() {
	version.Commit = commit
	version.Date = date
	version.BuildInfo = version.Version
	if commit != "" {
		version.BuildInfo = fmt.Sprintf("%s (%s)", version.Version, commit[:8])
	}

	if err := rootCmd.Execute(); err != nil {
		ui.Error("Error: %v", err)
		os.Exit(1)
	}
}

func init() {
	rootCmd.Version = version.BuildInfo
	rootCmd.SetVersionTemplate(fmt.Sprintf(`Guardian Agent v{{.Version}}
Provider-agnostic code review using AI
`))
}
