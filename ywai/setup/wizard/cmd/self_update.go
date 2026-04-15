package main

import (
	"fmt"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/api"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/version"
)

const (
	repoOwner = "Yoizen"
	repoName  = "dev-ai-workflow"
)

func runSelfUpdate(flags *installer.Flags) error {
	fmt.Println("Checking for updates...")

	githubAPI := api.NewGitHubAPI(fmt.Sprintf("%s/%s", repoOwner, repoName))
	resolver := version.NewResolver(fmt.Sprintf("%s/%s", repoOwner, repoName))
	
	// Get current version
	currentVersion := flags.BuildVersion
	if currentVersion == "" || currentVersion == "dev" {
		fmt.Println("Current version: dev (development build)")
		fmt.Println("Self-update is only available for released versions")
		return nil
	}

	// Get latest version
	latestVersion, err := resolver.ResolveVersion("", flags.Channel)
	if err != nil {
		return fmt.Errorf("failed to resolve latest version: %w", err)
	}

	if latestVersion == "main" || latestVersion == "master" {
		fmt.Println("Latest version is main branch (no releases available)")
		return nil
	}

	fmt.Printf("Current version: %s\n", currentVersion)
	fmt.Printf("Latest version: %s\n", latestVersion)

	// Check if update is needed
	isNewer, err := api.IsNewerVersion(latestVersion, currentVersion)
	if err != nil {
		return fmt.Errorf("failed to compare versions: %w", err)
	}

	if !isNewer {
		fmt.Println("Already up to date")
		return nil
	}

	fmt.Println("Update available")

	// Download and install update
	if flags.DryRun {
		fmt.Println("DRY RUN: Would download and install update")
		return nil
	}

	return downloadAndInstall(latestVersion, githubAPI, flags)
}

func downloadAndInstall(version string, githubAPI *api.GitHubAPI, flags *installer.Flags) error {
	// Determine platform
	osName := runtime.GOOS
	arch := runtime.GOARCH

	// Map arch names
	archMap := map[string]string{
		"amd64": "amd64",
		"arm64": "arm64",
	}
	archName, ok := archMap[arch]
	if !ok {
		return fmt.Errorf("unsupported architecture: %s", arch)
	}

	// Construct download URL
	// Format: https://github.com/Yoizen/dev-ai-workflow/releases/download/vX.Y.Z/setup-wizard-{os}-{arch}
	binaryName := fmt.Sprintf("setup-wizard-%s-%s", osName, archName)
	downloadURL := fmt.Sprintf("https://github.com/%s/%s/releases/download/%s/%s", repoOwner, repoName, version, binaryName)

	fmt.Printf("Downloading from: %s\n", downloadURL)

	// Download to temp file
	tmpDir, err := os.MkdirTemp("", "ywai-update-*")
	if err != nil {
		return fmt.Errorf("failed to create temp directory: %w", err)
	}
	defer os.RemoveAll(tmpDir)

	tmpFile := filepath.Join(tmpDir, "setup-wizard")
	if err := downloadFile(downloadURL, tmpFile); err != nil {
		return fmt.Errorf("failed to download: %w", err)
	}

	// Make executable
	if err := os.Chmod(tmpFile, 0755); err != nil {
		return fmt.Errorf("failed to make executable: %w", err)
	}

	// Get current executable path
	execPath, err := os.Executable()
	if err != nil {
		return fmt.Errorf("failed to get executable path: %w", err)
	}

	fmt.Printf("Installing to: %s\n", execPath)

	// Replace executable
	if err := replaceExecutable(tmpFile, execPath); err != nil {
		return fmt.Errorf("failed to replace executable: %w", err)
	}

	fmt.Printf("Successfully updated to %s\n", version)
	
	// Update global agents if not skipped
	if !flags.SkipGlobalAgentsUpdate {
		fmt.Println("\nUpdating global agents...")
		if err := runUpdateGlobalAgents(flags); err != nil {
			fmt.Fprintf(os.Stderr, "Warning: Failed to update global agents: %v\n", err)
		}
	}
	
	return nil
}

func downloadFile(url, dest string) error {
	resp, err := http.Get(url)
	if err != nil {
		return err
	}
	defer resp.Body.Close()

	if resp.StatusCode != http.StatusOK {
		return fmt.Errorf("download failed with status: %s", resp.Status)
	}

	out, err := os.Create(dest)
	if err != nil {
		return err
	}
	defer out.Close()

	_, err = io.Copy(out, resp.Body)
	return err
}

func replaceExecutable(src, dest string) error {
	// On Unix systems, we can't replace the running executable directly
	// We need to use a shell script to do the replacement after the process exits
	
	if runtime.GOOS == "windows" {
		// On Windows, we can move the file after a delay
		return os.Rename(src, dest)
	}

	// On Unix, create a shell script to do the replacement
	scriptPath := dest + ".update.sh"
	script := fmt.Sprintf(`#!/bin/bash
sleep 1
mv "%s" "%s"
rm "%s"
`, src, dest, scriptPath)

	if err := os.WriteFile(scriptPath, []byte(script), 0755); err != nil {
		return err
	}

	// Execute the script in background
	cmd := exec.Command("bash", scriptPath)
	cmd.Start()

	return nil
}
