package cmd

import (
	"fmt"
	"os"

	"github.com/yoizen/ga/internal/ui"

	"github.com/spf13/cobra"
)

var initCmd = &cobra.Command{
	Use:   "init",
	Short: "Create a sample .ga config file",
	RunE: func(cmd *cobra.Command, args []string) error {
		return runInit()
	},
}

func init() {
	rootCmd.AddCommand(initCmd)
}

func runInit() error {
	ui.PrintBanner("dev")

	if _, err := os.Stat(".ga"); err == nil {
		ui.Warning("Config file already exists: .ga")
		fmt.Print("Overwrite? (y/N): ")
		var confirm string
		fmt.Scanln(&confirm)
		if confirm != "y" && confirm != "Y" {
			fmt.Println("Aborted.")
			return nil
		}
	}

	configContent := `# Guardian Agent Configuration
# https://github.com/Yoizen/dev-ai-workflow

# AI Provider (required)
# Options: claude, gemini, codex, opencode, ollama:<model>, lmstudio[:model], github:<model>
PROVIDER="opencode"

# File patterns to include in review (comma-separated)
FILE_PATTERNS="*.ts,*.tsx,*.js,*.jsx"

# File patterns to exclude from review (comma-separated)
EXCLUDE_PATTERNS="*.test.ts,*.spec.ts,*.test.tsx,*.spec.tsx,*.d.ts"

# File containing code review rules
RULES_FILE="REVIEW.md"

# Strict mode: fail if AI response is ambiguous
STRICT_MODE="true"

# Timeout in seconds for AI provider response
TIMEOUT="300"
`

	if err := os.WriteFile(".ga", []byte(configContent), 0644); err != nil {
		ui.Error("Failed to write config: %v", err)
		return err
	}

	ui.Success("Created config file: .ga")
	ui.Info("Next steps:")
	ui.Info("  1. Edit .ga to set your preferred provider")
	ui.Info("  2. Create REVIEW.md with your coding standards")
	ui.Info("  3. Run: ga install")
	return nil
}
