package config

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

type Config struct {
	Provider        string
	FilePatterns    string
	ExcludePatterns string
	RulesFile       string
	StrictMode      bool
	Timeout         int
	PRBaseBranch    string
}

const (
	DefaultFilePatterns = "*"
	DefaultRulesFile    = "REVIEW.md"
	DefaultStrictMode   = true
	DefaultTimeout      = 300
)

func Load() (*Config, error) {
	cfg := &Config{
		FilePatterns:    DefaultFilePatterns,
		ExcludePatterns: "",
		RulesFile:       DefaultRulesFile,
		StrictMode:      DefaultStrictMode,
		Timeout:         DefaultTimeout,
		PRBaseBranch:    "",
	}

	home := os.Getenv("HOME")
	if home == "" {
		home = os.Getenv("USERPROFILE")
		if home == "" {
			home = os.Getenv("APPDATA")
		}
	}

	if home != "" {
		globalConfig := filepath.Join(home, ".config", "ga", "config")
		if err := cfg.loadFile(globalConfig); err != nil {
			return nil, err
		}
	}

	projectConfig := ".ga"
	if err := cfg.loadFile(projectConfig); err != nil {
		return nil, err
	}

	if envProvider := os.Getenv("GA_PROVIDER"); envProvider != "" {
		cfg.Provider = envProvider
	}
	if envTimeout := os.Getenv("GA_TIMEOUT"); envTimeout != "" {
		if _, err := fmt.Sscanf(envTimeout, "%d", &cfg.Timeout); err != nil || cfg.Timeout <= 0 {
			cfg.Timeout = DefaultTimeout
		}
	}

	return cfg, nil
}

func (c *Config) loadFile(path string) error {
	data, err := os.ReadFile(path)
	if os.IsNotExist(err) {
		return nil
	}
	if err != nil {
		return fmt.Errorf("failed to read config file %s: %v", path, err)
	}

	lines := strings.Split(string(data), "\n")
	for _, line := range lines {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}

		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			// Log warning but continue parsing
			continue
		}

		key := strings.TrimSpace(parts[0])
		value := strings.TrimSpace(parts[1])
		value = strings.Trim(value, "\"")

		switch key {
		case "PROVIDER":
			c.Provider = value
		case "FILE_PATTERNS":
			c.FilePatterns = value
		case "EXCLUDE_PATTERNS":
			c.ExcludePatterns = value
		case "RULES_FILE":
			c.RulesFile = value
		case "STRICT_MODE":
			c.StrictMode = value == "true"
		case "TIMEOUT":
			if _, err := fmt.Sscanf(value, "%d", &c.Timeout); err != nil || c.Timeout <= 0 {
				c.Timeout = DefaultTimeout
			}
		case "PR_BASE_BRANCH":
			c.PRBaseBranch = value
		default:
			// Unknown key, continue parsing
		}
	}

	return nil
}
