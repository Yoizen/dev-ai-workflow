package installer

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

var baseSkillsForAllTypes = []string{
	"git-commit",
	"skill-creator",
	"skill-sync",
}

func (i *Installer) configureProject() error {
	i.logger.LogStep("Configuring project...")

	if err := i.applyProjectType(); err != nil {
		return err
	}

	if err := i.installTypeSkills(); err != nil {
		i.logger.LogWarning("Failed to install type skills")
	}

	if err := i.copySharedSkills(); err != nil {
		i.logger.LogWarning("Failed to copy shared skills")
	}

	if err := i.runLocalSkillsSetup(); err != nil {
		i.logger.LogWarning("Failed to run local skills setup")
	}

	if err := i.copyCommands(); err != nil {
		i.logger.LogWarning("Failed to copy commands")
	}

	if err := i.updateGitignore(); err != nil {
		return err
	}

	if err := i.setupVSCodeSettings(); err != nil {
		return err
	}

	if err := i.initializeGA(); err != nil {
		i.logger.LogWarning("Failed to initialize GA")
	}

	i.logger.LogSuccess("Project configured")
	return nil
}

func (i *Installer) applyProjectType() error {
	types := i.loadTypesConfig()

	pt := i.projectType
	if pt == "" {
		pt = i.inferProjectType()
		if pt == "" {
			pt = types.Default
		}
		i.logger.LogInfo(fmt.Sprintf("Inferred project type: %s", pt))
	}

	_, ok := types.Types[pt]
	if !ok {
		i.logger.LogWarning(fmt.Sprintf("Unknown project type '%s', falling back to default '%s'", pt, types.Default))
		pt = types.Default
	}
	i.projectType = pt

	i.logger.LogInfo(fmt.Sprintf("Applying project type: %s", pt))

	typeConfig := types.Types[pt]

	docs := []struct {
		relPath  string
		destName string
	}{
		{typeConfig.AgentsMD, "AGENTS.md"},
		{typeConfig.ReviewMD, "REVIEW.md"},
	}

	for _, doc := range docs {
		sourcePath := i.firstExistingFile(i.ywaiCandidates(false, i.typeDocCandidatePaths(pt, doc.destName, doc.relPath)...)...)
		destPath := filepath.Join(i.targetDir, doc.destName)

		if sourcePath == "" {
			i.logger.LogWarning(fmt.Sprintf("Template not found for %s (%s)", doc.destName, pt))
			continue
		}

		if !i.fileExists(destPath) || i.flags.Force {
			if i.fileExists(sourcePath) {
				if err := i.copyFile(sourcePath, destPath); err != nil {
					return err
				}
				i.logger.LogSuccess(fmt.Sprintf("Created %s", doc.destName))
			}
		} else {
			i.logger.LogInfo(fmt.Sprintf("%s already exists, skipping", doc.destName))
		}
	}

	if err := i.applyLefthookConfig(typeConfig.LefthookYML); err != nil {
		i.logger.LogWarning("Failed to apply lefthook.yml")
	}
	if err := i.appendAgentsTemplates(types.BaseConfig.AppendAgentsTemplates); err != nil {
		i.logger.LogWarning("Failed to append AGENTS templates")
	}

	i.logger.LogSuccess(fmt.Sprintf("Project type '%s' applied", pt))
	return nil
}

