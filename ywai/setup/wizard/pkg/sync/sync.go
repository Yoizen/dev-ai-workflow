package sync

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
)

type Sync struct {
	flags       *SyncFlags
	logger      *ui.Logger
	targetDir   string
	projectType string
	typesCfg    *TypesConfig
	repoRoot    string
}

func New(flags *SyncFlags, logger *ui.Logger, targetDir string) *Sync {
	return &Sync{
		flags:     flags,
		logger:    logger,
		targetDir: targetDir,
	}
}

func (s *Sync) Run() error {
	s.repoRoot = s.findRepoRoot()
	s.projectType = s.resolveProjectType()
	s.typesCfg = s.loadTypesConfig()

	skillsReport := s.analyzeSkills()
	agentsChanges := s.analyzeAgentsMD()
	reviewChanges := s.analyzeReviewMD()

	report := s.generateSyncReport(skillsReport, agentsChanges, reviewChanges)

	fmt.Println(report)
	return nil
}

func (s *Sync) InstallSingleSkill(skillName string) error {
	return s.InstallSkills([]string{skillName})
}

func (s *Sync) InstallSkills(skillNames []string) error {
	s.repoRoot = s.findRepoRoot()
	if s.repoRoot == "" {
		return fmt.Errorf("cannot find ywai repository root")
	}

	if len(skillNames) == 0 {
		return fmt.Errorf("no skills selected for installation")
	}

	normalized := make([]string, 0, len(skillNames))
	seenRequested := map[string]bool{}
	for _, skillName := range skillNames {
		skillName = filepath.Clean(strings.TrimSpace(skillName))
		if skillName == "." || skillName == "" || seenRequested[skillName] {
			continue
		}
		seenRequested[skillName] = true
		normalized = append(normalized, skillName)
	}
	if len(normalized) == 0 {
		return fmt.Errorf("no valid skills selected for installation")
	}

	planMap := map[string]SkillInfo{}
	existingSkills := s.getExistingSkills()

	for _, skillName := range normalized {
		srcPath := s.findSkillSource(skillName)
		if srcPath == "" {
			return fmt.Errorf("skill not found: %s", skillName)
		}
		planMap[skillName] = s.getSkillInfo(skillName)

		for _, dep := range s.resolveSkillDependencies(skillName) {
			planMap[dep.Name] = dep
		}
	}

	needSkillSync := !s.skillExistsInProject(existingSkills, "skill-sync")
	if needSkillSync {
		requestedSkillSync := false
		for _, name := range normalized {
			if name == "skill-sync" {
				requestedSkillSync = true
				break
			}
		}
		if !requestedSkillSync {
			planMap["skill-sync"] = s.getSkillInfo("skill-sync")
		}
	}

	orderedSkills := make([]string, 0, len(planMap))
	for name := range planMap {
		orderedSkills = append(orderedSkills, name)
	}
	sort.Strings(orderedSkills)

	if len(normalized) == 1 {
		srcPath := s.findSkillSource(normalized[0])
		var deps []SkillInfo
		for _, name := range orderedSkills {
			if name != normalized[0] {
				deps = append(deps, planMap[name])
			}
		}
		report := s.generateInstallReport(normalized[0], srcPath, deps)
		fmt.Println(report)
	} else {
		fmt.Printf("# YWAI: Install Skills\n\n")
		fmt.Printf("Requested skills: %s\n", strings.Join(normalized, ", "))
		fmt.Printf("Skills to install (including dependencies): %d\n\n", len(orderedSkills))
		for _, name := range orderedSkills {
			fmt.Printf("- %s\n", name)
		}
		fmt.Println("")
	}

	s.logger.LogStep(fmt.Sprintf("Installing skills: %s", strings.Join(normalized, ", ")))

	installedCount := 0
	for _, name := range orderedSkills {
		info := planMap[name]
		if info.Path == "" {
			return fmt.Errorf("source path not found for skill: %s", name)
		}

		destPath := filepath.Join(s.targetDir, "skills", name)
		if s.dirExists(destPath) && !s.flags.Force {
			s.logger.LogInfo(fmt.Sprintf("Skill already present, skipping: %s", name))
			continue
		}

		if s.flags.DryRun {
			s.logger.LogInfo(fmt.Sprintf("DRY RUN: Would install skill %s -> %s", name, destPath))
			installedCount++
			continue
		}

		if _, err := s.installSkillDir(name, info.Path); err != nil {
			return fmt.Errorf("failed to install skill %s: %w", name, err)
		}

		s.logger.LogSuccess(fmt.Sprintf("Installed skill: %s", name))
		installedCount++
	}

	if installedCount == 0 {
		s.logger.LogInfo("No new skills were installed")
	} else {
		if s.flags.DryRun {
			s.logger.LogSuccess(fmt.Sprintf("Planned %d skill(s)", installedCount))
		} else {
			s.logger.LogSuccess(fmt.Sprintf("Installed %d skill(s)", installedCount))
		}
	}

	if err := s.runLocalSkillsSetup(); err != nil {
		s.logger.LogWarning(err.Error())
	}

	if err := s.syncSkillMetadata(); err != nil {
		s.logger.LogWarning(err.Error())
	}

	fmt.Println("")
	fmt.Println("📌 Prompt for LLM / manual follow-up:")
	fmt.Println("   \"Review the newly installed skills in ./skills, confirm AGENTS.md auto-invoke")
	fmt.Println("    sections were updated correctly by skill-sync, and adjust project-specific")
	fmt.Println("    documentation if any custom skill guidance is still missing.\"")
	return nil
}

func (s *Sync) resolveProjectType() string {
	if s.flags.ProjectType != "" {
		return s.flags.ProjectType
	}
	return s.inferProjectType()
}

