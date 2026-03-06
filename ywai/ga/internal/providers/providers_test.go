package providers

import (
	"os/exec"
	"testing"
)

func hasCommand(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func TestValidateProvider(t *testing.T) {
	hasClaude := hasCommand("claude")
	hasOllama := hasCommand("ollama")
	hasGh := hasCommand("gh")

	tests := []struct {
		name      string
		provider  string
		wantError bool
	}{
		{
			name:      "claude - when not installed",
			provider:  "claude",
			wantError: !hasClaude,
		},
		{
			name:      "unknown provider",
			provider:  "unknown",
			wantError: true,
		},
		{
			name:      "github with model - when gh not installed",
			provider:  "github:gpt-4o",
			wantError: !hasGh,
		},
		{
			name:      "ollama - when not installed",
			provider:  "ollama",
			wantError: !hasOllama,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := ValidateProvider(tt.provider)
			if (err != nil) != tt.wantError {
				t.Errorf("ValidateProvider() error = %v, wantError %v", err, tt.wantError)
			}
		})
	}
}

func TestNewProvider(t *testing.T) {
	tests := []struct {
		name      string
		provider  string
		wantError bool
	}{
		{
			name:      "claude",
			provider:  "claude",
			wantError: false,
		},
		{
			name:      "gemini",
			provider:  "gemini",
			wantError: false,
		},
		{
			name:      "codex",
			provider:  "codex",
			wantError: false,
		},
		{
			name:      "opencode without model",
			provider:  "opencode",
			wantError: false,
		},
		{
			name:      "opencode with model",
			provider:  "opencode:anthropic/claude-opus-4-5",
			wantError: false,
		},
		{
			name:      "ollama with model",
			provider:  "ollama:llama3.2",
			wantError: false,
		},
		{
			name:      "lmstudio without model",
			provider:  "lmstudio",
			wantError: false,
		},
		{
			name:      "lmstudio with model",
			provider:  "lmstudio:qwen2.5-coder-7b",
			wantError: false,
		},
		{
			name:      "github with model",
			provider:  "github:gpt-4o",
			wantError: false,
		},
		{
			name:      "unknown provider",
			provider:  "unknown",
			wantError: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			_, err := NewProvider(&Config{Provider: tt.provider, Timeout: 300})
			if (err != nil) != tt.wantError {
				t.Errorf("NewProvider() error = %v, wantError %v", err, tt.wantError)
			}
		})
	}
}