func (i *Installer) copySharedSkills() error {
	types := i.loadTypesConfig()
	repoRoot := i.getRepoRoot()
	skillsSrc := i.findSkillsSource(repoRoot)
	skillsTgt := i.getSkillsDir()

	if skillsSrc == "" {
		i.logger.LogInfo("No shared skills directory found")
		return nil
	}

	if err := i.ensureDir(skillsTgt); err != nil {
		return err
	}

	if types.BaseConfig.CopySharedSkills {
		copiedAll, err := i.copySkillEntries(skillsSrc, skillsTgt)
		if err != nil {
			return err
		}
		if copiedAll > 0 {
			i.logger.LogSuccess(fmt.Sprintf("Copied %d shared skill asset(s)", copiedAll))
		}
	}

	sharedSrc := filepath.Join(skillsSrc, "_shared")
	sharedDst := filepath.Join(skillsTgt, "_shared")
	if !i.dirExists(sharedSrc) {
		return nil
	}

	if err := i.ensureDir(sharedDst); err != nil {
		return err
	}

	copiedShared, err := i.copySkillEntries(sharedSrc, sharedDst)
	if err != nil {
		return err
	}
	if copiedShared > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Copied %d skills/_shared asset(s)", copiedShared))
	}

	return nil
}

func (i *Installer) installTypeSkills() error {
	types := i.loadTypesConfig()
	pt := i.projectType
	if pt == "" {
		pt = types.Default
	}

	typeConfig, ok := types.Types[pt]
	if !ok {
		return nil
	}
	typeSkills := uniqueStrings(append([]string{}, typeConfig.Skills...))
	typeSkills = uniqueStrings(append(baseSkillsForAllTypes, typeSkills...))
	if len(typeSkills) == 0 {
		return nil
	}

	repoRoot := i.getRepoRoot()
	skillsSrc := i.findSkillsSource(repoRoot)
	skillsTgt := i.getSkillsDir()
	if skillsSrc == "" {
		return nil
	}

	if err := i.ensureDir(skillsTgt); err != nil {
		return err
	}

	installed := 0
	missing := make([]string, 0)
	for _, skill := range typeSkills {
		srcPath := filepath.Join(skillsSrc, skill)
		destPath := filepath.Join(skillsTgt, skill)

		if !i.dirExists(srcPath) {
			missing = append(missing, skill)
			continue
		}
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
		i.logger.LogSuccess(fmt.Sprintf("Installed %d type skills for %s", installed, pt))
	}
	if len(missing) > 0 {
		i.logger.LogWarning(fmt.Sprintf("Missing skill directories in source (%s): %s", skillsSrc, strings.Join(missing, ", ")))
	}
	return nil
}

func uniqueStrings(input []string) []string {
	seen := make(map[string]struct{})
	result := make([]string, 0, len(input))
	for _, value := range input {
		key := strings.TrimSpace(value)
		if key == "" {
			continue
		}
		if _, ok := seen[key]; ok {
			continue
		}
		seen[key] = struct{}{}
		result = append(result, key)
	}
	return result
}

func (i *Installer) copySkillEntries(sourceDir, targetDir string) (int, error) {
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		return 0, err
	}

	copied := 0
	for _, entry := range entries {
		name := entry.Name()
		srcPath := filepath.Join(sourceDir, name)
		destPath := filepath.Join(targetDir, name)

		if i.fileExists(destPath) || i.dirExists(destPath) {
			if !i.flags.Force {
				continue
			}
			if err := os.RemoveAll(destPath); err != nil {
				return copied, err
			}
		}

		if entry.IsDir() {
			if err := i.copyDir(srcPath, destPath); err != nil {
				return copied, err
			}
		} else {
			if err := i.copyFile(srcPath, destPath); err != nil {
				return copied, err
			}
		}

		copied++
	}

	return copied, nil
}

func (i *Installer) resolveLocalSkillsSetupScript() string {
	candidates := []string{
		filepath.Join(i.getSkillsDir(), "setup.sh"),
	}

	if source := i.findSkillsSource(i.getRepoRoot()); source != "" {
		candidates = append(candidates, filepath.Join(source, "setup.sh"))
	}
	candidates = append(candidates,
		i.ywaiCandidates(false, "skills/setup.sh")...,
	)

	return i.firstExistingFile(uniqueCleanPaths(candidates)...)
}

