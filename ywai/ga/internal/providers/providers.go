package providers

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"strings"
	"time"
)

type Provider interface {
	Name() string
	Validate() error
	Execute(prompt string) (string, error)
}

type Config struct {
	Provider string
	Model    string
	Timeout  int
}

// ValidateConfig validates the provider configuration
func ValidateConfig(cfg *Config) error {
	if cfg.Timeout <= 0 {
		return fmt.Errorf("timeout must be positive, got: %d", cfg.Timeout)
	}
	if cfg.Timeout > 3600 {
		return fmt.Errorf("timeout too large (max 3600s), got: %d", cfg.Timeout)
	}
	if cfg.Provider == "" {
		return fmt.Errorf("provider cannot be empty")
	}
	return nil
}

func NewProvider(cfg *Config) (Provider, error) {
	if err := ValidateConfig(cfg); err != nil {
		return nil, fmt.Errorf("invalid config: %v", err)
	}
	
	baseProvider := strings.Split(cfg.Provider, ":")[0]

	switch baseProvider {
	case "claude":
		return &ClaudeProvider{timeout: cfg.Timeout}, nil
	case "gemini":
		return &GeminiProvider{timeout: cfg.Timeout}, nil
	case "codex":
		return &CodexProvider{timeout: cfg.Timeout}, nil
	case "opencode":
		model := strings.TrimPrefix(cfg.Provider, "opencode:")
		if model == cfg.Provider {
			model = ""
		}
		return &OpenCodeProvider{model: model, timeout: cfg.Timeout}, nil
	case "ollama":
		model := strings.TrimPrefix(cfg.Provider, "ollama:")
		if model == cfg.Provider {
			model = "llama3.2"  // Default fallback
		}
		return &OllamaProvider{model: model, timeout: cfg.Timeout}, nil
	case "lmstudio":
		model := strings.TrimPrefix(cfg.Provider, "lmstudio:")
		if model == cfg.Provider {
			model = ""
		}
		return &LMStudioProvider{model: model, timeout: cfg.Timeout}, nil
	case "github":
		model := strings.TrimPrefix(cfg.Provider, "github:")
		if model == cfg.Provider {
			return nil, fmt.Errorf("github provider requires a model: github:gpt-4o")
		}
		return &GitHubProvider{model: model, timeout: cfg.Timeout}, nil
	default:
		return nil, fmt.Errorf("unknown provider: %s", baseProvider)
	}
}

func ValidateProvider(provider string) error {
	baseProvider := strings.Split(provider, ":")[0]

	switch baseProvider {
	case "claude":
		return checkCommand("claude")
	case "gemini":
		if err := checkCommand("gemini"); err != nil {
			return fmt.Errorf("Gemini CLI not found. Install: npm install -g @anthropic-ai/gemini-cli")
		}
		return nil
	case "codex":
		return checkCommand("codex")
	case "opencode":
		return checkCommand("opencode")
	case "ollama":
		return checkCommand("ollama")
	case "lmstudio":
		return nil
	case "github":
		return checkCommand("gh")
	default:
		return fmt.Errorf("unknown provider: %s", baseProvider)
	}
}

func checkCommand(cmd string) error {
	if _, err := exec.LookPath(cmd); err != nil {
		return fmt.Errorf("%s not found", cmd)
	}
	return nil
}

type ClaudeProvider struct {
	timeout int
}

func (p *ClaudeProvider) Name() string    { return "Claude" }
func (p *ClaudeProvider) Validate() error { return checkCommand("claude") }

func (p *ClaudeProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "claude", "--print")
	cmd.Stdin = strings.NewReader(prompt)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("claude command timed out after %d seconds", p.timeout)
		}
		return "", fmt.Errorf("claude command failed: %v\nOutput: %s", err, string(out))
	}
	return string(out), nil
}

type GeminiProvider struct {
	timeout int
}

func (p *GeminiProvider) Name() string { return "Gemini" }

func (p *GeminiProvider) Validate() error {
	if err := checkCommand("gemini"); err != nil {
		return err
	}
	cmd := exec.Command("gemini", "whoami")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("Gemini CLI not authenticated. Run: gemini login")
	}
	return nil
}

func (p *GeminiProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "gemini", "-p", prompt)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("gemini command timed out after %d seconds", p.timeout)
		}
		return "", fmt.Errorf("gemini command failed: %v\nOutput: %s", err, string(out))
	}
	return string(out), nil
}

type CodexProvider struct {
	timeout int
}

func (p *CodexProvider) Name() string    { return "Codex" }
func (p *CodexProvider) Validate() error { return checkCommand("codex") }

func (p *CodexProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "codex", "exec", prompt)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("codex command timed out after %d seconds", p.timeout)
		}
		return "", fmt.Errorf("codex command failed: %v\nOutput: %s", err, string(out))
	}
	return string(out), nil
}

type OpenCodeProvider struct {
	model   string
	timeout int
}

func (p *OpenCodeProvider) Name() string { return "OpenCode" }
func (p *OpenCodeProvider) Validate() error {
	return checkCommand("opencode")
}

func (p *OpenCodeProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	var cmd *exec.Cmd
	if p.model != "" {
		cmd = exec.CommandContext(ctx, "opencode", "run", "--model", p.model, prompt)
	} else {
		cmd = exec.CommandContext(ctx, "opencode", "run", prompt)
	}
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("opencode command timed out after %d seconds", p.timeout)
		}
		return "", fmt.Errorf("opencode command failed: %v\nOutput: %s", err, string(out))
	}
	return string(out), nil
}

type OllamaProvider struct {
	model   string
	timeout int
}

