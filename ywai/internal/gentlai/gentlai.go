package gentlai

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/internal/config"
)

func IsInstalled() bool {
	if _, err := exec.LookPath(config.GentleAIBin); err == nil {
		return true
	}
	// Also check GOPATH/bin (common on Linux where it's not always in PATH)
	if gopath := os.Getenv("GOPATH"); gopath != "" {
		if _, err := os.Stat(filepath.Join(gopath, "bin", config.GentleAIBin)); err == nil {
			return true
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		if _, err := os.Stat(filepath.Join(home, "go", "bin", config.GentleAIBin)); err == nil {
			return true
		}
	}
	return false
}

func Install() error {
	if IsInstalled() {
		fmt.Println("gentle-ai already installed.")
		return nil
	}

	_, err := exec.LookPath("go")
	if err != nil {
		return fmt.Errorf("Go is not installed. Install Go first: https://go.dev/dl/")
	}

	fmt.Println("Installing gentle-ai...")
	cmd := exec.Command("go", "install", "github.com/gentleman-programming/gentle-ai/cmd/gentle-ai@latest")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to install gentle-ai: %w", err)
	}

	if runtime.GOOS == "windows" {
		gopath := os.Getenv("GOPATH")
		if gopath == "" {
			home, _ := os.UserHomeDir()
			gopath = home + "\\go"
		}
		binDir := gopath + "\\bin"
		path := os.Getenv("PATH")
		fmt.Printf("Make sure %s is in your PATH.\n", binDir)
		_ = path
	}

	fmt.Println("gentle-ai installed successfully.")
	return nil
}

func InstallEcosystem(agentName string) error {
	if !IsInstalled() {
		return fmt.Errorf("gentle-ai is not installed. Run install first.")
	}

	components := []string{
		"engram", "sdd", "skills", "context7",
		"persona", "permissions", "theme",
	}

	args := []string{
		"install",
		"--agent", agentName,
		"--persona", "neutral",
	}
	for _, c := range components {
		args = append(args, "--component", c)
	}

	gentleBin := findGentleAI()
	if gentleBin == "" {
		return fmt.Errorf("gentle-ai binary not found in PATH or GOPATH")
	}

	fmt.Printf("Running gentle-ai install --agent %s...\n", agentName)
	cmd := exec.Command(gentleBin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		return err
	}

	UpgradeEngram()
	return nil
}

func UpgradeEngram() {
	engram := findBinary("engram")
	if engram == "" {
		return
	}

	fmt.Println("Checking for engram updates...")
	cmd := exec.Command(engram, "version")
	output, err := cmd.CombinedOutput()
	if err != nil {
		return
	}

	if strings.Contains(string(output), "Update available") {
		fmt.Println("Updating engram...")
		if runtime.GOOS == "windows" {
			engramExe := engram
			if strings.HasSuffix(engram, ".ps1") || strings.HasSuffix(engram, ".cmd") {
				return
			}
			oldPath := engramExe + ".bak"
			os.Rename(engramExe, oldPath)
			if err := runCommand("go", "install", "github.com/Gentleman-Programming/engram/cmd/engram@latest"); err != nil {
				fmt.Printf("  Warning: engram update failed: %v\n", err)
				os.Rename(oldPath, engramExe)
			} else {
				os.Remove(oldPath)
				fmt.Println("  engram updated successfully.")
			}
		} else {
			if err := runCommand("go", "install", "github.com/Gentleman-Programming/engram/cmd/engram@latest"); err != nil {
				fmt.Printf("  Warning: engram update failed: %v\n", err)
			} else {
				fmt.Println("  engram updated successfully.")
			}
		}
	}
}

func Upgrade() error {
	if !IsInstalled() {
		return fmt.Errorf("gentle-ai is not installed")
	}

	gentleBin := findGentleAI()
	if gentleBin == "" {
		return fmt.Errorf("gentle-ai binary not found")
	}

	fmt.Println("Upgrading gentle-ai...")
	cmd := exec.Command(gentleBin, "upgrade")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func Sync() error {
	if !IsInstalled() {
		return fmt.Errorf("gentle-ai is not installed")
	}

	gentleBin := findGentleAI()
	if gentleBin == "" {
		return fmt.Errorf("gentle-ai binary not found")
	}

	fmt.Println("Syncing gentle-ai assets...")
	cmd := exec.Command(gentleBin, "sync")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

func findGentleAI() string {
	if p, err := exec.LookPath(config.GentleAIBin); err == nil {
		return p
	}
	if gopath := os.Getenv("GOPATH"); gopath != "" {
		p := filepath.Join(gopath, "bin", config.GentleAIBin)
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	if home, err := os.UserHomeDir(); err == nil {
		p := filepath.Join(home, "go", "bin", config.GentleAIBin)
		if _, err := os.Stat(p); err == nil {
			return p
		}
	}
	return ""
}

func findBinary(name string) string {
	if path, err := exec.LookPath(name); err == nil {
		return path
	}
	if runtime.GOOS == "windows" {
		for _, ext := range []string{".cmd", ".ps1", ".bat", ".exe"} {
			if path, err := exec.LookPath(name + ext); err == nil {
				return path
			}
		}
	}
	return ""
}

func runCommand(name string, args ...string) error {
	bin := findBinary(name)
	if bin == "" {
		return fmt.Errorf("%s not found", name)
	}

	if runtime.GOOS == "windows" && (strings.HasSuffix(bin, ".ps1") || strings.HasSuffix(bin, ".cmd")) {
		if strings.HasSuffix(bin, ".ps1") {
			fullArgs := append([]string{"-NoProfile", "-File", bin}, args...)
			cmd := exec.Command("powershell", fullArgs...)
			cmd.Stdout = os.Stdout
			cmd.Stderr = os.Stderr
			return cmd.Run()
		}
		fullArgs := append([]string{"/c", bin}, args...)
		cmd := exec.Command("cmd", fullArgs...)
		cmd.Stdout = os.Stdout
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}

	cmd := exec.Command(bin, args...)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}
