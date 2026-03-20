package installer

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/api"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/templates"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/version"
	syncpkg "github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/sync"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
)

func New(flags *Flags) *Installer {
	logger := ui.NewLogger(flags.Silent)

	// ALWAYS install GA, Context7-MCP, and Engram - no matter what
	// These are the base components that should always be present
	flags.InstallGA = true
	flags.InstallExt = true

	// OpenCode and GitHub Copilot go together by default.
	// If provider is OpenCode, ensure Copilot-native setup is also enabled.
	if strings.EqualFold(flags.Provider, "opencode") {
		flags.InstallGlobal = true
		if !flags.SkipVSCode {
			flags.InstallVSCode = true
		}
	}

	targetDir := flags.Target
	if targetDir == "" {
		if wd, err := os.Getwd(); err == nil {
			targetDir = wd
		}
	}

	return &Installer{
		flags:           flags,
		targetDir:       targetDir,
		logger:          logger,
		apiClient:       api.NewGitHubAPI("Yoizen/dev-ai-workflow"),
		versionResolver: version.NewResolver("Yoizen/dev-ai-workflow"),
		projectType:     flags.ProjectType,
		provider:        flags.Provider,
		version:         flags.Version,
		channel:         flags.Channel,
		buildVersion:    flags.BuildVersion,
	}
}

func (i *Installer) Run() error {
	if i.flags.Help {
		i.showHelp()
		return nil
	}

	if i.flags.ListTypes {
		return i.listTypes()
	}

	if i.flags.ListExtensions {
		return i.listExtensions()
	}

	if i.flags.ListInstallableSkills {
		return i.runListInstallableSkills()
	}

	// Handle --sync flag
	if i.flags.Sync {
		return i.runSync()
	}

	// Handle --install-skill flag
	if i.flags.InstallSkill != "" {
		return i.runInstallSkill()
	}
	if len(i.flags.InstallSkills) > 0 {
		return i.runInstallSkills()
	}

	if i.flags.DryRun {
		i.logger.LogWarning("⚠ DRY RUN MODE - no changes will be made")
		i.logger.Log("")
	}

	if err := i.checkPrerequisites(); err != nil {
		return fmt.Errorf("prerequisite check failed: %w", err)
	}

	if err := i.ensureGitRepo(); err != nil {
		return fmt.Errorf("git repository setup failed: %w", err)
	}

	if i.flags.All {
		return i.runAll()
	} else if i.flags.UpdateAll {
		return i.updateAll()
	} else {
		return i.runSelected()
	}
}

func (i *Installer) ShowNextSteps() {
	i.showNextSteps()
}

func (i *Installer) showNextSteps() {
	i.logger.Log("")
	if i.flags.UpdateAll {
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━  Update Complete!")
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	} else {
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━   Setup Complete!")
		i.logger.Log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
	}
	i.logger.Log("")
	i.logger.Log("YWAI configured in:")
	i.logger.Log("  • " + i.targetDir)
	i.logger.Log("")
	i.logger.Log("What is now available:")

	if i.flags.InstallGA || i.flags.All {
		i.logger.Log("  • GA (Guardian Agent) core runtime")
	}

	if i.flags.InstallSDD || i.flags.All {
		i.logger.Log("  • SDD Orchestrator workflow")
	}

	if i.flags.InstallExt || i.flags.All {
		i.logger.Log("  • Project extensions and integrations")
	}

	if i.flags.InstallGlobal {
		i.logger.Log("  • Global agents / skills")
	}

	if i.flags.InstallVSCode && !i.flags.SkipVSCode {
		i.logger.Log("  • VS Code / Copilot extensions")
	}

	i.logger.Log("")
	if i.flags.UpdateAll {
		i.logger.Log("Suggested checks after update:")
		i.logger.Log("  1. Open the project and confirm your AI tools still load the expected agents/commands")
		i.logger.Log("  2. Review AGENTS.md and .ga config if you changed provider or project type")
	} else {
		i.logger.Log("Suggested next steps:")
		i.logger.Log("  1. Open the project in your editor")
		i.logger.Log("  2. Review .ga config (provider: " + i.provider + ")")
		i.logger.Log("  3. Customize AGENTS.md for your project")
	}
	if i.flags.InstallSDD || i.flags.All {
		i.logger.Log("  4. Start with /sdd:new for spec-driven development")
	}
	i.logger.Log("")
	i.logger.Log("Useful commands:")
	i.logger.Log("  • ywai --help")
	i.logger.Log("  • ywai --sync")
	i.logger.Log("  • ywai --update-all")
}