func (p *OllamaProvider) Name() string    { return "Ollama" }
func (p *OllamaProvider) Validate() error { return checkCommand("ollama") }

func (p *OllamaProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	cmd := exec.CommandContext(ctx, "ollama", "run", p.model, prompt)
	out, err := cmd.CombinedOutput()
	if err != nil {
		if ctx.Err() == context.DeadlineExceeded {
			return "", fmt.Errorf("ollama command timed out after %d seconds", p.timeout)
		}
		return "", fmt.Errorf("ollama command failed: %v\nOutput: %s", err, string(out))
	}
	return string(out), nil
}

type LMStudioProvider struct {
	model   string
	timeout int
}

func (p *LMStudioProvider) Name() string { return "LM Studio" }
func (p *LMStudioProvider) Validate() error {
	host := os.Getenv("LMSTUDIO_HOST")
	if host == "" {
		host = "http://localhost:1234/v1"
	}

	client := &http.Client{Timeout: 5 * time.Second}
	resp, err := client.Get(host + "/models")
	if err != nil {
		return fmt.Errorf("LM Studio not reachable at %s: %v", host, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("LM Studio API not responding correctly: %d", resp.StatusCode)
	}

	return nil
}

func (p *LMStudioProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	host := os.Getenv("LMSTUDIO_HOST")
	if host == "" {
		host = "http://localhost:1234/v1"
	}

	requestBody := map[string]interface{}{
		"model": p.model, // Use configured model instead of hardcoded
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
		"temperature": 0.1,
		"max_tokens": 4000,
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %v", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", host+"/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %v", err)
	}
	req.Header.Set("Content-Type", "application/json")

	// Use shorter timeout for HTTP client to ensure context timeout takes precedence
	client := &http.Client{
		Timeout: time.Duration(p.timeout) * time.Second,
		Transport: &http.Transport{
			ResponseHeaderTimeout: time.Duration(p.timeout-5) * time.Second,
			IdleConnTimeout:       30 * time.Second,
			DisableKeepAlives:     true,
		},
	}
	
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("LM Studio API request failed: %v", err)
	}
	defer func() {
		if resp.Body != nil {
			resp.Body.Close()
		}
	}()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		return "", fmt.Errorf("LM Studio API error: %d - %s", resp.StatusCode, string(body))
	}

	var response struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return "", fmt.Errorf("failed to decode response: %v", err)
	}

	if len(response.Choices) == 0 {
		return "", fmt.Errorf("no response from LM Studio")
	}

	return response.Choices[0].Message.Content, nil
}

type GitHubProvider struct {
	model   string
	timeout int
}

func (p *GitHubProvider) Name() string { return "GitHub Models" }

func (p *GitHubProvider) Validate() error {
	if err := checkCommand("gh"); err != nil {
		return fmt.Errorf("gh CLI not found. Install: brew install gh")
	}
	cmd := exec.Command("gh", "auth", "status")
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("gh CLI not authenticated. Run: gh auth login")
	}
	return nil
}

func (p *GitHubProvider) Execute(prompt string) (string, error) {
	ctx, cancel := context.WithTimeout(context.Background(), time.Duration(p.timeout)*time.Second)
	defer cancel()
	
	// Get token from gh CLI securely
	tokenCmd := exec.CommandContext(ctx, "gh", "auth", "token")
	token, err := tokenCmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get gh auth token: %v", err)
	}

	requestBody := map[string]interface{}{
		"model": p.model,
		"messages": []map[string]string{
			{"role": "user", "content": prompt},
		},
		"temperature": 0.1,
		"max_tokens": 4000,
	}

	jsonData, err := json.Marshal(requestBody)
	if err != nil {
		return "", fmt.Errorf("failed to marshal request: %v", err)
	}

	req, err := http.NewRequestWithContext(ctx, "POST", "https://models.inference.ai.azure.com/chat/completions", bytes.NewBuffer(jsonData))
	if err != nil {
		return "", fmt.Errorf("failed to create request: %v", err)
	}

	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Authorization", "Bearer "+strings.TrimSpace(string(token)))

	// Use improved HTTP client with proper timeout handling
	client := &http.Client{
		Timeout: time.Duration(p.timeout) * time.Second,
		Transport: &http.Transport{
			ResponseHeaderTimeout: time.Duration(p.timeout-5) * time.Second,
			IdleConnTimeout:       30 * time.Second,
			DisableKeepAlives:     true,
		},
	}
	
	resp, err := client.Do(req)
	if err != nil {
		return "", fmt.Errorf("GitHub Models API request failed: %v", err)
	}
	defer func() {
		if resp.Body != nil {
			resp.Body.Close()
		}
	}()

	if resp.StatusCode != http.StatusOK {
		body, _ := io.ReadAll(resp.Body)
		// Redact token from error messages to prevent security leaks
		errorMsg := fmt.Sprintf("GitHub Models API error: %d - %s", resp.StatusCode, string(body))
		if len(token) > 0 {
			tokenStr := strings.TrimSpace(string(token))
			errorMsg = strings.ReplaceAll(errorMsg, tokenStr, "[REDACTED]")
		}
		return "", fmt.Errorf(errorMsg)
	}

	var response struct {
		Choices []struct {
			Message struct {
				Content string `json:"content"`
			} `json:"message"`
		} `json:"choices"`
	}

	if err := json.NewDecoder(resp.Body).Decode(&response); err != nil {
		return "", fmt.Errorf("failed to decode response: %v", err)
	}

	if len(response.Choices) == 0 {
		return "", fmt.Errorf("no response from GitHub Models")
	}

	return response.Choices[0].Message.Content, nil
}
