package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
)

func runUpdateGlobalAgents(flags *installer.Flags) error {
	fmt.Println("Checking for global agents updates...")

	// Find the global-agents install script
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return fmt.Errorf("failed to get home directory: %w", err)
	}

	// Possible locations for the install script
	possiblePaths := []string{
		filepath.Join(homeDir, "Documents", "GitHub", "dev-ai-workflow", "ywai", "extensions", "install-steps", "global-agents", "install.sh"),
		filepath.Join(homeDir, ".local", "share", "ywai", "extensions", "install-steps", "global-agents", "install.sh"),
	}

	var installScript string
	for _, path := range possiblePaths {
		if _, err := os.Stat(path); err == nil {
			installScript = path
			break
		}
	}

	if installScript == "" {
		return fmt.Errorf("global-agents install script not found. Please ensure dev-ai-workflow is installed.")
	}

	fmt.Printf("Using install script: %s\n", installScript)

	// Run the install script
	cmd := exec.Command("bash", installScript, ".")
	cmd.Env = append(os.Environ(), fmt.Sprintf("YWAI_PROJECT_TYPE=%s", flags.ProjectType))
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run global agents update: %w", err)
	}

	fmt.Println("\nGlobal agents updated successfully")
	return nil
}