func (i *Installer) showHelp() {
	fmt.Println(`GA + SDD Orchestrator — Setup

USAGE:
    ywai [OPTIONS] [target-directory]

OPTIONS:
    --all               Install everything
    --install-ga       Install GA
    --install-sdd      Install SDD
    --install-vscode   Install VS Code
    --extensions       Install extensions
    --global-skills    Install global agents
    --provider=<name>  opencode, claude, gemini, ollama
    --type=<name>      nest, nest-angular, nest-react, python, dotnet, devops, generic
    --target=<path>    Target directory
    --install-version=<tag> Specific version tag
    --channel=<name>   stable, latest
    --force            Force reinstall
    --dry-run          Preview
    --list-types       List available project types
    --list-extensions  List available extensions
    --skip-ga          Skip GA installation
    --skip-sdd         Skip SDD installation
    --skip-vscode      Skip VS Code extensions
    --help, -h         Show help`)
}

func (i *Installer) runCommand(name string, args ...string) error {
	cmd := exec.Command(name, args...)
	cmd.Dir = i.targetDir
	output, err := cmd.CombinedOutput()
	if err != nil {
		i.logger.LogError(fmt.Sprintf("Command failed: %s %v", name, args))
		i.logger.LogError(string(output))
		return err
	}
	return nil
}

func (i *Installer) commandOutput(name string, args ...string) string {
	cmd := exec.Command(name, args...)
	cmd.Dir = i.targetDir
	output, _ := cmd.CombinedOutput()
	return string(output)
}

func (i *Installer) fileExists(path string) bool {
	_, err := os.Stat(path)
	return err == nil
}

func (i *Installer) dirExists(path string) bool {
	info, err := os.Stat(path)
	return err == nil && info.IsDir()
}

func (i *Installer) ensureDir(path string) error {
	return os.MkdirAll(path, 0755)
}

func (i *Installer) copyFile(src, dst string) error {
	if i.fileExists(dst) && !i.flags.Force {
		if err := i.backupFile(dst); err != nil {
			i.logger.LogWarning(fmt.Sprintf("Failed to backup %s: %v", dst, err))
		}
	}

	data, err := os.ReadFile(src)
	if err != nil {
		return err
	}
	return os.WriteFile(dst, data, 0644)
}

func (i *Installer) copyDir(src, dst string) error {
	return filepath.Walk(src, func(path string, info os.FileInfo, err error) error {
		if err != nil {
			return err
		}
		relPath, _ := filepath.Rel(src, path)
		destPath := filepath.Join(dst, relPath)
		if info.IsDir() {
			return os.MkdirAll(destPath, info.Mode())
		}
		return i.copyFile(path, destPath)
	})
}

func (i *Installer) commandExists(name string) bool {
	_, err := exec.LookPath(name)
	return err == nil
}

func (i *Installer) getGADir() string {
	if runtime.GOOS == "windows" {
		if localAppData := strings.TrimSpace(os.Getenv("LOCALAPPDATA")); localAppData != "" {
			return filepath.Join(localAppData, "yoizen", "dev-ai-workflow")
		}
	}

	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".local", "share", "yoizen", "dev-ai-workflow")
}

func (i *Installer) getSkillsDir() string {
	return filepath.Join(i.targetDir, "skills")
}

func (i *Installer) getYWAIDir() string {
	return filepath.Join(i.targetDir, "ywai")
}

