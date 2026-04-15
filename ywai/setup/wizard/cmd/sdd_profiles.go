package main

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
)

const (
	sddProfilesFileName = "sdd-profiles.json"
)

type SDDProfile struct {
	Phases map[string]string `json:"phases"`
}

type SDDProfilesConfig struct {
	Profiles      map[string]SDDProfile `json:"profiles"`
	ActiveProfile string               `json:"active_profile"`
}

func runSDDProfiles(flags *installer.Flags) error {
	if len(os.Args) < 3 {
		showSDDProfilesHelp()
		return nil
	}

	command := os.Args[2]
	
	switch command {
	case "list":
		return listSDDProfiles()
	case "create":
		if len(os.Args) < 4 {
			return fmt.Errorf("usage: ywai sdd-profiles create <profile-name>")
		}
		return createSDDProfile(os.Args[3])
	case "set":
		if len(os.Args) < 5 {
			return fmt.Errorf("usage: ywai sdd-profiles set <profile-name> <phase> <model>")
		}
		return setSDDProfilePhase(os.Args[3], os.Args[4], os.Args[5])
	case "activate":
		if len(os.Args) < 4 {
			return fmt.Errorf("usage: ywai sdd-profiles activate <profile-name>")
		}
		return activateSDDProfile(os.Args[3])
	case "delete":
		if len(os.Args) < 4 {
			return fmt.Errorf("usage: ywai sdd-profiles delete <profile-name>")
		}
		return deleteSDDProfile(os.Args[3])
	default:
		showSDDProfilesHelp()
		return nil
	}
}

func getSDDProfilesPath() (string, error) {
	homeDir, err := os.UserHomeDir()
	if err != nil {
		return "", err
	}
	
	// Check in project .ywai directory first
	if cwd, err := os.Getwd(); err == nil {
		projectPath := filepath.Join(cwd, ".ywai", sddProfilesFileName)
		if _, err := os.Stat(projectPath); err == nil {
			return projectPath, nil
		}
	}
	
	// Fallback to global config
	globalPath := filepath.Join(homeDir, ".ywai", sddProfilesFileName)
	return globalPath, nil
}

func loadSDDProfiles() (*SDDProfilesConfig, error) {
	path, err := getSDDProfilesPath()
	if err != nil {
		return nil, err
	}
	
	content, err := os.ReadFile(path)
	if err != nil {
		// Return default config if file doesn't exist
		return &SDDProfilesConfig{
			Profiles: map[string]SDDProfile{
				"default": {
					Phases: map[string]string{
						"sdd-init":    "anthropic/claude-opus-4-20250514",
						"sdd-explore": "anthropic/claude-opus-4-20250514",
						"sdd-spec":    "anthropic/claude-opus-4-20250514",
						"sdd-design":  "anthropic/claude-opus-4-20250514",
						"sdd-tasks":   "anthropic/claude-sonnet-4-20250514",
						"sdd-apply":   "openai/codex-5.3",
						"sdd-verify":  "anthropic/claude-opus-4-20250514",
					},
				},
			},
			ActiveProfile: "default",
		}, nil
	}
	
	var config SDDProfilesConfig
	if err := json.Unmarshal(content, &config); err != nil {
		return nil, err
	}
	
	return &config, nil
}

func saveSDDProfiles(config *SDDProfilesConfig) error {
	path, err := getSDDProfilesPath()
	if err != nil {
		return err
	}
	
	// Ensure directory exists
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0755); err != nil {
		return err
	}
	
	content, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return err
	}
	
	return os.WriteFile(path, content, 0644)
}

func listSDDProfiles() error {
	config, err := loadSDDProfiles()
	if err != nil {
		return err
	}
	
	fmt.Println("SDD Profiles:")
	fmt.Println("============")
	
	// Sort profile names
	var profileNames []string
	for name := range config.Profiles {
		profileNames = append(profileNames, name)
	}
	sort.Strings(profileNames)
	
	for _, name := range profileNames {
		profile := config.Profiles[name]
		indicator := " "
		if name == config.ActiveProfile {
			indicator = "*"
		}
		fmt.Printf("%s %s\n", indicator, name)
		
		// Sort phase names
		var phaseNames []string
		for phase := range profile.Phases {
			phaseNames = append(phaseNames, phase)
		}
		sort.Strings(phaseNames)
		
		for _, phase := range phaseNames {
			fmt.Printf("    %s: %s\n", phase, profile.Phases[phase])
		}
		fmt.Println()
	}
	
	return nil
}

