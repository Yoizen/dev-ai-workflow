package tests

import (
	"fmt"
	"os/exec"
	"strings"
	"testing"
)

const (
	testImage  = "ywai-test"
	dockerfile = "Dockerfile.test"
)

func setupDockerImage(t *testing.T) {
	if _, err := exec.LookPath("docker"); err != nil {
		t.Skip("Docker not available")
	}

	if err := exec.Command("docker", "info").Run(); err != nil {
		t.Skipf("Docker not accessible: %v", err)
	}

	// Check if image exists
	cmd := exec.Command("docker", "image", "inspect", testImage)
	if err := cmd.Run(); err == nil {
		return // Image already exists
	}

	// Build image
	t.Log("Building Docker image...")
	buildCmd := exec.Command("docker", "build", "-t", testImage, "-f", dockerfile, ".")
	buildCmd.Dir = getRepoRoot()
	if output, err := buildCmd.CombinedOutput(); err != nil {
		t.Fatalf("Failed to build Docker image: %v\nOutput: %s", err, string(output))
	}
	t.Log("✅ Docker image ready")
}

func runDockerCommand(t *testing.T, command string) (string, error) {
	cmd := exec.Command("docker", "run", "--rm", "-i",
		"-v", getRepoRoot()+":/src",
		testImage, "bash", "-lc", command)

	output, err := cmd.CombinedOutput()
	return string(output), err
}

func TestE2ESetupWizard(t *testing.T) {
	setupDockerImage(t)

	tests := []struct {
		name        string
		command     string
		expect      string
		expectError bool
	}{
		{
			name:    "Go build in Docker",
			command: `cd /src/ywai/setup && make clean && make build && test -f setup-wizard && echo "BUILD_OK"`,
			expect:  "BUILD_OK",
		},
		{
			name:    "Binary version check",
			command: `cd /src/ywai/setup && ./setup-wizard --version 2>&1 | grep -q "YWAI Setup Wizard v" && echo "VERSION_OK"`,
			expect:  "VERSION_OK",
		},
		{
			name:    "Dry run mode",
			command: `mkdir -p /tmp/test-project && cd /tmp/test-project && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && ./setup/setup-wizard --dry-run --all --type=generic 2>&1 | grep -q "DRY RUN MODE" && echo "DRYRUN_OK"`,
			expect:  "DRYRUN_OK",
		},
		{
			name:    "Install script wrapper",
			command: `mkdir -p /tmp/test-project && cd /tmp/test-project && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true bash setup/install.sh --dry-run --all --type=generic 2>&1 | grep -q "DRY RUN MODE" && echo "WRAPPER_OK"`,
			expect:  "WRAPPER_OK",
		},
		{
			name:    "Full setup test",
			command: `mkdir -p /tmp/test-full && cd /tmp/test-full && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --all --type=generic 2>&1 | grep -q "Setup Complete" && echo "FULL_OK"`,
			expect:  "FULL_OK",
		},
		{
			name:    "Project files verification",
			command: `cd /tmp/test-full && test -f .ga && test -f AGENTS.md && test -f .gitignore && echo "FILES_OK"`,
			expect:  "FILES_OK",
		},
		{
			name:    "Nest project type",
			command: `mkdir -p /tmp/test-nest && cd /tmp/test-nest && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --all --type=nest 2>&1 | grep -q "Applying project type: nest" && echo "NEST_OK"`,
			expect:  "NEST_OK",
		},
		{
			name:    "Python project type",
			command: `mkdir -p /tmp/test-python && cd /tmp/test-python && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --all --type=python 2>&1 | grep -q "Applying project type: python" && echo "PYTHON_OK"`,
			expect:  "PYTHON_OK",
		},
		{
			name:    "Invalid project type error handling",
			command: `mkdir -p /tmp/test-invalid && cd /tmp/test-invalid && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && ./setup/setup-wizard --dry-run --all --type=invalid-type 2>&1 | grep -q "Failed to apply project type" && echo "ERROR_OK"`,
			expect:  "ERROR_OK",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			t.Logf("▶ %s", tt.name)

			output, err := runDockerCommand(t, tt.command)

			if tt.expectError && err == nil {
				t.Errorf("Expected error but command succeeded")
				return
			}

			if !tt.expectError && err != nil {
				t.Errorf("Command failed: %v\nOutput: %s", err, output)
				return
			}

			if !strings.Contains(output, tt.expect) {
				t.Errorf("Expected output to contain %q, got:\n%s", tt.expect, output)
				return
			}

			t.Logf("  ✅ PASS")
		})
	}
}

func TestE2EProjectTypes(t *testing.T) {
	setupDockerImage(t)

	projectTypes := []string{"generic", "nest", "nest-angular", "nest-react", "python", "dotnet", "devops"}

	for _, projectType := range projectTypes {
		t.Run(fmt.Sprintf("ProjectType_%s", projectType), func(t *testing.T) {
			command := fmt.Sprintf(`mkdir -p /tmp/test-%s && cd /tmp/test-%s && git init >/dev/null 2>&1 && cp -r /src/ywai/setup . && cp -r /src/ywai/config . && cp -r /src/ywai/extensions . && cp -r /src/ywai/types . && cp -r /src/ywai/templates . && cd setup && make build >/dev/null 2>&1 && cd .. && YWAI_SKIP_MCPS=true ./setup/setup-wizard --dry-run --all --type=%s 2>&1 | grep -q "Applying project type: %s" && echo "TYPE_OK"`,
				projectType, projectType, projectType, projectType)

			output, err := runDockerCommand(t, command)
			if err != nil {
				t.Errorf("Project type %s test failed: %v\nOutput: %s", projectType, err, output)
				return
			}

			if !strings.Contains(output, "TYPE_OK") {
				t.Errorf("Expected TYPE_OK for project type %s, got: %s", projectType, output)
				return
			}

			t.Logf("  ✅ %s project type validated", projectType)
		})
	}
}