func (i *Installer) runLocalSkillsSetup() error {
	script := i.resolveLocalSkillsSetupScript()
	if script == "" {
		return nil
	}

	if i.flags.DryRun {
		i.logger.LogInfo("DRY RUN: Would run local skills setup")
		return nil
	}

	cmd := exec.Command("bash", script, "--all")
	cmd.Dir = i.targetDir
	cmd.Env = append(os.Environ(),
		fmt.Sprintf("YWAI_PROJECT_TYPE=%s", i.getEffectiveProjectType()),
	)
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to run local skills setup: %w: %s", err, string(output))
	}

	i.logger.LogSuccess("Configured local skills")
	return nil
}

func normalizeTypesRelativePath(path string) string {
	path = strings.TrimSpace(path)
	if path == "" {
		return ""
	}
	path = strings.TrimPrefix(path, "./")
	path = strings.TrimPrefix(path, "ywai/")
	path = strings.TrimPrefix(path, "setup/")
	return path
}

func withSetupCompatFallback(path string) []string {
	path = normalizeYWAIRelativePath(path)
	if path == "" {
		return nil
	}

	paths := []string{path}
	if !strings.HasPrefix(path, "setup/") {
		paths = append(paths, filepath.Join("setup", path))
	}
	return paths
}

func (i *Installer) typeDocCandidatePaths(projectType, docName, configuredRelPath string) []string {
	candidateRelPaths := make([]string, 0, 6)

	normalized := normalizeTypesRelativePath(configuredRelPath)
	if normalized != "" {
		candidateRelPaths = append(candidateRelPaths, withSetupCompatFallback(normalized)...)
	}

	candidateRelPaths = append(candidateRelPaths,
		filepath.Join("types", projectType, docName),
		filepath.Join("setup", "types", projectType, docName),
	)

	return uniqueCleanPaths(candidateRelPaths)
}

func (i *Installer) updateGitignore() error {
	gitignorePath := filepath.Join(i.targetDir, ".gitignore")

	if !i.fileExists(gitignorePath) {
		if err := os.WriteFile(gitignorePath, []byte(""), 0644); err != nil {
			return err
		}
	}

	patterns := []string{
		"# Dependencies", "node_modules/", "",
		"# Environment", ".env", ".env.local", ".env.*.local", "",
		"# AI Assistants", "CLAUDE.md", "CURSOR.md", "GEMINI.md", ".cursorrules", ".ga", ".gga", ".claude/", "",
		"# OpenCode", ".opencode/plugins/**/node_modules/", ".opencode/plugins/**/dist/", ".opencode/**/cache/", "",
		"# System", ".DS_Store", "Thumbs.db", "",
		"# Logs", "*.log", "logs/", "",
		"# IDE", ".idea/", "*.iml", ".vscode/", "",
	}

	content, _ := os.ReadFile(gitignorePath)
	existing := string(content)

	for _, pattern := range patterns {
		if pattern == "" {
			continue
		}
		if !strings.Contains(existing, pattern) {
			existing += pattern + "\n"
		}
	}

	if err := os.WriteFile(gitignorePath, []byte(existing), 0644); err != nil {
		return err
	}

	i.logger.LogSuccess("Updated .gitignore")
	return nil
}

func (i *Installer) setupVSCodeSettings() error {
	vscodeDir := filepath.Join(i.targetDir, ".vscode")
	settingsPath := filepath.Join(vscodeDir, "settings.json")

	if i.fileExists(settingsPath) && !i.flags.Force {
		return nil
	}

	if err := i.ensureDir(vscodeDir); err != nil {
		return err
	}

	settings := `{
    "github.copilot.chat.useAgentsMdFile": true
}
`

	if err := os.WriteFile(settingsPath, []byte(settings), 0644); err != nil {
		return err
	}

	i.logger.LogSuccess("Created VS Code settings")
	return nil
}

