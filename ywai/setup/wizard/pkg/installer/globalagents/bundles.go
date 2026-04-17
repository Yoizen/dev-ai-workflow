// Package globalagents generates global user-profile agent files for
// OpenCode, GitHub Copilot, Gemini, Cursor and Claude from the repository
// templates and bundle configuration.
//
// The generator is the single source of truth replacing the parallel bash
// implementation in ywai/skills/setup.sh --global-only and the thin copy in
// ywai/extensions/install-steps/global-agents/install.{sh,ps1}.
package globalagents

import (
	"encoding/json"
	"os"
)

// BundleConfig models ywai/extensions/install-steps/global-agents/bundles.json.
type BundleConfig struct {
	Defaults      map[string][]string            `json:"defaults"`
	ByProjectType map[string]map[string][]string `json:"by_project_type"`
}

// LoadBundleConfig reads a bundles.json file. Returns a zero-valued config if
// the file does not exist, allowing the generator to fall back gracefully.
func LoadBundleConfig(path string) (*BundleConfig, error) {
	cfg := &BundleConfig{
		Defaults:      map[string][]string{},
		ByProjectType: map[string]map[string][]string{},
	}

	if path == "" {
		return cfg, nil
	}

	data, err := os.ReadFile(path)
	if err != nil {
		if os.IsNotExist(err) {
			return cfg, nil
		}
		return nil, err
	}

	if err := json.Unmarshal(data, cfg); err != nil {
		return nil, err
	}

	if cfg.Defaults == nil {
		cfg.Defaults = map[string][]string{}
	}
	if cfg.ByProjectType == nil {
		cfg.ByProjectType = map[string]map[string][]string{}
	}
	return cfg, nil
}

// Bundle returns the skills bundle for an agent in a given project type.
// Resolution order: by_project_type[projectType][agent] -> defaults[agent].
func (c *BundleConfig) Bundle(projectType, agent string) []string {
	if c == nil {
		return nil
	}
	if overrides, ok := c.ByProjectType[projectType]; ok {
		if skills, ok := overrides[agent]; ok && len(skills) > 0 {
			return append([]string(nil), skills...)
		}
	}
	if skills, ok := c.Defaults[agent]; ok {
		return append([]string(nil), skills...)
	}
	return nil
}