func (s *Sync) inferProjectType() string {
	if s.fileExists(filepath.Join(s.targetDir, "angular.json")) {
		if s.fileExists(filepath.Join(s.targetDir, "nest-cli.json")) {
			return "nest-angular"
		}
		return "nest-angular"
	}

	if s.fileExists(filepath.Join(s.targetDir, "package.json")) {
		pkg := s.readPackageJSON()
		if s.hasDeps(pkg, "@nestjs/core") && s.hasDeps(pkg, "react") {
			return "nest-react"
		}
		if s.hasDeps(pkg, "@nestjs/core") {
			return "nest"
		}
	}

	if s.hasFiles("*.csproj") || s.hasFiles("*.sln") {
		return "dotnet"
	}

	if s.fileExists(filepath.Join(s.targetDir, "requirements.txt")) ||
		s.fileExists(filepath.Join(s.targetDir, "pyproject.toml")) {
		return "python"
	}

	if s.fileExists(filepath.Join(s.targetDir, "Dockerfile")) ||
		s.fileExists(filepath.Join(s.targetDir, "helm")) ||
		s.fileExists(filepath.Join(s.targetDir, ".github", "workflows")) {
		return "devops"
	}

	return "generic"
}

func (s *Sync) loadTypesConfig() *TypesConfig {
	typesPath := s.findTypesConfig()
	if typesPath == "" {
		return s.defaultTypesConfig()
	}

	data, err := os.ReadFile(typesPath)
	if err != nil {
		return s.defaultTypesConfig()
	}

	var cfg TypesConfig
	if err := json.Unmarshal(data, &cfg); err != nil {
		return s.defaultTypesConfig()
	}

	return &cfg
}

func (s *Sync) findTypesConfig() string {
	candidates := []string{
		filepath.Join(s.targetDir, "ywai", "types", "types.json"),
		filepath.Join(s.targetDir, "ywai", "setup", "types", "types.json"),
	}

	if s.repoRoot != "" {
		candidates = append(candidates,
			filepath.Join(s.repoRoot, "ywai", "types", "types.json"),
			filepath.Join(s.repoRoot, "ywai", "setup", "types", "types.json"),
		)
	}

	for _, path := range candidates {
		if s.fileExists(path) {
			return path
		}
	}

	return ""
}

func (s *Sync) defaultTypesConfig() *TypesConfig {
	return &TypesConfig{
		Types: map[string]ProjectType{
			"generic": {Description: "Generic project"},
			"nest":    {Description: "NestJS backend"},
		},
		Default: "generic",
	}
}

func (s *Sync) findRepoRoot() string {
	tryFindRoot := func(start string) string {
		dir := start
		for i := 0; i < 6; i++ {
			if s.dirExists(filepath.Join(dir, "ywai")) {
				return dir
			}
			if s.fileExists(filepath.Join(dir, "ywai", "types", "types.json")) {
				return dir
			}
			parent := filepath.Dir(dir)
			if parent == dir {
				break
			}
			dir = parent
		}
		return ""
	}

	// First try from target directory (current directory)
	if root := tryFindRoot(s.targetDir); root != "" {
		return root
	}

	// Also try from current working directory
	if wd, err := os.Getwd(); err == nil {
		if root := tryFindRoot(wd); root != "" {
			return root
		}
	}

	// Also try from executable path as fallback
	execPath, _ := os.Executable()
	if root := tryFindRoot(filepath.Dir(execPath)); root != "" {
		return root
	}

	// Check for environment variable
	if repoRoot := os.Getenv("YWAI_REPO_ROOT"); repoRoot != "" {
		if s.fileExists(filepath.Join(repoRoot, "ywai", "types", "types.json")) {
			return repoRoot
		}
	}

	// Standard local install mirror
	if home, err := os.UserHomeDir(); err == nil {
		repoRoot := filepath.Join(home, ".local", "share", "yoizen", "dev-ai-workflow")
		if s.fileExists(filepath.Join(repoRoot, "ywai", "types", "types.json")) {
			return repoRoot
		}
	}

	return ""
}

func (s *Sync) findSkillSource(skillName string) string {
	candidates := []string{
		filepath.Join(s.targetDir, "ywai", "skills", skillName),
		filepath.Join(s.targetDir, "skills", skillName),
	}

	if s.repoRoot != "" {
		candidates = append(candidates,
			filepath.Join(s.repoRoot, "ywai", "skills", skillName),
			filepath.Join(s.repoRoot, "skills", skillName),
		)
	}

	for _, path := range candidates {
		if s.dirExists(path) {
			return path
		}
	}

	return ""
}

func (s *Sync) fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func (s *Sync) dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func (s *Sync) hasFiles(pattern string) bool {
	matches, _ := filepath.Glob(filepath.Join(s.targetDir, pattern))
	return len(matches) > 0
}

func (s *Sync) readPackageJSON() map[string]interface{} {
	path := filepath.Join(s.targetDir, "package.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil
	}

	var pkg map[string]interface{}
	if err := json.Unmarshal(data, &pkg); err != nil {
		return nil
	}

	return pkg
}

func (s *Sync) hasDeps(pkg map[string]interface{}, dep string) bool {
	if pkg == nil {
		return false
	}

	if deps, ok := pkg["dependencies"].(map[string]interface{}); ok {
		if _, exists := deps[dep]; exists {
			return true
		}
	}

	if deps, ok := pkg["devDependencies"].(map[string]interface{}); ok {
		if _, exists := deps[dep]; exists {
			return true
		}
	}

	return false
}

func (s *Sync) readFile(path string) string {
	data, err := os.ReadFile(path)
	if err != nil {
		return ""
	}
	return string(data)
}