func (i *Installer) initializeGA() error {
	if i.flags.SkipGA {
		i.logger.LogInfo("GA initialization skipped by --skip-ga")
		return nil
	}
	if !i.flags.All && !i.flags.InstallGA {
		i.logger.LogInfo("GA initialization skipped (GA install not requested)")
		return nil
	}

	types := i.loadTypesConfig()
	if !types.BaseConfig.InitGA {
		i.logger.LogInfo("GA initialization disabled by base_config.init_ga")
		return nil
	}

	if !i.commandExists("ga") {
		i.logger.LogInfo("GA command not available, skipping initialization")
		return nil
	}

	gaConfigPath := filepath.Join(i.targetDir, ".ga")
	gaConfigExists := i.fileExists(gaConfigPath)

	if i.flags.DryRun {
		if !gaConfigExists || i.flags.Force {
			i.logger.Log("DRY RUN: Would initialize GA in project")
		}
		i.logger.Log("DRY RUN: Would configure .ga template/provider")
		i.logger.Log("DRY RUN: Would install GA hooks")
		return nil
	}

	if !gaConfigExists || i.flags.Force {
		if err := i.runCommand("ga", "init"); err != nil {
			return fmt.Errorf("failed to initialize GA: %w", err)
		}
		i.logger.LogSuccess("GA initialized in project")
	} else {
		i.logger.LogInfo("GA already initialized in project")
	}

	if err := i.applyGAProjectTemplate(gaConfigPath); err != nil {
		return err
	}

	if err := i.applyGAProvider(gaConfigPath); err != nil {
		return err
	}

	if err := i.runCommand("ga", "install"); err != nil {
		return fmt.Errorf("failed to install GA hooks: %w", err)
	}
	i.logger.LogSuccess("GA hooks installed")

	return nil
}

func (i *Installer) resolveGATemplatePath() string {
	candidates := make([]string, 0, 5)
	candidates = append(candidates,
		i.ywaiCandidates(false, "ga/.ga.opencode-template")...,
	)
	if repoRoot := i.getRepoRoot(); repoRoot != "" {
		candidates = append(candidates, filepath.Join(repoRoot, "ywai", "ga", ".ga.opencode-template"))
	}
	candidates = append(candidates, filepath.Join(i.getGADir(), ".ga.opencode-template"))
	return i.firstExistingFile(uniqueCleanPaths(candidates)...)
}

func (i *Installer) applyGAProjectTemplate(gaConfigPath string) error {
	templatePath := i.resolveGATemplatePath()
	if templatePath == "" || !i.fileExists(gaConfigPath) {
		return nil
	}

	if err := i.copyFile(templatePath, gaConfigPath); err != nil {
		return fmt.Errorf("failed to apply GA template: %w", err)
	}
	i.logger.LogSuccess("Applied OpenCode template to .ga")
	return nil
}

func (i *Installer) applyGAProvider(gaConfigPath string) error {
	provider := strings.TrimSpace(i.provider)
	if provider == "" || strings.EqualFold(provider, "opencode") {
		return nil
	}
	if !i.fileExists(gaConfigPath) {
		return nil
	}

	content, err := os.ReadFile(gaConfigPath)
	if err != nil {
		return err
	}

	lines := strings.Split(string(content), "\n")
	replaced := false
	for idx, line := range lines {
		trimmed := strings.TrimSpace(line)
		if strings.HasPrefix(trimmed, "PROVIDER=") {
			lines[idx] = fmt.Sprintf("PROVIDER=\"%s\"", provider)
			replaced = true
			break
		}
	}
	if !replaced {
		lines = append(lines, fmt.Sprintf("PROVIDER=\"%s\"", provider))
	}

	result := strings.Join(lines, "\n")
	if !strings.HasSuffix(result, "\n") {
		result += "\n"
	}
	if err := os.WriteFile(gaConfigPath, []byte(result), 0o644); err != nil {
		return err
	}

	i.logger.LogSuccess("Provider set in .ga")
	return nil
}

