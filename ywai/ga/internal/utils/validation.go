package utils

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"
)

// ValidateFilePath validates and sanitizes file paths to prevent security issues
func ValidateFilePath(path string) error {
	if path == "" {
		return fmt.Errorf("file path cannot be empty")
	}

	// Convert to clean path
	cleanPath := filepath.Clean(path)

	// Check for absolute paths (not allowed for security)
	if filepath.IsAbs(cleanPath) {
		return fmt.Errorf("absolute paths not allowed: %s", cleanPath)
	}

	// Check for directory traversal attempts
	if strings.Contains(cleanPath, "..") {
		return fmt.Errorf("directory traversal not allowed: %s", cleanPath)
	}

	// Check for suspicious patterns
	suspiciousPatterns := []string{
		"../", "..\\",
		"/etc/", "/proc/", "/sys/", "/dev/",
		"\\..\\", "\\..",
	}

	for _, pattern := range suspiciousPatterns {
		if strings.Contains(strings.ToLower(cleanPath), strings.ToLower(pattern)) {
			return fmt.Errorf("suspicious path pattern detected: %s", cleanPath)
		}
	}

	return nil
}

// ValidateFileExists checks if a file exists and is accessible
func ValidateFileExists(path string) error {
	if err := ValidateFilePath(path); err != nil {
		return err
	}

	info, err := os.Stat(path)
	if err != nil {
		if os.IsNotExist(err) {
			return fmt.Errorf("file does not exist: %s", path)
		}
		return fmt.Errorf("cannot access file: %s: %v", path, err)
	}

	// Check if it's actually a file (not directory)
	if info.IsDir() {
		return fmt.Errorf("path is a directory, not a file: %s", path)
	}

	return nil
}

// SanitizeFileName removes or replaces problematic characters in filenames
func SanitizeFileName(name string) string {
	// Replace problematic characters with underscores
	replacements := map[string]string{
		"/": "_", "\\": "_", ":": "_", "*": "_", "?": "_",
		"\"": "_", "<": "_", ">": "_", "|": "_", "\n": "_",
		"\r": "_", "\t": "_",
	}

	result := name
	for old, new := range replacements {
		result = strings.ReplaceAll(result, old, new)
	}

	// Remove control characters
	var sb strings.Builder
	for _, r := range result {
		if r < 32 {
			continue // Skip control characters
		}
		sb.WriteRune(r)
	}

	// Limit length to prevent issues
	maxLen := 255
	if sb.Len() > maxLen {
		return sb.String()[:maxLen]
	}

	return sb.String()
}

// IsValidPattern checks if a file pattern is safe to use
func IsValidPattern(pattern string) error {
	if pattern == "" {
		return fmt.Errorf("pattern cannot be empty")
	}

	// Check for directory traversal in patterns
	if strings.Contains(pattern, "..") {
		return fmt.Errorf("directory traversal not allowed in pattern: %s", pattern)
	}

	// Check for absolute paths in patterns
	if filepath.IsAbs(pattern) {
		return fmt.Errorf("absolute paths not allowed in patterns: %s", pattern)
	}

	return nil
}
