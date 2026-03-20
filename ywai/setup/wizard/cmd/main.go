package main

import (
	"flag"
	"fmt"
	"os"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	versionresolver "github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer/version"
)

// Version information (set during build)
var version = "dev"

func main() {
	flags := parseFlags()

	if !flags.NonInteractive && len(os.Args) == 1 {
		handled, err := runInteractive(flags)
		if err != nil {
			if err == errInteractiveSetupCancelled {
				os.Exit(0)
			}
			fmt.Fprintf(os.Stderr, "Error: %v\n", err)
			os.Exit(1)
		}
		if handled {
			return
		}
	}

	// Handle version flag
	if flags.Help {
		showHelp()
		os.Exit(0)
	}

	if flags.VersionFlag && !hasInstallIntent(flags) {
		fmt.Printf("YWAI Setup Wizard %s\n", formatDisplayVersion(version))
		os.Exit(0)
	}

	checkForUpdates(flags)

	inst := installer.New(flags)

	if err := inst.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %v\n", err)
		os.Exit(1)
	}

	if shouldShowNextSteps(flags) {
		inst.ShowNextSteps()
	}
}

func hasInstallIntent(flags *installer.Flags) bool {
	return flags.All ||
		flags.InstallGA ||
		flags.InstallSDD ||
		flags.InstallVSCode ||
		flags.InstallGlobal ||
		flags.InstallExt ||
		flags.SkipGA ||
		flags.SkipSDD ||
		flags.SkipVSCode ||
		flags.UpdateAll ||
		flags.DryRun ||
		flags.Force ||
		flags.ListTypes ||
		flags.ListExtensions ||
		flags.ListInstallableSkills ||
		flags.Sync ||
		flags.InstallSkill != "" ||
		len(flags.InstallSkills) > 0 ||
		flags.Target != "" ||
		flags.ProjectType != "" ||
		flags.Version != "" ||
		flags.Channel != "stable"
}

func shouldShowNextSteps(flags *installer.Flags) bool {
	return !flags.Help &&
		!flags.VersionFlag &&
		!flags.ListTypes &&
		!flags.ListExtensions &&
		!flags.ListInstallableSkills &&
		!flags.Sync &&
		flags.InstallSkill == "" &&
		len(flags.InstallSkills) == 0
}

func parseFlags() *installer.Flags {
	flags := &installer.Flags{}

	flag.BoolVar(&flags.All, "all", false, "Install everything")
	flag.BoolVar(&flags.InstallGA, "install-ga", false, "Install GA")
	flag.BoolVar(&flags.InstallSDD, "install-sdd", false, "Install SDD")
	flag.BoolVar(&flags.InstallVSCode, "install-vscode", false, "Install VS Code")
	flag.BoolVar(&flags.InstallGlobal, "global-skills", false, "Install global agents")
	flag.BoolVar(&flags.InstallExt, "extensions", false, "Install extensions")
	flag.BoolVar(&flags.SkipGA, "skip-ga", false, "Skip GA")
	flag.BoolVar(&flags.SkipSDD, "skip-sdd", false, "Skip SDD")
	flag.BoolVar(&flags.SkipVSCode, "skip-vscode", false, "Skip VS Code")
	flag.BoolVar(&flags.UpdateAll, "update-all", false, "Update all")
	flag.BoolVar(&flags.Force, "force", false, "Force reinstall")
	flag.BoolVar(&flags.Silent, "silent", false, "Minimal output")
	flag.BoolVar(&flags.DryRun, "dry-run", false, "Show what would happen")
	flag.BoolVar(&flags.Help, "h", false, "Show help")
	flag.BoolVar(&flags.Help, "help", false, "Show help")
	flag.BoolVar(&flags.NonInteractive, "no-interactive", false, "Disable interactive mode")

	var showVersion bool
	flag.BoolVar(&showVersion, "version", false, "Show version")

	flag.BoolVar(&flags.ListTypes, "list-types", false, "List project types")
	flag.BoolVar(&flags.ListExtensions, "list-extensions", false, "List extensions for a project type")
	flag.BoolVar(&flags.ListInstallableSkills, "list-installable-skills", false, "List skills available to install in this repo")
	flag.BoolVar(&flags.Sync, "sync", false, "Generate sync report for LLM")
	flag.StringVar(&flags.InstallSkill, "install-skill", "", "Install specific skill (e.g., angular/signals)")
	var installSkillsCSV string
	flag.StringVar(&installSkillsCSV, "install-skills", "", "Install multiple skills separated by commas")
	flag.StringVar(&flags.Provider, "provider", "opencode", "LLM provider")
	flag.StringVar(&flags.Target, "target", "", "Target directory")
	flag.StringVar(&flags.ProjectType, "type", "", "Project type")
	flag.StringVar(&flags.Version, "install-version", "", "Specific version to install")
	flag.StringVar(&flags.Channel, "channel", "stable", "Release channel")

	flag.Parse()

	// Handle environment variable overrides
	if envVersion := os.Getenv("YWAI_VERSION"); envVersion != "" {
		flags.Version = envVersion
	}
	if envChannel := os.Getenv("YWAI_CHANNEL"); envChannel != "" {
		flags.Channel = envChannel
	}

	if flag.NArg() > 0 && flags.Target == "" {
		flags.Target = flag.Arg(0)
	}
	if installSkillsCSV != "" {
		for _, part := range strings.Split(installSkillsCSV, ",") {
			part = strings.TrimSpace(part)
			if part != "" {
				flags.InstallSkills = append(flags.InstallSkills, part)
			}
		}
	}

	// Set version flag for main function
	flags.VersionFlag = showVersion
	flags.BuildVersion = normalizeBuildVersion(version)

	return flags
}

