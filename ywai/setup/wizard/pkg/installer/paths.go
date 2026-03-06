package installer

import (
	"fmt"
	"path/filepath"
	"strings"
	"time"
)

func normalizeYWAIRelativePath(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	path = filepath.ToSlash(path)
	path = strings.TrimPrefix(path, "./")
	path = strings.TrimPrefix(path, "/")
	path = strings.TrimPrefix(path, "ywai/")
	return path
}

func uniqueCleanPaths(paths []string) []string {
	seen := make(map[string]struct{}, len(paths))
	unique := make([]string, 0, len(paths))
	for _, path := range paths {
		path = strings.TrimSpace(path)
		if path == "" {
			continue
		}
		clean := filepath.Clean(path)
		if _, ok := seen[clean]; ok {
			continue
		}
		seen[clean] = struct{}{}
		unique = append(unique, clean)
	}
	return unique
}

func (i *Installer) backupFile(path string) error {
	if !i.fileExists(path) {
		return nil
	}

	timestamp := time.Now().Format("20060102150405")
	backupPath := fmt.Sprintf("%s.backup.%s", path, timestamp)

	if err := i.copyFile(path, backupPath); err != nil {
		return err
	}

	i.logger.LogInfo(fmt.Sprintf("Backed up %s -> %s", filepath.Base(path), filepath.Base(backupPath)))
	return nil
}

func (i *Installer) ywaiRoots(includeTarget bool) []string {
	roots := make([]string, 0, 3)
	if repoRoot := strings.TrimSpace(i.getRepoRoot()); repoRoot != "" {
		roots = append(roots, filepath.Join(repoRoot, "ywai"))
	}
	roots = append(roots, filepath.Join(i.getGADir(), "ywai"))
	if includeTarget {
		roots = append(roots, filepath.Join(i.targetDir, "ywai"))
	}
	return uniqueCleanPaths(roots)
}

func (i *Installer) ywaiCandidates(includeTarget bool, relPaths ...string) []string {
	roots := i.ywaiRoots(includeTarget)
	candidates := make([]string, 0, len(roots)*len(relPaths))
	for _, root := range roots {
		for _, relPath := range relPaths {
			relPath = normalizeYWAIRelativePath(relPath)
			if relPath == "" {
				continue
			}
			candidates = append(candidates, filepath.Join(root, filepath.FromSlash(relPath)))
		}
	}
	return uniqueCleanPaths(candidates)
}

func (i *Installer) firstExistingFile(candidates ...string) string {
	for _, candidate := range candidates {
		if i.fileExists(candidate) {
			return candidate
		}
	}
	return ""
}

func (i *Installer) firstExistingDir(candidates ...string) string {
	for _, candidate := range candidates {
		if i.dirExists(candidate) {
			return candidate
		}
	}
	return ""
}
