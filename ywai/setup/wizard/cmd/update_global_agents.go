package main

import (
	"fmt"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
)

// runUpdateGlobalAgents delegates to the in-process global agents generator.
// The legacy implementation hardcoded user-specific paths like
// ~/Documents/GitHub/dev-ai-workflow/... which only worked on one machine.
func runUpdateGlobalAgents(flags *installer.Flags) error {
	fmt.Println("Checking for global agents updates...")

	inst := installer.New(flags)
	if err := inst.UpdateGlobalAgents(); err != nil {
		return fmt.Errorf("failed to run global agents update: %w", err)
	}

	fmt.Println("\nGlobal agents updated successfully")
	return nil
}