func (i *Installer) getRepoRoot() string {
	execPath, _ := os.Executable()
	dir := filepath.Dir(execPath)

	for j := 0; j < 5; j++ {
		if i.dirExists(filepath.Join(dir, "ywai")) {
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

func (i *Installer) loadTypesConfig() *TypesConfig {
	candidates := i.ywaiCandidates(false, "types/types.json", "setup/types/types.json")
	typesPath := i.firstExistingFile(candidates...)

	data, err := os.ReadFile(typesPath)
	if err != nil {
		return &TypesConfig{
			Types: map[string]ProjectType{
				"generic": {Description: "Generic"},
				"nest":    {Description: "NestJS"},
			},
			Default: "generic",
		}
	}

	var config TypesConfig
	if err := json.Unmarshal(data, &config); err != nil {
		i.logger.LogWarning("Failed to parse types.json, using defaults")
		return &TypesConfig{
			Types: map[string]ProjectType{
				"generic": {Description: "Generic"},
				"nest":    {Description: "NestJS"},
			},
			Default: "generic",
		}
	}
	return &config
}

func (i *Installer) ProjectTypeOptions() []ProjectTypeOption {
	cfg := i.loadTypesConfig()
	if len(cfg.Types) == 0 {
		return []ProjectTypeOption{
			{Name: "generic", Description: "Generic project"},
		}
	}

	names := make([]string, 0, len(cfg.Types))
	for name := range cfg.Types {
		names = append(names, name)
	}
	sort.Strings(names)

	options := make([]ProjectTypeOption, 0, len(names))
	defaultType := cfg.Default
	if def, ok := cfg.Types[defaultType]; ok {
		options = append(options, ProjectTypeOption{
			Name:        defaultType,
			Description: def.Description,
		})
	}

	for _, name := range names {
		if name == defaultType {
			continue
		}
		options = append(options, ProjectTypeOption{
			Name:        name,
			Description: cfg.Types[name].Description,
		})
	}

	return options
}

func (i *Installer) resolveVersion() string {
	// Explicit user selection always wins.
	if v := strings.TrimSpace(i.version); v != "" {
		return v
	}

	// Default behavior: pin assets to the same release tag as the running binary.
	if pinned := normalizePinnedBuildVersion(i.buildVersion); pinned != "" {
		return pinned
	}

	version, err := i.versionResolver.ResolveVersion(i.version, i.channel)
	if err != nil {
		i.logger.LogWarning(fmt.Sprintf("Failed to resolve version: %v", err))
		return "main" // fallback to main branch
	}
	return version
}

var gitDescribeVersionPattern = regexp.MustCompile(`^(v\d+\.\d+\.\d+(?:-[0-9A-Za-z.]+)?)-\d+-g[0-9a-f]+(?:-dirty)?$`)

func normalizePinnedBuildVersion(raw string) string {
	v := strings.TrimSpace(raw)
	if v == "" || v == "dev" {
		return ""
	}
	if idx := strings.Index(v, " "); idx > 0 {
		v = v[:idx]
	}
	if strings.HasPrefix(v, "main") || strings.HasPrefix(v, "master") {
		return v
	}
	if !strings.HasPrefix(v, "v") {
		v = "v" + v
	}
	if matches := gitDescribeVersionPattern.FindStringSubmatch(v); len(matches) == 2 {
		return matches[1]
	}
	return v
}

// installTemplates installs documentation templates
func (i *Installer) installTemplates() error {
	// Get templates directory - look in multiple locations
	templatesDirs := i.ywaiCandidates(false, "templates", "setup/lib/templates")
	if repoRoot := i.getRepoRoot(); repoRoot != "" {
		templatesDirs = append(templatesDirs, filepath.Join(repoRoot, "lib", "templates"))
	}
	templatesDirs = append(templatesDirs, filepath.Join(i.getGADir(), "lib", "templates"), "lib/templates")

	templatesDir := i.firstExistingDir(templatesDirs...)

	if templatesDir == "" {
		i.logger.LogInfo("Templates directory not found, skipping docs templates")
		return nil
	}

	templateInstaller := templates.NewInstaller(templatesDir, i.targetDir)
	return templateInstaller.InstallTemplates()
}

func (i *Installer) runSync() error {
	syncFlags := &syncpkg.SyncFlags{
		ProjectType: i.flags.ProjectType,
		Force:       i.flags.Force,
		DryRun:      i.flags.DryRun,
	}
	s := syncpkg.New(syncFlags, i.logger, i.targetDir)
	return s.Run()
}

func (i *Installer) runInstallSkill() error {
	syncFlags := &syncpkg.SyncFlags{
		ProjectType: i.flags.ProjectType,
		Force:       i.flags.Force,
		DryRun:      i.flags.DryRun,
	}
	s := syncpkg.New(syncFlags, i.logger, i.targetDir)
	return s.InstallSingleSkill(i.flags.InstallSkill)
}

func (i *Installer) runInstallSkills() error {
	syncFlags := &syncpkg.SyncFlags{
		ProjectType: i.flags.ProjectType,
		Force:       i.flags.Force,
		DryRun:      i.flags.DryRun,
	}
	s := syncpkg.New(syncFlags, i.logger, i.targetDir)
	return s.InstallSkills(i.flags.InstallSkills)
}

func (i *Installer) runListInstallableSkills() error {
	syncFlags := &syncpkg.SyncFlags{
		ProjectType: i.flags.ProjectType,
		Force:       i.flags.Force,
		DryRun:      i.flags.DryRun,
	}
	s := syncpkg.New(syncFlags, i.logger, i.targetDir)
	return s.ListInstallableSkills()
}
