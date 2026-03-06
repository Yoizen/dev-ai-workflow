package api

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"time"
)

// GitHubAPI client for interacting with GitHub API
type GitHubAPI struct {
	client  *http.Client
	baseURL string
	repoURL string
}

// Release represents a GitHub release
type Release struct {
	TagName     string `json:"tag_name"`
	Name        string `json:"name"`
	Prerelease  bool   `json:"prerelease"`
	PublishedAt string `json:"published_at"`
}

// Tag represents a GitHub tag
type Tag struct {
	Name   string `json:"name"`
	Commit struct {
		SHA string `json:"sha"`
	} `json:"commit"`
}

// NewGitHubAPI creates a new GitHub API client
func NewGitHubAPI(repo string) *GitHubAPI {
	return &GitHubAPI{
		client: &http.Client{
			Timeout: 10 * time.Second,
		},
		baseURL: "https://api.github.com",
		repoURL: fmt.Sprintf("https://api.github.com/repos/%s", repo),
	}
}

// GetReleases fetches all releases for the repository
func (g *GitHubAPI) GetReleases() ([]Release, error) {
	url := fmt.Sprintf("%s/releases", g.repoURL)
	
	resp, err := g.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch releases: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}
	
	var releases []Release
	if err := json.Unmarshal(body, &releases); err != nil {
		return nil, fmt.Errorf("failed to parse releases: %w", err)
	}
	
	return releases, nil
}

// GetTags fetches all tags for the repository
func (g *GitHubAPI) GetTags() ([]Tag, error) {
	url := fmt.Sprintf("%s/tags", g.repoURL)
	
	resp, err := g.client.Get(url)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch tags: %w", err)
	}
	defer resp.Body.Close()
	
	if resp.StatusCode != http.StatusOK {
		return nil, fmt.Errorf("API returned status %d", resp.StatusCode)
	}
	
	body, err := io.ReadAll(resp.Body)
	if err != nil {
		return nil, fmt.Errorf("failed to read response: %w", err)
	}
	
	var tags []Tag
	if err := json.Unmarshal(body, &tags); err != nil {
		return nil, fmt.Errorf("failed to parse tags: %w", err)
	}
	
	return tags, nil
}

// GetLatestStable returns the latest non-prerelease version
func (g *GitHubAPI) GetLatestStable() (string, error) {
	releases, err := g.GetReleases()
	if err != nil {
		return "", err
	}
	
	// Find first non-prerelease release
	for _, release := range releases {
		if !release.Prerelease {
			return release.TagName, nil
		}
	}
	
	return "", fmt.Errorf("no stable release found")
}

// GetLatest returns the latest release (including prereleases)
func (g *GitHubAPI) GetLatest() (string, error) {
	releases, err := g.GetReleases()
	if err != nil {
		return "", err
	}
	
	if len(releases) == 0 {
		return "", fmt.Errorf("no releases found")
	}
	
	// Return first release (GitHub returns in reverse chronological order)
	return releases[0].TagName, nil
}

// GetLatestTag returns the latest tag from tags endpoint
func (g *GitHubAPI) GetLatestTag() (string, error) {
	tags, err := g.GetTags()
	if err != nil {
		return "", err
	}
	
	if len(tags) == 0 {
		return "", fmt.Errorf("no tags found")
	}
	
	// Return first tag (GitHub returns in reverse chronological order)
	return tags[0].Name, nil
}
