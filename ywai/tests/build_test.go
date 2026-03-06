package tests

import (
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"testing"
)

func TestGoBuild(t *testing.T) {
	setupDir := filepath.Join(getRepoRoot(), "ywai", "setup")

	t.Log("▶ Testing Go build process")

	// Clean build artifacts
	t.Log("  Cleaning build artifacts...")
	_, err := runCommand(setupDir, "make", "clean")
	if err != nil {
		t.Errorf("Make clean failed: %v", err)
		return
	}

	// Build Go binary
	t.Log("  Building Go binary...")
	_, err = runCommand(setupDir, "make", "build")
	if err != nil {
		t.Errorf("Make build failed: %v", err)
		return
	}

	// Verify binary exists
	binaryPath := filepath.Join(setupDir, "setup-wizard")
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		t.Errorf("Binary not found at %s", binaryPath)
		return
	}

	t.Log("  ✅ Go build successful")
}

func TestGoBinaryExecution(t *testing.T) {
	setupDir := filepath.Join(getRepoRoot(), "ywai", "setup")
	binaryPath := filepath.Join(setupDir, "setup-wizard")

	// Ensure binary exists
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		t.Skip("Binary not found, skipping execution tests")
	}

	t.Log("▶ Testing Go binary execution")

	// Test version flag
	t.Log("  Testing --version flag...")
	output, err := runCommand(setupDir, "./setup-wizard", "--version")
	if err != nil {
		t.Errorf("Version command failed: %v\nOutput: %s", err, output)
		return
	}

	if !strings.Contains(output, "YWAI Setup Wizard v") && !strings.Contains(strings.ToLower(output), "version") {
		t.Errorf("Version output unexpected: %s", output)
		return
	}

	// Test help flag
	t.Log("  Testing --help flag...")
	output, err = runCommand(setupDir, "./setup-wizard", "--help")
	if err != nil {
		t.Errorf("Help command failed: %v\nOutput: %s", err, output)
		return
	}

	if !strings.Contains(output, "Usage") && !strings.Contains(output, "help") {
		t.Errorf("Help output unexpected: %s", output)
		return
	}

	t.Log("  ✅ Binary execution successful")
}

func TestGoDryRunMode(t *testing.T) {
	setupDir := filepath.Join(getRepoRoot(), "ywai", "setup")
	binaryPath := filepath.Join(setupDir, "setup-wizard")

	// Ensure binary exists
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		t.Skip("Binary not found, skipping dry-run tests")
	}

	t.Log("▶ Testing dry-run mode")

	// Create temp test directory
	tempDir, err := os.MkdirTemp("", "ywai-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Initialize git repo
	_, err = runCommand(tempDir, "git", "init")
	if err != nil {
		t.Fatalf("Failed to init git repo: %v", err)
	}

	// Copy necessary files
	filesToCopy := []string{"setup", "config", "extensions", "types", "templates"}
	for _, file := range filesToCopy {
		src := filepath.Join(getRepoRoot(), "ywai", file)
		dst := filepath.Join(tempDir, file)

		cmd := exec.Command("cp", "-r", src, dst)
		if err := cmd.Run(); err != nil {
			t.Logf("Warning: Could not copy %s: %v", file, err)
		}
	}

	// Run dry-run
	t.Log("  Running setup wizard in dry-run mode...")
	output, err := runCommand(filepath.Join(tempDir, "setup"), "./setup-wizard", "--dry-run", "--all")
	if err != nil {
		t.Errorf("Dry-run failed: %v\nOutput: %s", err, output)
		return
	}

	if !strings.Contains(output, "DRY RUN MODE") {
		t.Errorf("Expected DRY RUN MODE in output, got: %s", output)
		return
	}

	t.Log("  ✅ Dry-run mode successful")
}

func TestGoBinaryInDocker(t *testing.T) {
	if testing.Short() {
		t.Skip("Skipping Docker test in short mode")
	}

	const testImage = "ywai-test"

	// Check if Docker is available
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("Docker not available")
	}

	// Check if image exists
	cmd := exec.Command("docker", "image", "inspect", testImage)
	if err := cmd.Run(); err != nil {
		t.Skip("Docker image not found, skipping Docker tests")
	}

	t.Log("▶ Testing Go binary in Docker")

	dockerCmd := exec.Command("docker", "run", "--rm", "-i",
		"-v", getRepoRoot()+":/src",
		testImage, "bash", "-lc",
		"cd /src/ywai/setup && make clean && make build && test -f setup-wizard && echo \"BUILD_OK\"")

	output, err := dockerCmd.CombinedOutput()
	if err != nil {
		t.Errorf("Docker build failed: %v\nOutput: %s", err, string(output))
		return
	}

	if !strings.Contains(string(output), "BUILD_OK") {
		t.Errorf("Expected BUILD_OK in Docker output, got: %s", string(output))
		return
	}

	t.Log("  ✅ Docker build successful")
}

func TestGoBinaryErrors(t *testing.T) {
	setupDir := filepath.Join(getRepoRoot(), "ywai", "setup")
	binaryPath := filepath.Join(setupDir, "setup-wizard")

	// Ensure binary exists
	if _, err := os.Stat(binaryPath); os.IsNotExist(err) {
		t.Skip("Binary not found, skipping error tests")
	}

	t.Log("▶ Testing error handling")

	// Test invalid flag
	t.Log("  Testing invalid flag...")
	_, err := runCommand(setupDir, "./setup-wizard", "--invalid-flag")
	if err == nil {
		t.Error("Expected error for invalid flag, but command succeeded")
		return
	}

	// Test invalid project type in temp directory
	tempDir, err := os.MkdirTemp("", "ywai-error-test-*")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Initialize git repo
	_, err = runCommand(tempDir, "git", "init")
	if err != nil {
		t.Fatalf("Failed to init git repo: %v", err)
	}

	// Copy setup files
	cmd := exec.Command("cp", "-r", filepath.Join(getRepoRoot(), "ywai", "setup"), tempDir)
	if err := cmd.Run(); err != nil {
		t.Logf("Warning: Could not copy setup files: %v", err)
	}

	// Test invalid project type
	t.Log("  Testing invalid project type...")
	output, err := runCommand(filepath.Join(tempDir, "setup"), "./setup-wizard", "--dry-run", "--type", "invalid-type")
	if err != nil {
		t.Errorf("Expected graceful fallback for invalid project type, got error: %v\nOutput: %s", err, output)
		return
	}

	if !strings.Contains(output, "falling back to default") {
		t.Errorf("Expected fallback warning for invalid project type, got: %s", output)
		return
	}

	t.Log("  ✅ Error handling working correctly")
}
