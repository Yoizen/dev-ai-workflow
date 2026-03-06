package sync

import (
	"bufio"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"sort"
	"strings"
)

func (s *Sync) analyzeSkills() *SkillsReport {
	report := &SkillsReport{}

	typeConfig, ok := s.typesCfg.Types[s.projectType]
	if !ok {
		// Debug: tipo no encontrado
		return report
	}

	requiredSkills := typeConfig.Skills
	existingSkills := s.getExistingSkills()

	// Debug output
	if len(requiredSkills) > 0 {
		// Debug: skills requeridas
	}

	for _, req := range requiredSkills {
		if !s.skillExistsInProject(existingSkills, req) {
			info := s.getSkillInfo(req)
			report.Missing = append(report.Missing, info)
		}
	}

	return report
}

func (s *Sync) getExistingSkills() []string {
	skillsDir := filepath.Join(s.targetDir, "skills")
	var skills []string

	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		return skills
	}

	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), "_") && entry.Name() != "." {
			skills = append(skills, entry.Name())
			subSkills := s.getSubSkills(filepath.Join(skillsDir, entry.Name()))
			for _, sub := range subSkills {
				skills = append(skills, entry.Name()+"/"+sub)
			}
		}
	}

	return skills
}

func (s *Sync) listAvailableSourceSkills() []string {
	skillsDir := filepath.Join(s.repoRoot, "ywai", "skills")
	if !s.dirExists(skillsDir) {
		skillsDir = filepath.Join(s.repoRoot, "skills")
	}
	if !s.dirExists(skillsDir) {
		return nil
	}

	var skills []string
	entries, err := os.ReadDir(skillsDir)
	if err != nil {
		return nil
	}

	for _, entry := range entries {
		if !entry.IsDir() || strings.HasPrefix(entry.Name(), "_") {
			continue
		}

		rootSkillPath := filepath.Join(skillsDir, entry.Name(), "SKILL.md")
		if s.fileExists(rootSkillPath) {
			skills = append(skills, entry.Name())
		}

		for _, sub := range s.getSubSkills(filepath.Join(skillsDir, entry.Name())) {
			skills = append(skills, entry.Name()+"/"+sub)
		}
	}

	sort.Strings(skills)
	return skills
}

func (s *Sync) getSubSkills(dir string) []string {
	var subSkills []string

	entries, err := os.ReadDir(dir)
	if err != nil {
		return subSkills
	}

	for _, entry := range entries {
		if entry.IsDir() {
			skillPath := filepath.Join(dir, entry.Name(), "SKILL.md")
			if s.fileExists(skillPath) {
				subSkills = append(subSkills, entry.Name())
			}
		}
	}

	return subSkills
}

func (s *Sync) skillExistsInProject(existing []string, required string) bool {
	for _, skill := range existing {
		if skill == required {
			return true
		}
	}
	return false
}

func (s *Sync) getSkillInfo(skillName string) SkillInfo {
	srcPath := s.findSkillSource(skillName)
	if srcPath == "" {
		return SkillInfo{
			Name:   skillName,
			Status: "UNKNOWN",
		}
	}

	desc := s.extractSkillDescription(srcPath)
	deps := s.extractSkillDependencies(srcPath)

	return SkillInfo{
		Name:         skillName,
		Path:         srcPath,
		Status:       "NEW",
		Description:  desc,
		Dependencies: deps,
	}
}

func (s *Sync) extractSkillDescription(skillPath string) string {
	skillFile := filepath.Join(skillPath, "SKILL.md")
	data, err := os.ReadFile(skillFile)
	if err != nil {
		return ""
	}

	content := string(data)
	descRegex := regexp.MustCompile(`(?i)^description:\s*(.+)$`)
	descMatch := descRegex.FindStringSubmatch(content)
	if len(descMatch) > 1 {
		return strings.TrimSpace(descMatch[1])
	}

	lines := strings.Split(content, "\n")
	for _, line := range lines {
		if strings.HasPrefix(line, "# ") {
			return strings.TrimSpace(strings.TrimPrefix(line, "# "))
		}
	}

	return ""
}

