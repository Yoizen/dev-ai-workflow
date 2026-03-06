package version

import (
	"fmt"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/api"
)

// Resolver handles version resolution with API fallback
type Resolver struct {
	apiClient *api.GitHubAPI
	repo      string
}

// NewResolver creates a new version resolver
func NewResolver(repo string) *Resolver {
	return &Resolver{
		apiClient: api.NewGitHubAPI(repo),
		repo:      repo,
	}
}

// ResolveVersion resolves version based on channel or specific version
func (r *Resolver) ResolveVersion(version, channel string) (string, error) {
	// If specific version is provided, use it
	if version != "" {
		return version, nil
	}

	// Resolve based on channel
	switch channel {
	case "stable":
		return r.getStableVersion()
	case "latest":
		return r.getLatestVersion()
	default:
		// Fallback to main branch
		return "main", nil
	}
}

// getStableVersion gets the latest stable release
func (r *Resolver) getStableVersion() (string, error) {
	version, err := r.apiClient.GetLatestStable()
	if err != nil {
		// Fallback to latest tag
		version, err = r.apiClient.GetLatestTag()
		if err != nil {
			// Final fallback to main branch
			return "main", nil
		}
	}
	return version, nil
}

// getLatestVersion gets the latest release (including prereleases)
func (r *Resolver) getLatestVersion() (string, error) {
	version, err := r.apiClient.GetLatest()
	if err != nil {
		// Fallback to latest tag
		version, err = r.apiClient.GetLatestTag()
		if err != nil {
			// Final fallback to main branch
			return "main", nil
		}
	}
	return version, nil
}

// CheckForUpdates checks if there are updates available
func (r *Resolver) CheckForUpdates(currentVersion, channel string) (bool, string, error) {
	// Resolve latest version based on channel
	latestVersion, err := r.ResolveVersion("", channel)
	if err != nil {
		return false, "", fmt.Errorf("failed to resolve latest version: %w", err)
	}

	// If latest is a branch name, can't compare versions
	if strings.HasPrefix(latestVersion, "main") || strings.HasPrefix(latestVersion, "master") {
		return false, latestVersion, nil
	}

	// Compare versions
	isNewer, err := api.IsNewerVersion(latestVersion, currentVersion)
	if err != nil {
		return false, "", fmt.Errorf("failed to compare versions: %w", err)
	}

	return isNewer, latestVersion, nil
}

// GetInstalledVersion gets the currently installed GA version
func (r *Resolver) GetInstalledVersion() (string, error) {
	// This would typically check the installed GA version
	// For now, return empty - this can be implemented later
	return "", nil
}

// IsValidVersion checks if a version string is valid
func (r *Resolver) IsValidVersion(version string) bool {
	// Check if it's a branch name
	if version == "main" || version == "master" {
		return true
	}

	// Check if it's a valid semantic version
	_, err := api.ParseVersion(version)
	return err == nil
}

// NormalizeVersion normalizes a version string
func (r *Resolver) NormalizeVersion(version string) string {
	// Ensure version starts with 'v' if it's a semantic version
	if !strings.HasPrefix(version, "v") && 
		!strings.HasPrefix(version, "main") && 
		!strings.HasPrefix(version, "master") {
		return "v" + version
	}
	return version
}
