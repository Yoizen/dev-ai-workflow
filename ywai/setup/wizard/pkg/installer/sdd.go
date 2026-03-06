package installer

import (
	"fmt"
	"os"
	"path/filepath"
)

func (i *Installer) installSDD() error {
	if i.flags.SkipSDD {
		return nil
	}

	i.logger.LogStep("Installing SDD Orchestrator...")

	skillsTarget := i.getSkillsDir()
	if err := i.ensureDir(skillsTarget); err != nil {
		return err
	}

	repoRoot := i.getRepoRoot()
	if repoRoot == "" {
		repoRoot = i.getGADir()
	}

	sourceDir := i.findSkillsSource(repoRoot)
	if sourceDir == "" {
		i.logger.LogWarning("No skills directory found, skipping SDD installation")
		return nil
	}

	if i.flags.DryRun {
		i.logger.Log("DRY RUN: Would copy SDD skills from " + sourceDir)
		return nil
	}

	copied, replaced, err := i.copySDSSkills(sourceDir, skillsTarget)
	if err != nil {
		return err
	}

	if copied > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Installed %d SDD skills", copied))
	} else if replaced > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Updated %d SDD skills", replaced))
	} else {
		i.logger.LogInfo("SDD skills already up to date")
	}

	if err := i.copySetupScript(sourceDir, skillsTarget); err != nil {
		i.logger.LogWarning("Failed to copy setup script")
	}

	if i.flags.InstallGlobal {
		if err := i.installGlobalSkills(sourceDir); err != nil {
			i.logger.LogWarning("Failed to install global skills")
		}
	}

	i.logger.LogSuccess("SDD Orchestrator installed")
	return nil
}

func (i *Installer) findSkillsSource(repoRoot string) string {
	locations := []string{
		filepath.Join(i.getRepoRoot(), "ywai", "skills"),
		filepath.Join(i.getYWAIDir(), "skills"),
		filepath.Join(i.getGADir(), "ywai", "skills"),
		filepath.Join(i.getGADir(), "skills"),
		filepath.Join(i.getRepoRoot(), "skills"),
		filepath.Join(repoRoot, "skills"),
	}

	for _, location := range locations {
		if i.dirExists(location) {
			return location
		}
	}

	return ""
}

func (i *Installer) copySDSSkills(sourceDir, targetDir string) (copied, replaced int, err error) {
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		return 0, 0, err
	}

	for _, entry := range entries {
		if !entry.IsDir() || !isSDDSkill(entry.Name()) {
			continue
		}

		srcPath := filepath.Join(sourceDir, entry.Name())
		destPath := filepath.Join(targetDir, entry.Name())

		if i.dirExists(destPath) {
			if i.flags.Force {
				if err := os.RemoveAll(destPath); err != nil {
					return 0, 0, err
				}
				if err := i.copyDir(srcPath, destPath); err != nil {
					return 0, 0, err
				}
				replaced++
			}
		} else {
			if err := i.copyDir(srcPath, destPath); err != nil {
				return 0, 0, err
			}
			copied++
		}
	}

	return copied, replaced, nil
}

func (i *Installer) copySetupScript(sourceDir, targetDir string) error {
	setupSrc := filepath.Join(sourceDir, "setup.sh")
	setupDst := filepath.Join(targetDir, "setup.sh")

	if !i.fileExists(setupSrc) || i.fileExists(setupDst) {
		return nil
	}

	if err := i.copyFile(setupSrc, setupDst); err != nil {
		return err
	}

	return os.Chmod(setupDst, 0755)
}

func (i *Installer) installGlobalSkills(sourceDir string) error {
	i.logger.LogInfo("Installing global skills...")

	home, _ := os.UserHomeDir()
	globalSkillsDir := filepath.Join(home, ".local", "share", "ga", "skills")
	if err := i.ensureDir(globalSkillsDir); err != nil {
		return err
	}

	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		return err
	}

	installed := 0
	for _, entry := range entries {
		if !entry.IsDir() {
			continue
		}

		srcPath := filepath.Join(sourceDir, entry.Name())
		destPath := filepath.Join(globalSkillsDir, entry.Name())

		if i.dirExists(destPath) && !i.flags.Force {
			continue
		}

		if i.dirExists(destPath) {
			if err := os.RemoveAll(destPath); err != nil {
				return err
			}
		}

		if err := i.copyDir(srcPath, destPath); err != nil {
			return err
		}
		installed++
	}

	if installed > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Installed %d global skills", installed))
	}

	if err := i.linkOpenCodeGlobalSkills(sourceDir); err != nil {
		i.logger.LogWarning("Failed to link OpenCode global skills")
	}

	return nil
}

func (i *Installer) linkOpenCodeGlobalSkills(sourceDir string) error {
	home, _ := os.UserHomeDir()
	xdgConfig := os.Getenv("XDG_CONFIG_HOME")
	if xdgConfig == "" {
		xdgConfig = filepath.Join(home, ".config")
	}
	opencodeDir := filepath.Join(xdgConfig, "opencode")
	if err := i.ensureDir(opencodeDir); err != nil {
		return err
	}

	target := filepath.Join(opencodeDir, "skills")
	if _, err := os.Lstat(target); err == nil {
		if err := os.RemoveAll(target); err != nil {
			return err
		}
	}
	if err := os.Symlink(sourceDir, target); err != nil {
		// Fallback to copy if symlink is not allowed
		return i.copyDir(sourceDir, target)
	}
	return nil
}

func isSDDSkill(name string) bool {
	return len(name) > 4 && name[:4] == "sdd-"
}