func createSDDProfile(name string) error {
	config, err := loadSDDProfiles()
	if err != nil {
		return err
	}
	
	if _, exists := config.Profiles[name]; exists {
		return fmt.Errorf("profile '%s' already exists", name)
	}
	
	// Create new profile with default phases
	config.Profiles[name] = SDDProfile{
		Phases: map[string]string{
			"sdd-init":    "anthropic/claude-opus-4-20250514",
			"sdd-explore": "anthropic/claude-opus-4-20250514",
			"sdd-spec":    "anthropic/claude-opus-4-20250514",
			"sdd-design":  "anthropic/claude-opus-4-20250514",
			"sdd-tasks":   "anthropic/claude-sonnet-4-20250514",
			"sdd-apply":   "openai/codex-5.3",
			"sdd-verify":  "anthropic/claude-opus-4-20250514",
		},
	}
	
	if err := saveSDDProfiles(config); err != nil {
		return err
	}
	
	fmt.Printf("Created profile '%s'\n", name)
	fmt.Printf("Activate it with: ywai sdd-profiles activate %s\n", name)
	return nil
}

func setSDDProfilePhase(profileName, phase, model string) error {
	config, err := loadSDDProfiles()
	if err != nil {
		return err
	}
	
	profile, exists := config.Profiles[profileName]
	if !exists {
		return fmt.Errorf("profile '%s' not found", profileName)
	}
	
	profile.Phases[phase] = model
	config.Profiles[profileName] = profile
	
	if err := saveSDDProfiles(config); err != nil {
		return err
	}
	
	fmt.Printf("Set %s phase in profile '%s' to: %s\n", phase, profileName, model)
	return nil
}

func activateSDDProfile(name string) error {
	config, err := loadSDDProfiles()
	if err != nil {
		return err
	}
	
	if _, exists := config.Profiles[name]; !exists {
		return fmt.Errorf("profile '%s' not found", name)
	}
	
	config.ActiveProfile = name
	
	if err := saveSDDProfiles(config); err != nil {
		return err
	}
	
	fmt.Printf("Activated profile: %s\n", name)
	return nil
}

func deleteSDDProfile(name string) error {
	config, err := loadSDDProfiles()
	if err != nil {
		return err
	}
	
	if _, exists := config.Profiles[name]; !exists {
		return fmt.Errorf("profile '%s' not found", name)
	}
	
	if name == config.ActiveProfile {
		return fmt.Errorf("cannot delete active profile. Activate another profile first.")
	}
	
	delete(config.Profiles, name)
	
	if err := saveSDDProfiles(config); err != nil {
		return err
	}
	
	fmt.Printf("Deleted profile: %s\n", name)
	return nil
}

func showSDDProfilesHelp() {
	fmt.Println(`YWAI SDD Profiles - Per-Phase Model Assignment

USAGE:
    ywai sdd-profiles <command> [arguments]

COMMANDS:
    list                        List all profiles and their phase assignments
    create <profile-name>       Create a new profile with default phases
    set <profile> <phase> <model>  Set model for a specific phase in a profile
    activate <profile-name>     Set a profile as active
    delete <profile-name>       Delete a profile

PHASES:
    sdd-init    Initialize SDD context
    sdd-explore Explore ideas before committing
    sdd-spec    Write specifications
    sdd-design  Technical design document
    sdd-tasks   Break change into tasks
    sdd-apply   Implement tasks
    sdd-verify  Validate implementation vs specs

EXAMPLES:
    ywai sdd-profiles list
    ywai sdd-profiles create cheap
    ywai sdd-profiles set cheap sdd-design openrouter/qwen/qwen3-30b-a3b:free
    ywai sdd-profiles activate cheap
    ywai sdd-profiles delete old-profile

The active profile is used by SDD skills to determine which model to use for each phase.`)
}