func (i *Installer) applyLefthookConfig(relPath string) error {
	candidateRelPaths := i.typeDocCandidatePaths(i.projectType, "lefthook.yml", relPath)
	source := i.firstExistingFile(i.ywaiCandidates(false, candidateRelPaths...)...)
	if source == "" {
		return nil
	}

	dest := filepath.Join(i.targetDir, "lefthook.yml")
	if i.fileExists(dest) && !i.flags.Force {
		return nil
	}
	if err := i.copyFile(source, dest); err != nil {
		return err
	}
	i.logger.LogSuccess("Applied lefthook.yml")

	if i.commandExists("lefthook") {
		if err := i.runCommand("lefthook", "install"); err != nil {
			i.logger.LogWarning("Failed to install lefthook hooks")
		} else {
			i.logger.LogSuccess("Lefthook hooks installed")
		}
	} else {
		i.logger.LogInfo("Lefthook not installed, skipping hooks")
	}

	return nil
}

func (i *Installer) appendAgentsTemplates(relTemplates []string) error {
	if len(relTemplates) == 0 {
		return nil
	}
	agentsPath := filepath.Join(i.targetDir, "AGENTS.md")
	if !i.fileExists(agentsPath) {
		return nil
	}

	content, err := os.ReadFile(agentsPath)
	if err != nil {
		return err
	}
	existing := string(content)

	for _, rel := range relTemplates {
		normalized := normalizeTypesRelativePath(rel)
		if normalized == "" {
			continue
		}

		candidateRelPaths := make([]string, 0, 6)
		candidateRelPaths = append(candidateRelPaths, withSetupCompatFallback(normalized)...)
		baseName := filepath.Base(normalized)
		candidateRelPaths = append(candidateRelPaths,
			filepath.Join("templates", baseName),
			filepath.Join("setup", "lib", "templates", baseName),
		)

		source := i.firstExistingFile(i.ywaiCandidates(false, candidateRelPaths...)...)
		if source == "" {
			continue
		}

		tplData, readErr := os.ReadFile(source)
		if readErr != nil {
			continue
		}

		text := strings.TrimSpace(string(tplData))
		if text == "" {
			continue
		}
		if strings.Contains(existing, text) {
			continue
		}
		existing += "\n\n" + text + "\n"
	}

	return os.WriteFile(agentsPath, []byte(existing), 0644)
}

func (i *Installer) copyCommands() error {
	types := i.loadTypesConfig()
	if !types.BaseConfig.CopyCommands {
		return nil
	}

	source := i.firstExistingDir(i.ywaiCandidates(false, "commands", "setup/commands")...)
	if source == "" {
		return nil
	}

	dest := filepath.Join(i.targetDir, "commands")
	sourceForSync := source

	if i.flags.DryRun {
		i.logger.LogInfo("DRY RUN: Would copy commands directory")
		i.logger.LogInfo("DRY RUN: Would sync commands to .github/prompts")
		i.logger.LogInfo("DRY RUN: Would sync commands to OpenCode commands")
		return nil
	}

	if i.dirExists(dest) {
		sourceForSync = dest
		if i.flags.Force {
			if err := os.RemoveAll(dest); err != nil {
				return err
			}
			if err := i.copyDir(source, dest); err != nil {
				return err
			}
			i.logger.LogSuccess("Copied commands directory")
		}
	} else {
		if err := i.copyDir(source, dest); err != nil {
			return err
		}
		i.logger.LogSuccess("Copied commands directory")
		sourceForSync = dest
	}

	if err := i.syncCommandsToGitHubPrompts(sourceForSync); err != nil {
		return err
	}

	if err := i.syncCommandsToOpenCode(sourceForSync); err != nil {
		return err
	}

	return nil
}

func (i *Installer) syncCommandsToGitHubPrompts(sourceDir string) error {
	githubPromptsDir := filepath.Join(i.targetDir, ".github", "prompts")
	copied, err := i.copyMarkdownFiles(sourceDir, githubPromptsDir)
	if err != nil {
		return err
	}
	if copied > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Synced %d command file(s) to .github/prompts", copied))
	}
	return nil
}

