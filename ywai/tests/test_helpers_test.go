package tests

import (
	"os"
	"os/exec"
	"path/filepath"
)

func getRepoRoot() string {
	dir, _ := os.Getwd()
	for {
		if _, err := os.Stat(filepath.Join(dir, "ywai")); err == nil {
			return dir
		}
		parent := filepath.Dir(dir)
		if parent == dir {
			break
		}
		dir = parent
	}
	return "."
}

func runCommand(dir string, command string, args ...string) (string, error) {
	cmd := exec.Command(command, args...)
	if dir != "" {
		cmd.Dir = dir
	}

	output, err := cmd.CombinedOutput()
	return string(output), err
}