func (s *Sync) extractSkillDependencies(skillPath string) []string {
	skillFile := filepath.Join(skillPath, "SKILL.md")
	file, err := os.Open(skillFile)
	if err != nil {
		return nil
	}
	defer file.Close()

	var deps []string
	inDepsSection := false

	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())

		if strings.HasPrefix(line, "dependencies:") {
			inDepsSection = true
			continue
		}

		if inDepsSection {
			if strings.HasPrefix(line, "- ") {
				dep := strings.TrimPrefix(line, "- ")
				dep = strings.TrimSpace(dep)
				if dep != "" {
					deps = append(deps, dep)
				}
			} else if line != "" && !strings.HasPrefix(line, " ") && !strings.HasPrefix(line, "\t") {
				break
			}
		}
	}

	return deps
}

func (s *Sync) resolveSkillDependencies(skillName string) []SkillInfo {
	depsMap := s.buildDependencyMap()
	visited := make(map[string]bool)
	var allDeps []string

	s.resolveDepsRecursive(skillName, depsMap, &allDeps, visited)

	var result []SkillInfo
	for _, dep := range allDeps {
		if dep == skillName {
			continue
		}
		info := s.getSkillInfo(dep)
		result = append(result, info)
	}

	return result
}

func (s *Sync) buildDependencyMap() map[string][]string {
	depsMap := make(map[string][]string)

	skillsDir := filepath.Join(s.repoRoot, "ywai", "skills")
	if !s.dirExists(skillsDir) {
		skillsDir = filepath.Join(s.repoRoot, "skills")
	}

	if !s.dirExists(skillsDir) {
		return depsMap
	}

	entries, _ := os.ReadDir(skillsDir)
	for _, entry := range entries {
		if entry.IsDir() && !strings.HasPrefix(entry.Name(), "_") {
			skillName := entry.Name()
			skillPath := filepath.Join(skillsDir, skillName)
			deps := s.extractSkillDependencies(skillPath)
			if len(deps) > 0 {
				depsMap[skillName] = deps
			}

			subSkills := s.getSubSkills(skillPath)
			for _, sub := range subSkills {
				fullName := skillName + "/" + sub
				subPath := filepath.Join(skillPath, sub)
				subDeps := s.extractSkillDependencies(subPath)
				if len(subDeps) > 0 {
					depsMap[fullName] = subDeps
				}
			}
		}
	}

	return depsMap
}

func (s *Sync) resolveDepsRecursive(skill string, depsMap map[string][]string, allDeps *[]string, visited map[string]bool) {
	if visited[skill] {
		return
	}
	visited[skill] = true

	*allDeps = append(*allDeps, skill)

	if deps, ok := depsMap[skill]; ok {
		for _, dep := range deps {
			s.resolveDepsRecursive(dep, depsMap, allDeps, visited)
		}
	}
}

func (s *Sync) ListInstallableSkills() error {
	missing, existing, available, err := s.GetInstallableSkills()
	if err != nil {
		return err
	}

	fmt.Printf("# Installable skills for repo: %s\n\n", s.targetDir)
	fmt.Printf("- Skills already present: %d\n", len(existing))
	fmt.Printf("- Skills available from YWAI source: %d\n", len(available))
	fmt.Printf("- Skills you can install now: %d\n\n", len(missing))

	if len(missing) == 0 {
		fmt.Println("✅ This repository already has every installable skill from the current YWAI source.")
		return nil
	}

	fmt.Println("| Skill | Description |")
	fmt.Println("|-------|-------------|")
	for _, skill := range missing {
		desc := strings.TrimSpace(skill.Description)
		if desc == "" {
			desc = "—"
		}
		fmt.Printf("| `%s` | %s |\n", skill.Name, desc)
	}

	fmt.Println("\nExamples:")
	for idx, skill := range missing {
		if idx >= 5 {
			break
		}
		fmt.Printf("  ywai --install-skill %s\n", skill.Name)
	}

	fmt.Println("\nTip:")
	fmt.Println("  After installing a skill, YWAI will run local skills setup and sync AGENTS.md metadata when possible.")
	return nil
}

