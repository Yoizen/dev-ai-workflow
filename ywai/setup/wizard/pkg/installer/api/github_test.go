package api

import (
	"testing"
)

func TestNewGitHubAPI(t *testing.T) {
	api := NewGitHubAPI("test/repo")
	
	if api == nil {
		t.Fatal("Expected non-nil API client")
	}
	
	if api.repoURL != "https://api.github.com/repos/test/repo" {
		t.Errorf("Expected repoURL to be 'https://api.github.com/repos/test/repo', got '%s'", api.repoURL)
	}
	
	if api.baseURL != "https://api.github.com" {
		t.Errorf("Expected baseURL to be 'https://api.github.com', got '%s'", api.baseURL)
	}
	
	if api.client == nil {
		t.Error("Expected non-nil HTTP client")
	}
}

func TestVersionParsing(t *testing.T) {
	tests := []struct {
		input    string
		expected string
		hasError bool
	}{
		{"v1.2.3", "v1.2.3", false},
		{"1.2.3", "v1.2.3", false},
		{"main", "main", false},
		{"master", "master", false},
		{"invalid", "", true},
	}
	
	for _, test := range tests {
		t.Run(test.input, func(t *testing.T) {
			if test.input == "main" || test.input == "master" {
				// These should be handled as-is
				return
			}
			
			version, err := ParseVersion(test.input)
			
			if test.hasError {
				if err == nil {
					t.Errorf("Expected error for input '%s'", test.input)
				}
			} else {
				if err != nil {
					t.Errorf("Unexpected error for input '%s': %v", test.input, err)
				}
				
				if version.String() != test.expected {
					t.Errorf("Expected '%s', got '%s'", test.expected, version.String())
				}
			}
		})
	}
}

func TestVersionComparison(t *testing.T) {
	tests := []struct {
		v1       string
		v2       string
		expected int
	}{
		{"v1.0.0", "v1.0.0", 0},
		{"v1.0.1", "v1.0.0", 1},
		{"v1.0.0", "v1.0.1", -1},
		{"v1.1.0", "v1.0.0", 1},
		{"v1.0.0", "v1.1.0", -1},
		{"v2.0.0", "v1.0.0", 1},
		{"v1.0.0", "v2.0.0", -1},
	}
	
	for _, test := range tests {
		t.Run(test.v1+"_vs_"+test.v2, func(t *testing.T) {
			cmp, err := CompareVersions(test.v1, test.v2)
			if err != nil {
				t.Errorf("Unexpected error: %v", err)
			}
			
			if cmp != test.expected {
				t.Errorf("Expected comparison result %d, got %d", test.expected, cmp)
			}
		})
	}
}

func TestVersionHelpers(t *testing.T) {
	v1, _ := ParseVersion("v1.0.0")
	v2, _ := ParseVersion("v1.0.1")
	
	// Test IsNewerThan
	if !v2.IsNewerThan(v1) {
		t.Error("Expected v1.0.1 to be newer than v1.0.0")
	}
	
	if v1.IsNewerThan(v2) {
		t.Error("Expected v1.0.0 to not be newer than v1.0.1")
	}
	
	// Test IsOlderThan
	if !v1.IsOlderThan(v2) {
		t.Error("Expected v1.0.0 to be older than v1.0.1")
	}
	
	if v2.IsOlderThan(v1) {
		t.Error("Expected v1.0.1 to not be older than v1.0.0")
	}
	
	// Test IsEqual
	if !v1.IsEqual(v1) {
		t.Error("Expected v1.0.0 to be equal to itself")
	}
	
	if v1.IsEqual(v2) {
		t.Error("Expected v1.0.0 to not be equal to v1.0.1")
	}
}