func (i *Installer) syncCommandsToOpenCode(sourceDir string) error {
	home, _ := os.UserHomeDir()
	xdgConfig := os.Getenv("XDG_CONFIG_HOME")
	if xdgConfig == "" {
		xdgConfig = filepath.Join(home, ".config")
	}
	opencodeCommandsDir := filepath.Join(xdgConfig, "opencode", "commands")

	copied, err := i.copyMarkdownFiles(sourceDir, opencodeCommandsDir)
	if err != nil {
		return err
	}
	if copied > 0 {
		i.logger.LogSuccess(fmt.Sprintf("Synced %d command file(s) to OpenCode commands", copied))
	}
	return nil
}

func (i *Installer) copyMarkdownFiles(sourceDir, destDir string) (int, error) {
	entries, err := os.ReadDir(sourceDir)
	if err != nil {
		return 0, err
	}

	if err := i.ensureDir(destDir); err != nil {
		return 0, err
	}

	copied := 0
	for _, entry := range entries {
		if entry.IsDir() {
			continue
		}
		name := entry.Name()
		if !strings.HasSuffix(strings.ToLower(name), ".md") {
			continue
		}

		src := filepath.Join(sourceDir, name)
		dst := filepath.Join(destDir, name)

		if i.fileExists(dst) {
			if !i.flags.Force {
				continue
			}
			if err := os.Remove(dst); err != nil {
				return copied, err
			}
		}

		if err := i.copyFile(src, dst); err != nil {
			return copied, err
		}
		copied++
	}

	return copied, nil
}

func (i *Installer) syncSkillMetadataTables() error {
	syncScript := filepath.Join(i.getSkillsDir(), "skill-sync", "assets", "sync.sh")
	if !i.fileExists(syncScript) {
		return nil
	}

	if i.flags.DryRun {
		i.logger.LogInfo("DRY RUN: Would sync AGENTS metadata tables")
		return nil
	}

	cmd := exec.Command("bash", syncScript)
	cmd.Dir = i.targetDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		return fmt.Errorf("failed to sync AGENTS metadata tables: %w: %s", err, string(output))
	}

	i.logger.LogSuccess("Synced AGENTS metadata tables")
	return nil
}

func (i *Installer) inferProjectType() string {
	packageJsonPath := filepath.Join(i.targetDir, "package.json")
	if i.fileExists(packageJsonPath) {
		return i.inferFromPackageJson(packageJsonPath)
	}

	pyprojectPath := filepath.Join(i.targetDir, "pyproject.toml")
	if i.fileExists(pyprojectPath) {
		return "python"
	}

	csprojFiles, _ := filepath.Glob(filepath.Join(i.targetDir, "*.csproj"))
	if len(csprojFiles) > 0 {
		return "dotnet"
	}

	dockerfile := filepath.Join(i.targetDir, "Dockerfile")
	if i.fileExists(dockerfile) {
		return i.inferFromDockerfile(dockerfile)
	}

	return "generic"
}

func (i *Installer) inferFromPackageJson(packageJsonPath string) string {
	data, err := os.ReadFile(packageJsonPath)
	if err != nil {
		return "generic"
	}

	content := string(data)
	if strings.Contains(content, "@nestjs/core") || strings.Contains(content, "nestjs") {
		if strings.Contains(content, "@angular") || strings.Contains(content, "angular") {
			return "nest-angular"
		}
		if strings.Contains(content, "react") || strings.Contains(content, "@react") {
			return "nest-react"
		}
		return "nest"
	}

	return "generic"
}

func (i *Installer) inferFromDockerfile(dockerfile string) string {
	data, err := os.ReadFile(dockerfile)
	if err != nil {
		return "generic"
	}

	content := string(data)
	if strings.Contains(content, "node") || strings.Contains(content, "npm") {
		return "nest"
	}
	if strings.Contains(content, "python") || strings.Contains(content, "pip") {
		return "python"
	}
	if strings.Contains(content, "dotnet") || strings.Contains(content, "nuget") {
		return "dotnet"
	}

	return "generic"
}