func (s *Sync) GetInstallableSkills() ([]SkillInfo, []string, []string, error) {
	s.repoRoot = s.findRepoRoot()
	if s.repoRoot == "" {
		return nil, nil, nil, fmt.Errorf("cannot find ywai repository root")
	}

	available := s.listAvailableSourceSkills()
	existing := s.getExistingSkills()

	existingSet := make(map[string]bool, len(existing))
	for _, skill := range existing {
		existingSet[skill] = true
	}

	var missing []SkillInfo
	for _, skillName := range available {
		if existingSet[skillName] {
			continue
		}
		missing = append(missing, s.getSkillInfo(skillName))
	}

	return missing, existing, available, nil
}

func (s *Sync) copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}

		relPath, _ := filepath.Rel(src, path)
		destPath := filepath.Join(dst, relPath)

		if info.IsDir() {
			return os.MkdirAll(destPath, info.Mode())
		}

		data, err := os.ReadFile(path)
		if err != nil {
			return err
		}
		return os.WriteFile(destPath, data, info.Mode())
	})
}

func (s *Sync) installSkillDir(skillName, srcPath string) (string, error) {
	destPath := filepath.Join(s.targetDir, "skills", skillName)

	if s.flags.DryRun {
		return destPath, nil
	}

	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return destPath, err
	}

	if s.dirExists(destPath) {
		if !s.flags.Force {
			return destPath, nil
		}
		if err := os.RemoveAll(destPath); err != nil {
			return destPath, err
		}
	}

	if err := s.copyDir(srcPath, destPath); err != nil {
		return destPath, err
	}

	return destPath, nil
}

func (s *Sync) runLocalSkillsSetup() error {
	if s.flags.DryRun {
		s.logger.LogInfo("DRY RUN: Would run skills/setup.sh --all")
		return nil
	}

	script := filepath.Join(s.targetDir, "skills", "setup.sh")
	if !s.fileExists(script) {
		candidates := []string{
			filepath.Join(s.repoRoot, "ywai", "skills", "setup.sh"),
			filepath.Join(s.repoRoot, "skills", "setup.sh"),
		}
		for _, candidate := range candidates {
			if s.fileExists(candidate) {
				script = candidate
				break
			}
		}
	}
	if !s.fileExists(script) {
		return nil
	}

	cmd := exec.Command("bash", script, "--all")
	cmd.Dir = s.targetDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to run skills setup: %w: %s", err, string(output))
	}

	s.logger.LogSuccess("Configured local skills")
	return nil
}

func (s *Sync) syncSkillMetadata() error {
	if s.flags.DryRun {
		s.logger.LogInfo("DRY RUN: Would run skills/skill-sync/assets/sync.sh")
		return nil
	}

	script := filepath.Join(s.targetDir, "skills", "skill-sync", "assets", "sync.sh")
	if !s.fileExists(script) {
		candidates := []string{
			filepath.Join(s.repoRoot, "ywai", "skills", "skill-sync", "assets", "sync.sh"),
			filepath.Join(s.repoRoot, "skills", "skill-sync", "assets", "sync.sh"),
		}
		for _, candidate := range candidates {
			if s.fileExists(candidate) {
				script = candidate
				break
			}
		}
	}
	if !s.fileExists(script) {
		s.logger.LogWarning("skill-sync not installed in repo; AGENTS.md sync skipped")
		return nil
	}

	cmd := exec.Command("bash", script)
	cmd.Dir = s.targetDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to sync AGENTS.md skill metadata: %w: %s", err, string(output))
	}

	s.logger.LogSuccess("Synced AGENTS.md skill metadata")
	return nil
}

func (s *Sync) listSkillFiles(skillPath string) []SkillFile {
	var files []SkillFile

	err := filepath.Walk(skillPath, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		if info.IsDir() {
			return nil
		}

		relPath, _ := filepath.Rel(skillPath, path)
		if relPath == "" {
			return nil
		}

		files = append(files, SkillFile{
			Source:      path,
			Destination: relPath,
		})

		return nil
	})

	if err != nil {
		return nil
	}

	return files
}