func showHelp() {
	fmt.Println(`YWAI Setup Wizard - Go Binary Version

USAGE:
    ywai [OPTIONS] [target-directory]

OPTIONS:
    --all               Install the full recommended setup
    --install-ga        Install GA (Guardian Agent)
    --install-sdd       Install SDD Orchestrator
    --install-vscode    Install VS Code / Copilot extensions
    --global-skills     Install global agents
    --extensions       Install project extensions
    --update-all        Refresh an existing YWAI installation
    --sync              Generate sync report for LLM (no changes made)
    --install-skill SKILL   Install one specific skill (e.g. angular/signals)
    --install-skills A,B    Install multiple skills at once
    --force             Force reinstall / overwrite managed files
    --silent            Minimal output
    --dry-run           Preview changes without writing anything
    --version           Show version information
    --list-types        List available project types
    --list-extensions   List extensions for a project type
    --list-installable-skills  List installable skills missing from this repo
    --provider PROVIDER Main AI provider (default: opencode)
    --type TYPE         Project type
    --install-version VERSION   Specific version to install
    --channel CHANNEL   Release channel (stable/latest)
    --help, -h          Show this help
    --no-interactive    Disable interactive mode (CLI only)

EXAMPLES:
    ywai                                   # Interactive guided setup
    ywai --all --type=nest                 # Full install in current repo
    ywai --update-all                      # Refresh an existing setup
    ywai --sync                            # Generate sync report
    ywai --list-installable-skills         # Show missing installable skills
    ywai --install-skills typescript,biome # Install multiple skills
    ywai --sync --type=nest-angular        # Sync with specific type
    ywai --install-skill angular/signals   # Install one skill
    ywai --dry-run --all                   # Preview full install
    ywai --version

ENVIRONMENT VARIABLES:
    YWAI_VERSION        Specific version (overrides --install-version)
    YWAI_CHANNEL        Release channel (overrides --channel)

For more information, visit: https://github.com/Yoizen/dev-ai-workflow`)
}

func checkForUpdates(flags *installer.Flags) {
	if shouldSkipUpdateCheck() {
		return
	}

	current := normalizeBuildVersion(version)
	if current == "" {
		return
	}

	resolver := versionresolver.NewResolver("Yoizen/dev-ai-workflow")
	hasUpdate, latest, err := resolver.CheckForUpdates(current, flags.Channel)
	if err != nil || !hasUpdate {
		return
	}

	fmt.Printf("Update available: %s -> %s\n", current, latest)
	fmt.Println("   If YWAI is already installed, run: ywai --update-all")
	fmt.Println("   To reinstall the binary manually, run:")
	fmt.Println("   curl -sSL https://raw.githubusercontent.com/Yoizen/dev-ai-workflow/main/ywai/setup/install.sh | bash")
	fmt.Println("")
}

func shouldSkipUpdateCheck() bool {
	v := strings.ToLower(strings.TrimSpace(os.Getenv("YWAI_SKIP_UPDATE_CHECK")))
	return v == "1" || v == "true" || v == "yes"
}

func normalizeBuildVersion(raw string) string {
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
	return v
}

func formatDisplayVersion(raw string) string {
	v := strings.TrimSpace(raw)
	if v == "" {
		return "vdev"
	}
	if strings.HasPrefix(v, "v") {
		return v
	}
	return "v" + v
}
