package main

import (
	"errors"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	syncpkg "github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/sync"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
	"github.com/charmbracelet/bubbles/spinner"
	"github.com/charmbracelet/bubbles/textinput"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type interactiveStep int

const (
	stepWelcome interactiveStep = iota
	stepPath
	stepProjectType
	stepProvider
	stepComponents
	stepConfirm
	stepSkillSelect
	stepSkillConfirm
	stepInstalling
	stepDone
	// Agent creation steps
	stepAgentType
	stepAgentName
	stepAgentDescription
	stepAgentPrompt
	stepAgentTools
	stepAgentConfirm
	stepAgentDone
	// Agent list steps
	stepAgentList
	stepAgentMenu
	stepAgentView
	stepAgentEdit
	stepAgentDeleteConfirm
	// File browser step
	stepFileBrowser
	// Global tools steps
	stepGlobalTools
	stepGlobalToolsRunning
)

var (
	brandStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("86")).
			Background(lipgloss.Color("236")).
			Padding(0, 1)

	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("99"))

	subtitleStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("245"))

	infoStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("243"))

	helpStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("241"))

	itemStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	selectedItemStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(lipgloss.Color("118")).
				Background(lipgloss.Color("235")).
				Padding(0, 1)

	errorStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("167"))

	successStyle = lipgloss.NewStyle().
			Foreground(lipgloss.Color("84"))

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("236")).
			Padding(1, 2)

	activeBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("99")).
			Foreground(lipgloss.Color("255")).
			Padding(1, 2)
)

type setupModel struct {
	step       interactiveStep
	updateMode bool

	width  int
	height int

	spinner  spinner.Model
	quitting bool
	cancel   bool
	done     bool
	err      error

	pathInput textinput.Model

	projectTypeValues []string
	projectTypeLabels []string
	projectTypeHints  []string
	providerValues    []string
	providerLabels    []string

	projectTypeIdx int
	providerIdx    int

	componentNames  []string
	componentValues []bool
	componentCursor int

	welcomeIdx     int
	welcomeOptions []string

	animationFrame int

	// Agent creation fields
	agentTypeIdx     int
	agentTypeOptions []string
	agentNameInput   textinput.Model
	agentDescInput   textinput.Model
	agentPromptInput textinput.Model
	agentToolNames   []string
	agentToolValues  []bool
	agentToolCursor  int
	agentCreated     bool
	agentError       error

	// Agent list fields
	agentList        []AgentInfo
	agentListCursor  int
	agentToDelete    string
	agentSelected    string
	agentMenuCursor  int
	agentMenuOptions []string
	agentViewContent string
	agentEditField   int // 0=desc, 1=prompt, 2=tools

	// File browser fields
	fileBrowserDir     string
	fileBrowserEntries []os.DirEntry
	fileBrowserCursor  int

	skillInstallMode bool
	skillOptions     []syncpkg.SkillInfo
	skillValues      []bool
	skillCursor      int
	skillLoadError   error

	// Global tools fields
	globalToolNames  []string
	globalToolValues []bool
	globalToolCursor int
	globalToolDone   bool
	globalToolOutput string
}

type menuOption struct {
	Title       string
	Description string
}

var errInteractiveSetupCancelled = errors.New("interactive setup cancelled")

type AgentInfo struct {
	Name        string
	Description string
	Mode        string
}

func (m setupModel) currentModeLabel() string {
	if m.updateMode {
		return "Update"
	}
	return "Install"
}

func (m setupModel) currentActionVerb() string {
	if m.updateMode {
		return "update"
	}
	return "install"
}

func (m setupModel) currentProgressVerb() string {
	if m.updateMode {
		return "Updating"
	}
	return "Installing"
}

func (m setupModel) isComponentLocked(idx int) bool {
	switch idx {
	case 0, 3:
		return true
	case 2, 4:
		return strings.EqualFold(m.providerValues[m.providerIdx], "opencode")
	default:
		return false
	}
}

func detectProjectTypeFromPath(target string) string {
	target = strings.TrimSpace(target)
	if target == "" {
		return ""
	}

	packageJsonPath := filepath.Join(target, "package.json")
	if data, err := os.ReadFile(packageJsonPath); err == nil {
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

	if _, err := os.Stat(filepath.Join(target, "pyproject.toml")); err == nil {
		return "python"
	}

	if matches, _ := filepath.Glob(filepath.Join(target, "*.csproj")); len(matches) > 0 {
		return "dotnet"
	}

	if data, err := os.ReadFile(filepath.Join(target, "Dockerfile")); err == nil {
		content := string(data)
		switch {
		case strings.Contains(content, "python"), strings.Contains(content, "pip"):
			return "python"
		case strings.Contains(content, "dotnet"), strings.Contains(content, "nuget"):
			return "dotnet"
		case strings.Contains(content, "node"), strings.Contains(content, "npm"):
			return "nest"
		}
	}

	return "generic"
}

func loadInstallableSkillsForPath(target string) ([]syncpkg.SkillInfo, error) {
	logger := ui.NewLogger(true)
	s := syncpkg.New(&syncpkg.SyncFlags{}, logger, target)
	missing, _, _, err := s.GetInstallableSkills()
	if err != nil {
		return nil, err
	}
	return missing, nil
}

func newSetupModel(defaultPath string) setupModel {
	ti := textinput.New()
	ti.Placeholder = "~/my-project"
	ti.SetValue(defaultPath)
	ti.Focus()
	ti.Width = 50
	ti.Prompt = "  "

	s := spinner.New()
	s.Spinner = spinner.Dot
	s.Style = lipgloss.NewStyle().Foreground(lipgloss.Color("86"))

	typeValues := []string{"generic", "nest", "nest-angular", "nest-react", "python", "dotnet", "devops"}
	typeLabels := []string{
		"generic      - Generic project",
		"nest         - NestJS backend",
		"nest-angular - NestJS + Angular",
		"nest-react   - NestJS + React",
		"python       - Python project",
		"dotnet       - .NET/C# project",
		"devops       - DevOps / infrastructure",
	}
	typeHints := []string{
		"Safe default if you are unsure",
		"Best for NestJS backends",
		"Best for NestJS + Angular repos",
		"Best for NestJS + React repos",
		"Best for Python apps and scripts",
		"Best for .NET / C# repos",
		"Best for CI/CD, Docker, Helm, k8s",
	}

	// Agent creation inputs
	nameTi := textinput.New()
	nameTi.Placeholder = "my-agent"
	nameTi.Focus()
	nameTi.Width = 50
	nameTi.Prompt = "  "

	descTi := textinput.New()
	descTi.Placeholder = "Brief description of what this agent does"
	descTi.Width = 50
	descTi.Prompt = "  "

	promptTi := textinput.New()
	promptTi.Placeholder = "You are a specialized agent that..."
	promptTi.Width = 50
	promptTi.Prompt = "  "

	return setupModel{
		step: stepWelcome,
		welcomeOptions: []string{
			"Install YWAI in a project",
			"Update an existing YWAI setup",
			"Install missing skills in this repo",
			"Update global tools",
			"Create a global agent",
			"Manage global agents",
			"Quit",
		},
		welcomeIdx:        0,
		spinner:           s,
		pathInput:         ti,
		projectTypeValues: typeValues,
		projectTypeLabels: typeLabels,
		projectTypeHints:  typeHints,
		providerValues: []string{
			"opencode",
			"claude",
			"gemini",
			"ollama",
		},
		providerLabels: []string{
			"opencode - OpenCode + Copilot",
			"claude - Anthropic Claude",
			"gemini - Google Gemini",
			"ollama - Local Ollama",
		},
		componentNames: []string{
			"Core runtime: GA / base setup",
			"SDD Orchestrator",
			"VS Code + Copilot extensions",
			"Project integrations and extensions",
			"Global agents / skills",
			"Dry run (preview only)",
		},
		componentValues: []bool{true, true, true, true, false, false},
		// Agent creation initialization
		agentTypeIdx:     0,
		agentTypeOptions: []string{"primary", "subagent"},
		agentNameInput:   nameTi,
		agentDescInput:   descTi,
		agentPromptInput: promptTi,
		agentToolNames: []string{
			"read",
			"write",
			"edit",
			"bash",
		},
		agentToolValues: []bool{true, true, true, false},
		agentToolCursor: 0,
		agentCreated:    false,
		agentError:      nil,
		// Agent list initialization
		agentList:        []AgentInfo{},
		agentListCursor:  0,
		agentToDelete:    "",
		agentSelected:    "",
		agentMenuCursor:  0,
		agentMenuOptions: []string{"View", "Edit", "Delete", "Back"},
		agentViewContent: "",
		agentEditField:   0,
		// File browser initialization
		fileBrowserDir:     "",
		fileBrowserEntries: []os.DirEntry{},
		fileBrowserCursor:  0,
	}
}

func (m setupModel) Init() tea.Cmd {
	return tea.Batch(
		textinput.Blink,
		m.spinner.Tick,
	)
}

func (m setupModel) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
		return m, nil
	case tea.KeyMsg:
		if m.step == stepInstalling || m.step == stepDone {
			return m, nil
		}
		switch msg.String() {
		case "ctrl+c":
			m.cancel = true
			m.quitting = true
			return m, tea.Quit
		}
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}

	switch m.step {
	case stepWelcome:
		return m.updateWelcome(msg)
	case stepPath:
		return m.updatePath(msg)
	case stepProjectType:
		return m.updateProjectType(msg)
	case stepProvider:
		return m.updateProvider(msg)
	case stepComponents:
		return m.updateComponents(msg)
	case stepConfirm:
		return m.updateConfirm(msg)
	case stepSkillSelect:
		return m.updateSkillSelect(msg)
	case stepSkillConfirm:
		return m.updateSkillConfirm(msg)
	case stepAgentType:
		return m.updateAgentType(msg)
	case stepAgentName:
		return m.updateAgentName(msg)
	case stepAgentDescription:
		return m.updateAgentDescription(msg)
	case stepAgentPrompt:
		return m.updateAgentPrompt(msg)
	case stepAgentTools:
		return m.updateAgentTools(msg)
	case stepAgentConfirm:
		return m.updateAgentConfirm(msg)
	case stepAgentList:
		return m.updateAgentList(msg)
	case stepAgentMenu:
		return m.updateAgentMenu(msg)
	case stepAgentView:
		return m.updateAgentView(msg)
	case stepAgentEdit:
		return m.updateAgentEdit(msg)
	case stepAgentDeleteConfirm:
		return m.updateAgentDeleteConfirm(msg)
	case stepFileBrowser:
		return m.updateFileBrowser(msg)
	case stepGlobalTools:
		return m.updateGlobalTools(msg)
	case stepGlobalToolsRunning:
		return m.updateGlobalToolsRunning(msg)
	default:
		return m, nil
	}
}

func (m setupModel) updateWelcome(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.welcomeIdx > 0 {
				m.welcomeIdx--
			}
		case "down", "j":
			if m.welcomeIdx < len(m.welcomeOptions)-1 {
				m.welcomeIdx++
			}
		case "enter":
			switch m.welcomeIdx {
			case 0: // Install
				m.updateMode = false
				m.skillInstallMode = false
				m.step = stepPath
				m.pathInput.Focus()
			case 1: // Update — same flow for now
				m.updateMode = true
				m.skillInstallMode = false
				m.step = stepPath
				m.pathInput.Focus()
			case 2: // Install repo skills
				m.updateMode = false
				m.skillInstallMode = true
				m.step = stepPath
				m.pathInput.Focus()
			case 3: // Update global tools
				m.globalToolNames = []string{
					"GA (Guardian Agent)",
					"SDD Orchestrator skills",
					"Global agents & skills",
					"Engram CLI",
					"Context7 MCP",
				}
				m.globalToolValues = []bool{true, true, true, true, true}
				m.globalToolCursor = 0
				m.globalToolDone = false
				m.step = stepGlobalTools
			case 4: // Create global agent
				m.step = stepAgentType
			case 5: // List global agents
				m.agentList = m.loadAgentList()
				m.agentListCursor = 0
				m.step = stepAgentList
			case 6: // Quit
				m.cancel = true
				m.quitting = true
				return m, tea.Quit
			}
		case "q", "esc":
			m.cancel = true
			m.quitting = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m setupModel) updatePath(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			value := strings.TrimSpace(m.pathInput.Value())
			if value == "" {
				m.err = fmt.Errorf("project path cannot be empty")
				return m, nil
			}
			if m.skillInstallMode {
				skills, err := loadInstallableSkillsForPath(value)
				if err != nil {
					m.err = err
					return m, nil
				}
				m.skillOptions = skills
				m.skillValues = make([]bool, len(skills))
				for idx := range m.skillValues {
					m.skillValues[idx] = true
				}
				m.skillCursor = 0
				m.skillLoadError = nil
				m.step = stepSkillSelect
				m.pathInput.Blur()
				m.err = nil
				return m, nil
			}
			detected := detectProjectTypeFromPath(value)
			if detected != "" {
				for idx, pt := range m.projectTypeValues {
					if pt == detected {
						m.projectTypeIdx = idx
						break
					}
				}
			}
			m.step = stepProjectType
			m.pathInput.Blur()
			m.err = nil
			return m, nil
		case "ctrl+b":
			m.step = stepWelcome
			m.pathInput.Blur()
			return m, nil
		case "ctrl+c", "ctrl+q":
			m.cancel = true
			m.quitting = true
			m.pathInput.Blur()
			return m, tea.Quit
		case "ctrl+f":
			// Open file browser
			m.fileBrowserDir, _ = os.Getwd()
			if m.pathInput.Value() != "" {
				m.fileBrowserDir = m.pathInput.Value()
			}
			m.fileBrowserEntries = m.loadFileBrowser(m.fileBrowserDir)
			m.fileBrowserCursor = 0
			m.pathInput.Blur()
			m.step = stepFileBrowser
			return m, nil
		}
	}
	var cmd tea.Cmd
	m.pathInput, cmd = m.pathInput.Update(msg)
	return m, cmd
}

func (m setupModel) updateProjectType(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.projectTypeIdx > 0 {
				m.projectTypeIdx--
			}
		case "down", "j":
			if m.projectTypeIdx < len(m.projectTypeLabels)-1 {
				m.projectTypeIdx++
			}
		case "enter":
			m.step = stepProvider
		case "b":
			m.step = stepPath
			m.pathInput.Focus()
		}
	}
	return m, nil
}

func (m setupModel) updateProvider(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.providerIdx > 0 {
				m.providerIdx--
			}
		case "down", "j":
			if m.providerIdx < len(m.providerLabels)-1 {
				m.providerIdx++
			}
		case "enter":
			m.step = stepComponents
		case "b":
			m.step = stepProjectType
		}
	}
	return m, nil
}

func (m setupModel) updateComponents(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.componentCursor > 0 {
				m.componentCursor--
			}
		case "down", "j":
			if m.componentCursor < len(m.componentNames)-1 {
				m.componentCursor++
			}
		case " ":
			if !m.isComponentLocked(m.componentCursor) {
				m.componentValues[m.componentCursor] = !m.componentValues[m.componentCursor]
			}
		case "enter":
			m.step = stepConfirm
		case "b":
			m.step = stepProvider
		}
	}
	return m, nil
}

func (m setupModel) updateConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter", "y":
			m.done = true
			return m, tea.Quit
		case "n", "b":
			m.step = stepComponents
		}
	}
	return m, nil
}

func (m setupModel) updateSkillSelect(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.skillCursor > 0 {
				m.skillCursor--
			}
		case "down", "j":
			if m.skillCursor < len(m.skillOptions)-1 {
				m.skillCursor++
			}
		case " ":
			if len(m.skillValues) > 0 && m.skillCursor < len(m.skillValues) {
				m.skillValues[m.skillCursor] = !m.skillValues[m.skillCursor]
			}
		case "a":
			for idx := range m.skillValues {
				m.skillValues[idx] = true
			}
		case "n":
			for idx := range m.skillValues {
				m.skillValues[idx] = false
			}
		case "enter":
			m.step = stepSkillConfirm
		case "b":
			m.step = stepPath
			m.pathInput.Focus()
		}
	}
	return m, nil
}

func (m setupModel) updateSkillConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter", "y":
			m.done = true
			return m, tea.Quit
		case "n", "b":
			m.step = stepSkillSelect
		}
	}
	return m, nil
}

func (m setupModel) View() string {
	if m.quitting {
		return m.renderQuitScreen()
	}

	if m.step == stepInstalling {
		return m.renderInstalling()
	}

	if m.step == stepDone {
		return m.renderDone()
	}

	// Don't render until we have real terminal dimensions
	if m.width == 0 || m.height == 0 {
		return ""
	}

	// Handle agent done step with centered layout
	if m.step == stepAgentDone {
		content := m.renderAgentDone()
		return lipgloss.Place(
			m.width, m.height,
			lipgloss.Center,
			lipgloss.Center,
			content,
		)
	}

	header := m.renderHeader()
	footer := m.renderFooter()
	body := m.renderBody()

	mainContent := lipgloss.JoinVertical(
		lipgloss.Center,
		header,
		lipgloss.NewStyle().Height(1).Render(""),
		body,
		lipgloss.NewStyle().Height(1).Render(""),
		footer,
	)

	return lipgloss.Place(
		m.width, m.height,
		lipgloss.Center,
		lipgloss.Center,
		mainContent,
	)
}

func (m setupModel) renderHeader() string {
	logo := "██╗   ██╗██╗    ██╗ █████╗ ██╗\n" +
		"╚██╗ ██╔╝██║    ██║██╔══██╗██║\n" +
		" ╚████╔╝ ██║ █╗ ██║███████║██║\n" +
		"  ╚██╔╝  ██║███╗██║██╔══██║██║\n" +
		"   ██║   ╚███╔███╔╝██║  ██║██║\n" +
		"   ╚═╝    ╚══╝╚══╝ ╚═╝  ╚═╝╚═╝"

	styledLogo := lipgloss.NewStyle().
		Foreground(lipgloss.Color("99")).
		Bold(true).
		Render(logo)

	version := subtitleStyle.Render("Setup Wizard  •  AI Development Workflow")

	return lipgloss.JoinVertical(
		lipgloss.Left,
		styledLogo,
		"",
		version,
		"",
		infoStyle.Render(strings.Repeat("─", 50)),
	)
}

func (m setupModel) renderWelcomeStep() string {
	subtitle := subtitleStyle.Render("Set up AI workflows for a project in a guided way")
	options := []menuOption{
		{Title: m.welcomeOptions[0], Description: "Best for first-time setup in a repository"},
		{Title: m.welcomeOptions[1], Description: "Refresh an existing setup and re-apply managed files"},
		{Title: m.welcomeOptions[2], Description: "Install only the YWAI skills that are still missing in this repo"},
		{Title: m.welcomeOptions[3], Description: "Update GA, SDD, Engram, Context7, global agents — no repo needed"},
		{Title: m.welcomeOptions[4], Description: "Create a reusable agent for OpenCode / Copilot"},
		{Title: m.welcomeOptions[5], Description: "View, edit, or delete existing global agents"},
		{Title: m.welcomeOptions[6], Description: "Exit without making changes"},
	}

	var items []string
	for idx, opt := range options {
		line := opt.Title + "\n" + helpStyle.Render("   "+opt.Description)
		if idx == m.welcomeIdx {
			items = append(items, selectedItemStyle.Render("▸ "+line))
		} else {
			items = append(items, itemStyle.Render("  "+line))
		}
	}

	menu := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		subtitle,
		"",
		infoStyle.Render("What do you want to do today?"),
		"",
		menu,
	)
}

func (m setupModel) renderBody() string {
	if m.step == stepWelcome {
		return m.renderWelcomeStep()
	}

	stepIndicator := m.renderStepIndicator()

	content := ""
	switch m.step {
	case stepPath:
		content = m.renderPathStep()
	case stepProjectType:
		content = m.renderProjectTypeStep()
	case stepProvider:
		content = m.renderProviderStep()
	case stepComponents:
		content = m.renderComponentsStep()
	case stepConfirm:
		content = m.renderConfirmStep()
	case stepSkillSelect:
		content = m.renderSkillSelectStep()
	case stepSkillConfirm:
		content = m.renderSkillConfirmStep()
	case stepAgentType:
		content = m.renderAgentTypeStep()
	case stepAgentName:
		content = m.renderAgentNameStep()
	case stepAgentDescription:
		content = m.renderAgentDescriptionStep()
	case stepAgentPrompt:
		content = m.renderAgentPromptStep()
	case stepAgentTools:
		content = m.renderAgentToolsStep()
	case stepAgentConfirm:
		content = m.renderAgentConfirmStep()
	case stepAgentList:
		content = m.renderAgentListStep()
	case stepAgentMenu:
		content = m.renderAgentMenuStep()
	case stepAgentView:
		content = m.renderAgentViewStep()
	case stepAgentEdit:
		content = m.renderAgentEditStep()
	case stepAgentDeleteConfirm:
		content = m.renderAgentDeleteConfirmStep()
	case stepFileBrowser:
		content = m.renderFileBrowserStep()
	case stepGlobalTools:
		content = m.renderGlobalToolsStep()
	case stepGlobalToolsRunning:
		content = m.renderGlobalToolsRunningStep()
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		stepIndicator,
		lipgloss.NewStyle().Height(1).Render(""),
		content,
	)
}

func (m setupModel) renderStepIndicator() string {
	if m.skillInstallMode {
		stepNames := []string{"Path", "Skills", "Review"}
		stepEnums := []interactiveStep{stepPath, stepSkillSelect, stepSkillConfirm}
		var parts []string
		for i, s := range stepNames {
			idx := stepEnums[i]
			var item string
			switch {
			case idx < m.step:
				item = successStyle.Render("● " + s)
			case idx == m.step:
				item = titleStyle.Render("▶ " + s)
			default:
				item = infoStyle.Render("○ " + s)
			}
			parts = append(parts, item)
		}
		return strings.Join(parts, infoStyle.Render("  ·  "))
	}

	// stepWelcome is not part of the wizard steps — offset by 1
	stepNames := []string{"Path", "Type", "Provider", "Components", "Review"}
	stepEnums := []interactiveStep{stepPath, stepProjectType, stepProvider, stepComponents, stepConfirm}

	var parts []string
	for i, s := range stepNames {
		idx := stepEnums[i]
		var item string
		switch {
		case idx < m.step:
			item = successStyle.Render("● " + s)
		case idx == m.step:
			item = titleStyle.Render("▶ " + s)
		default:
			item = infoStyle.Render("○ " + s)
		}
		parts = append(parts, item)
	}

	return strings.Join(parts, infoStyle.Render("  ·  "))
}

func (m setupModel) renderPathStep() string {
	box := activeBoxStyle.Render(m.currentModeLabel() + " • Project Directory")

	inputView := m.pathInput.View()
	if m.err != nil {
		inputView = inputView + "\n" + errorStyle.Render("⚠ "+m.err.Error())
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		lipgloss.NewStyle().Foreground(lipgloss.Color("250")).PaddingLeft(2).Render(
			func() string {
				if m.skillInstallMode {
					return "Choose the repository where you want to install missing skills:"
				}
				return fmt.Sprintf("Choose the project folder where YWAI should %s:", m.currentActionVerb())
			}(),
		),
		"",
		helpStyle.Render("Tip: press ctrl+f to browse folders"),
		"",
		itemStyle.Render(inputView),
	)
}

func (m setupModel) renderProjectTypeStep() string {
	box := activeBoxStyle.Render(m.currentModeLabel() + " • Project Type")
	path := strings.TrimSpace(m.pathInput.Value())
	detected := detectProjectTypeFromPath(path)
	hint := infoStyle.Render("Pick the closest match for this repository.")
	if detected != "" {
		hint = infoStyle.Render("Detected from files: ") + titleStyle.Render(detected)
	}
	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		hint,
		"",
		m.renderList(m.projectTypeLabels, m.projectTypeIdx),
		"",
		helpStyle.Render(m.projectTypeHints[m.projectTypeIdx]),
	)
}

func (m setupModel) renderProviderStep() string {
	box := activeBoxStyle.Render(m.currentModeLabel() + " • AI Provider")
	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Select the main AI client your team will use:"),
		"",
		m.renderList(m.providerLabels, m.providerIdx),
		"",
		helpStyle.Render("OpenCode is the default and enables the most integrated workflow."),
	)
}

func (m setupModel) renderComponentsStep() string {
	box := activeBoxStyle.Render(m.currentModeLabel() + " • Components")
	var items []string

	for idx, name := range m.componentNames {
		prefix := "[ ]"
		s := itemStyle

		if idx == m.componentCursor {
			s = selectedItemStyle
		}

		if m.componentValues[idx] {
			prefix = "[✓]"
		}
		if m.isComponentLocked(idx) {
			prefix = "[•]"
		}

		line := fmt.Sprintf("%s %s", prefix, name)
		if m.isComponentLocked(idx) {
			if idx == 0 || idx == 3 {
				line += helpStyle.Render("  (required)")
			} else {
				line += helpStyle.Render("  (required for OpenCode)")
			}
		}
		items = append(items, s.Render(line))
	}

	content := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Choose the optional parts of the workflow:"),
		"",
		helpStyle.Render("Items marked as required are managed automatically and cannot be disabled here."),
		"",
		content,
	)
}

func (m setupModel) renderConfirmStep() string {
	box := activeBoxStyle.Render(m.currentModeLabel() + " • Review")

	path := strings.TrimSpace(m.pathInput.Value())
	if path == "" {
		path = m.pathInput.Placeholder
	}

	projectType := m.projectTypeValues[m.projectTypeIdx]
	provider := m.providerValues[m.providerIdx]

	lines := []string{
		infoStyle.Render(fmt.Sprintf("Ready to %s YWAI in this project:", strings.ToLower(m.currentModeLabel()))),
		"",
		"  " + successStyle.Render("▶") + " Path: " + subtitleStyle.Render(path),
		"  " + successStyle.Render("▶") + " Type: " + subtitleStyle.Render(projectType),
		"  " + successStyle.Render("▶") + " Provider: " + subtitleStyle.Render(provider),
		"",
		infoStyle.Render("What will be applied:"),
	}

	for idx, name := range m.componentNames {
		if m.componentValues[idx] || m.isComponentLocked(idx) {
			status := successStyle.Render("✓")
			label := name
			if m.isComponentLocked(idx) {
				label += " (automatic)"
			}
			lines = append(lines, "    "+status+" "+label)
		}
	}

	lines = append(lines, "")
	if m.updateMode {
		lines = append(lines, helpStyle.Render("Update mode refreshes managed files, skills, extensions, and GA/runtime setup."))
		lines = append(lines, "")
	}
	lines = append(lines, infoStyle.Render("Press ")+titleStyle.Render("Enter")+" to continue, "+titleStyle.Render("b/n")+" to go back")

	content := lipgloss.JoinVertical(lipgloss.Left, lines...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		content,
	)
}

func (m setupModel) renderSkillSelectStep() string {
	box := activeBoxStyle.Render("Install Missing Skills")

	if len(m.skillOptions) == 0 {
		return lipgloss.JoinVertical(
			lipgloss.Left,
			box,
			"",
			successStyle.Render("This repository already has all installable YWAI skills."),
			"",
			helpStyle.Render("Press b to go back and choose another path."),
		)
	}

	var items []string
	for idx, skill := range m.skillOptions {
		prefix := "[ ]"
		style := itemStyle
		if idx == m.skillCursor {
			style = selectedItemStyle
		}
		if idx < len(m.skillValues) && m.skillValues[idx] {
			prefix = "[✓]"
		}
		desc := strings.TrimSpace(skill.Description)
		if desc == "" {
			desc = "No description"
		}
		items = append(items, style.Render(fmt.Sprintf("%s %s", prefix, skill.Name)))
		items = append(items, helpStyle.Render("    "+desc))
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Select the missing skills you want to install in this repository:"),
		"",
		lipgloss.JoinVertical(lipgloss.Left, items...),
		"",
		helpStyle.Render("Space toggle • a select all • n clear all"),
	)
}

func (m setupModel) renderSkillConfirmStep() string {
	box := activeBoxStyle.Render("Review Skill Installation")
	var selected []string
	for idx, skill := range m.skillOptions {
		if idx < len(m.skillValues) && m.skillValues[idx] {
			selected = append(selected, skill.Name)
		}
	}

	lines := []string{
		infoStyle.Render("Repository:"),
		"  " + subtitleStyle.Render(strings.TrimSpace(m.pathInput.Value())),
		"",
		infoStyle.Render("Skills to install:"),
	}
	if len(selected) == 0 {
		lines = append(lines, "  "+errorStyle.Render("No skills selected"))
		lines = append(lines, "", helpStyle.Render("Press b to go back and choose at least one skill."))
	} else {
		for _, skill := range selected {
			lines = append(lines, "  "+successStyle.Render("✓")+" "+skill)
		}
		lines = append(lines, "", helpStyle.Render("YWAI will copy the selected skills, run skills/setup.sh, and try to sync AGENTS.md metadata."))
	}

	lines = append(lines, "", infoStyle.Render("Press ")+titleStyle.Render("Enter")+" to continue, "+titleStyle.Render("b/n")+" to go back")

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		lipgloss.JoinVertical(lipgloss.Left, lines...),
	)
}

func (m setupModel) renderList(items []string, selected int) string {
	var rendered []string
	for idx, item := range items {
		prefix := "  "
		s := itemStyle

		if idx == selected {
			prefix = "▸ "
			s = selectedItemStyle
		}

		rendered = append(rendered, s.Render(prefix+item))
	}
	return lipgloss.JoinVertical(lipgloss.Left, rendered...)
}

func (m setupModel) renderFooter() string {
	var keys []string

	switch m.step {
	case stepPath:
		keys = []string{"Enter", "next", "ctrl+f", "browse", "ctrl+b", "back", "ctrl+q", "quit"}
	case stepProjectType, stepProvider:
		keys = []string{"↑↓", "move", "Enter", "next", "b", "back", "q", "quit"}
	case stepComponents:
		keys = []string{"↑↓", "move", "Space", "toggle", "Enter", "next", "b", "back", "q", "quit"}
	case stepConfirm:
		keys = []string{"Enter", "confirm", "n/b", "back", "q", "quit"}
	case stepSkillSelect:
		keys = []string{"↑↓", "move", "Space", "toggle", "a", "all", "n", "none", "Enter", "next", "b", "back"}
	case stepSkillConfirm:
		keys = []string{"Enter", "confirm", "n/b", "back", "q", "quit"}
	case stepAgentType:
		keys = []string{"↑↓", "move", "Enter", "select", "q/esc", "cancel"}
	case stepAgentName, stepAgentDescription, stepAgentPrompt:
		keys = []string{"Enter", "next", "b", "back", "q/esc", "cancel"}
	case stepAgentTools:
		keys = []string{"↑↓", "move", "Space", "toggle", "Enter", "next", "b", "back", "q/esc", "cancel"}
	case stepAgentConfirm:
		keys = []string{"Enter/y", "create", "n/b", "back", "q/esc", "cancel"}
	case stepAgentList:
		keys = []string{"↑↓", "move", "Enter", "menu", "q", "back"}
	case stepAgentMenu:
		keys = []string{"↑↓", "move", "Enter", "select", "q", "back"}
	case stepAgentView:
		keys = []string{"Enter/q", "back"}
	case stepAgentEdit:
		keys = []string{"↑↓", "field", "Enter", "save", "q", "cancel"}
	case stepAgentDeleteConfirm:
		keys = []string{"y", "confirm", "n", "cancel"}
	case stepFileBrowser:
		keys = []string{"↑↓", "move", "Enter", "select", "ctrl+l", "open", "ctrl+b", "up", "ctrl+q", "back"}
	}

	var helpParts []string
	for i := 0; i < len(keys); i += 2 {
		keyStr := keys[i]
		action := keys[i+1]
		helpParts = append(helpParts, helpStyle.Render(keyStr)+subtitleStyle.Render(" "+action))
	}

	return lipgloss.NewStyle().
		Foreground(lipgloss.Color("241")).
		Render("  " + strings.Join(helpParts, " • "))
}

func (m setupModel) renderInstalling() string {
	header := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("86")).
		Render(fmt.Sprintf("%s YWAI...", m.currentProgressVerb()))

	spinnerFrame := m.spinner.View()

	return lipgloss.JoinVertical(
		lipgloss.Center,
		"",
		header,
		"",
		spinnerFrame,
		"",
		infoStyle.Render(fmt.Sprintf("Please wait while YWAI %s your environment...", strings.ToLower(m.currentActionVerb())+"s")),
		"",
		"",
		helpStyle.Render("This can take a moment depending on downloads and local tools."),
	)
}

func (m setupModel) renderDone() string {
	icon := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("84")).
		Render("✓")

	title := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("86")).
		Render(func() string {
			if m.updateMode {
				return "Update Complete!"
			}
			return "Setup Complete!"
		}())

	message := infoStyle.Render(func() string {
		if m.updateMode {
			return "YWAI has been updated successfully."
		}
		return "YWAI has been installed successfully."
	}())

	return lipgloss.JoinVertical(
		lipgloss.Center,
		"",
		icon,
		"",
		title,
		"",
		message,
	)
}

func (m setupModel) renderQuitScreen() string {
	return lipgloss.JoinVertical(
		lipgloss.Center,
		"",
		errorStyle.Render("✧ Setup cancelled"),
		"",
		infoStyle.Render("No changes were made to your system."),
	)
}

// Agent creation render methods

func (m setupModel) renderAgentTypeStep() string {
	box := activeBoxStyle.Render("Agent Type")

	options := []string{
		"primary  - Main agent (switch with Tab)",
		"subagent - Specialized agent (invoke with @)",
	}

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Select agent type:"),
		"",
		m.renderList(options, m.agentTypeIdx),
	)
}

func (m setupModel) renderAgentNameStep() string {
	box := activeBoxStyle.Render("Agent Name")

	inputView := m.agentNameInput.View()

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		lipgloss.NewStyle().Foreground(lipgloss.Color("250")).PaddingLeft(2).Render("Enter agent name:"),
		"",
		itemStyle.Render(inputView),
	)
}

func (m setupModel) renderAgentDescriptionStep() string {
	box := activeBoxStyle.Render("Agent Description")

	inputView := m.agentDescInput.View()

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		lipgloss.NewStyle().Foreground(lipgloss.Color("250")).PaddingLeft(2).Render("Brief description of what this agent does:"),
		"",
		itemStyle.Render(inputView),
	)
}

func (m setupModel) renderAgentPromptStep() string {
	box := activeBoxStyle.Render("Agent Prompt")

	inputView := m.agentPromptInput.View()

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		lipgloss.NewStyle().Foreground(lipgloss.Color("250")).PaddingLeft(2).Render("System prompt (role and behavior):"),
		"",
		itemStyle.Render(inputView),
	)
}

func (m setupModel) renderAgentToolsStep() string {
	box := activeBoxStyle.Render("Agent Tools")
	var items []string

	for idx, name := range m.agentToolNames {
		prefix := "[ ]"
		s := itemStyle

		if idx == m.agentToolCursor {
			s = selectedItemStyle
		}

		if m.agentToolValues[idx] {
			prefix = "[✓]"
		}

		line := fmt.Sprintf("%s %s", prefix, name)
		items = append(items, s.Render(line))
	}

	content := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Select tools (space to toggle):"),
		"",
		content,
	)
}

func (m setupModel) renderAgentConfirmStep() string {
	box := activeBoxStyle.Render("Confirm Agent Creation")

	name := strings.TrimSpace(m.agentNameInput.Value())
	if name == "" {
		name = m.agentNameInput.Placeholder
	}

	description := strings.TrimSpace(m.agentDescInput.Value())
	if description == "" {
		description = m.agentDescInput.Placeholder
	}

	agentType := m.agentTypeOptions[m.agentTypeIdx]

	lines := []string{
		infoStyle.Render("Ready to create agent:"),
		"",
		"  " + successStyle.Render("▶") + " Name: " + subtitleStyle.Render(name),
		"  " + successStyle.Render("▶") + " Type: " + subtitleStyle.Render(agentType),
		"  " + successStyle.Render("▶") + " Description: " + subtitleStyle.Render(description),
		"",
		infoStyle.Render("Tools enabled:"),
	}

	for idx, tool := range m.agentToolNames {
		if m.agentToolValues[idx] {
			lines = append(lines, "    "+successStyle.Render("✓")+" "+tool)
		}
	}

	lines = append(lines, "")
	lines = append(lines, infoStyle.Render("Press ")+titleStyle.Render("Enter")+" to create, "+titleStyle.Render("b/n")+" to go back")

	content := lipgloss.JoinVertical(lipgloss.Left, lines...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		content,
	)
}

func (m setupModel) renderAgentDone() string {
	if m.agentError != nil {
		icon := lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("167")).
			Render("✗")

		title := lipgloss.NewStyle().
			Bold(true).
			Foreground(lipgloss.Color("167")).
			Render("Creation Failed")

		message := errorStyle.Render(m.agentError.Error())

		return lipgloss.JoinVertical(
			lipgloss.Center,
			"",
			icon,
			"",
			title,
			"",
			message,
		)
	}

	icon := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("84")).
		Render("✓")

	title := lipgloss.NewStyle().
		Bold(true).
		Foreground(lipgloss.Color("86")).
		Render("Agent Created!")

	name := strings.TrimSpace(m.agentNameInput.Value())
	message := infoStyle.Render(fmt.Sprintf("Agent '%s' has been created for:", name))

	locations := []string{
		successStyle.Render("✓") + " OpenCode",
		successStyle.Render("✓") + " Copilot",
	}

	return lipgloss.JoinVertical(
		lipgloss.Center,
		"",
		icon,
		"",
		title,
		"",
		message,
		"",
		lipgloss.JoinVertical(lipgloss.Left, locations...),
	)
}

func (m setupModel) renderAgentListStep() string {
	box := activeBoxStyle.Render("Global Agents")

	if len(m.agentList) == 0 {
		return lipgloss.JoinVertical(
			lipgloss.Left,
			box,
			"",
			infoStyle.Render("No agents found."),
			"",
			helpStyle.Render("Press q to go back"),
		)
	}

	var items []string
	for idx, agent := range m.agentList {
		prefix := "  "
		s := itemStyle

		if idx == m.agentListCursor {
			prefix = "▸ "
			s = selectedItemStyle
		}

		name := agent.Name
		if agent.Mode != "" {
			name = name + " [" + agent.Mode + "]"
		}

		desc := agent.Description
		if len(desc) > 40 {
			desc = desc[:37] + "..."
		}

		line := name
		if desc != "" {
			line = line + " - " + infoStyle.Render(desc)
		}

		items = append(items, s.Render(prefix+line))
	}

	content := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render("Your agents (d/x to delete, q to go back):"),
		"",
		content,
	)
}

func (m setupModel) renderAgentDeleteConfirmStep() string {
	box := activeBoxStyle.Render("Delete Agent")

	lines := []string{
		infoStyle.Render("Are you sure you want to delete this agent?"),
		"",
		"  " + errorStyle.Render("⚠") + " " + titleStyle.Render(m.agentToDelete),
		"",
		infoStyle.Render("This will remove the agent from both OpenCode and Copilot."),
		"",
		helpStyle.Render("Press y to confirm, n to cancel"),
	}

	content := lipgloss.JoinVertical(lipgloss.Left, lines...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		content,
	)
}

func runInteractive(flags *installer.Flags) error {
	wd, _ := os.Getwd()
	model := newSetupModel(wd)

	program := tea.NewProgram(
		model,
		tea.WithAltScreen(),
	)
	finalModel, err := program.Run()
	if err != nil {
		return err
	}

	m, ok := finalModel.(setupModel)
	if !ok {
		return fmt.Errorf("failed to read interactive state")
	}

	if m.cancel || !m.done {
		return errInteractiveSetupCancelled
	}

	target := strings.TrimSpace(m.pathInput.Value())
	if target == "" {
		target = wd
	}

	flags.Target = target

	if m.skillInstallMode {
		var selected []string
		for idx, skill := range m.skillOptions {
			if idx < len(m.skillValues) && m.skillValues[idx] {
				selected = append(selected, skill.Name)
			}
		}
		if len(selected) == 0 {
			return fmt.Errorf("no skills selected")
		}
		flags.InstallSkills = selected
		return nil
	}

	flags.ProjectType = m.projectTypeValues[m.projectTypeIdx]
	flags.Provider = m.providerValues[m.providerIdx]
	flags.UpdateAll = m.updateMode

	flags.InstallGA = m.componentValues[0]
	flags.InstallSDD = m.componentValues[1]
	flags.InstallVSCode = m.componentValues[2]
	flags.InstallExt = m.componentValues[3]
	flags.InstallGlobal = m.componentValues[4]
	flags.DryRun = m.componentValues[5]

	if strings.EqualFold(flags.Provider, "opencode") && !flags.SkipVSCode && !flags.InstallVSCode {
		flags.InstallVSCode = true
		fmt.Println("ℹ OpenCode requires GitHub Copilot setup in this workflow; enabling VS Code extensions.")
	}
	if strings.EqualFold(flags.Provider, "opencode") && !flags.InstallExt {
		flags.InstallExt = true
		fmt.Println("ℹ OpenCode+Copilot flow requires project extensions; enabling extensions.")
	}
	if strings.EqualFold(flags.Provider, "opencode") && !flags.InstallGlobal {
		flags.InstallGlobal = true
		fmt.Println("ℹ OpenCode+Copilot flow requires global agents; enabling global skills/agents.")
	}

	if !flags.UpdateAll && flags.InstallGA && flags.InstallSDD && flags.InstallVSCode && flags.InstallExt {
		flags.All = true
	}

	return nil
}

// Agent creation methods

func (m setupModel) updateAgentType(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.agentTypeIdx > 0 {
				m.agentTypeIdx--
			}
		case "down", "j":
			if m.agentTypeIdx < len(m.agentTypeOptions)-1 {
				m.agentTypeIdx++
			}
		case "enter":
			m.step = stepAgentName
			m.agentNameInput.Focus()
		case "q", "esc":
			m.step = stepWelcome
		}
	}
	return m, nil
}

func (m setupModel) updateAgentName(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			value := strings.TrimSpace(m.agentNameInput.Value())
			if value == "" {
				return m, nil
			}
			m.step = stepAgentDescription
			m.agentDescInput.Focus()
		case "b":
			m.step = stepAgentType
		}
	}
	var cmd tea.Cmd
	m.agentNameInput, cmd = m.agentNameInput.Update(msg)
	return m, cmd
}

func (m setupModel) updateAgentDescription(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			m.step = stepAgentPrompt
			m.agentPromptInput.Focus()
		case "b":
			m.step = stepAgentName
			m.agentNameInput.Focus()
		}
	}
	var cmd tea.Cmd
	m.agentDescInput, cmd = m.agentDescInput.Update(msg)
	return m, cmd
}

func (m setupModel) updateAgentPrompt(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter":
			m.step = stepAgentTools
		case "b":
			m.step = stepAgentDescription
			m.agentDescInput.Focus()
		}
	}
	var cmd tea.Cmd
	m.agentPromptInput, cmd = m.agentPromptInput.Update(msg)
	return m, cmd
}

func (m setupModel) updateAgentTools(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.agentToolCursor > 0 {
				m.agentToolCursor--
			}
		case "down", "j":
			if m.agentToolCursor < len(m.agentToolNames)-1 {
				m.agentToolCursor++
			}
		case " ":
			m.agentToolValues[m.agentToolCursor] = !m.agentToolValues[m.agentToolCursor]
		case "enter":
			m.step = stepAgentConfirm
		case "b":
			m.step = stepAgentPrompt
			m.agentPromptInput.Focus()
		}
	}
	return m, nil
}

func (m setupModel) updateAgentConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "enter", "y":
			err := m.createAgentFile()
			if err != nil {
				m.agentError = err
			} else {
				m.agentCreated = true
			}
			m.step = stepAgentDone
		case "n", "b":
			m.step = stepAgentTools
		case "q", "esc":
			m.cancel = true
			m.quitting = true
			return m, tea.Quit
		}
	}
	return m, nil
}

func (m setupModel) createAgentFile() error {
	name := strings.TrimSpace(m.agentNameInput.Value())
	if name == "" {
		return fmt.Errorf("agent name cannot be empty")
	}

	// Normalize name for filename
	filename := strings.ToLower(name)
	filename = strings.ReplaceAll(filename, " ", "-")
	filename = strings.ReplaceAll(filename, "_", "-")

	description := strings.TrimSpace(m.agentDescInput.Value())
	if description == "" {
		description = fmt.Sprintf("Agent %s", name)
	}

	prompt := strings.TrimSpace(m.agentPromptInput.Value())
	if prompt == "" {
		prompt = fmt.Sprintf("You are %s, a helpful assistant.", name)
	}

	agentType := m.agentTypeOptions[m.agentTypeIdx]

	// Build tools config
	toolsConfig := ""
	toolsEnabled := []string{}
	for i, enabled := range m.agentToolValues {
		if enabled {
			toolsEnabled = append(toolsEnabled, m.agentToolNames[i])
		}
	}

	if len(toolsEnabled) > 0 {
		toolsConfig = "\ntools:\n"
		for _, tool := range m.agentToolNames {
			enabled := false
			for _, e := range toolsEnabled {
				if e == tool {
					enabled = true
					break
				}
			}
			toolsConfig += fmt.Sprintf("  %s: %t\n", tool, enabled)
		}
	}

	content := fmt.Sprintf(`---
description: %s
mode: %s%s---
%s
`, description, agentType, toolsConfig, prompt)

	// Determine agents directory
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}

	// Create directory if it doesn't exist
	if err := os.MkdirAll(agentsDir, 0755); err != nil {
		return fmt.Errorf("failed to create agents directory: %w", err)
	}

	// Write file for OpenCode
	filePath := filepath.Join(agentsDir, filename+".md")
	if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write agent file: %w", err)
	}

	// Also create for Copilot
	copilotDir := filepath.Join(os.Getenv("HOME"), ".github", "copilot", "agents")
	if err := os.MkdirAll(copilotDir, 0755); err != nil {
		return fmt.Errorf("failed to create copilot agents directory: %w", err)
	}

	copilotFilePath := filepath.Join(copilotDir, filename+".md")
	if err := os.WriteFile(copilotFilePath, []byte(content), 0644); err != nil {
		return fmt.Errorf("failed to write copilot agent file: %w", err)
	}

	return nil
}

// loadAgentList loads all agents from the agents directory
func (m setupModel) loadAgentList() []AgentInfo {
	var agents []AgentInfo

	// Determine agents directory
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}

	// Read directory
	entries, err := os.ReadDir(agentsDir)
	if err != nil {
		return agents
	}

	for _, entry := range entries {
		if entry.IsDir() || !strings.HasSuffix(entry.Name(), ".md") {
			continue
		}

		name := strings.TrimSuffix(entry.Name(), ".md")
		info := AgentInfo{
			Name:        name,
			Description: "",
			Mode:        "",
		}

		// Try to read the file to get description and mode
		content, err := os.ReadFile(filepath.Join(agentsDir, entry.Name()))
		if err == nil {
			contentStr := string(content)
			// Parse frontmatter
			if strings.HasPrefix(contentStr, "---") {
				endIdx := strings.Index(contentStr[3:], "---")
				if endIdx > 0 {
					frontmatter := contentStr[3 : endIdx+3]
					// Extract description
					if descIdx := strings.Index(frontmatter, "description:"); descIdx >= 0 {
						lines := strings.Split(frontmatter[descIdx:], "\n")
						if len(lines) > 0 {
							desc := strings.TrimPrefix(lines[0], "description:")
							info.Description = strings.TrimSpace(desc)
						}
					}
					// Extract mode
					if modeIdx := strings.Index(frontmatter, "mode:"); modeIdx >= 0 {
						lines := strings.Split(frontmatter[modeIdx:], "\n")
						if len(lines) > 0 {
							mode := strings.TrimPrefix(lines[0], "mode:")
							info.Mode = strings.TrimSpace(mode)
						}
					}
				}
			}
		}

		agents = append(agents, info)
	}

	return agents
}

func (m setupModel) updateAgentList(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.agentListCursor > 0 {
				m.agentListCursor--
			}
		case "down", "j":
			if m.agentListCursor < len(m.agentList)-1 {
				m.agentListCursor++
			}
		case "enter":
			if len(m.agentList) > 0 && m.agentListCursor < len(m.agentList) {
				m.agentSelected = m.agentList[m.agentListCursor].Name
				m.agentMenuCursor = 0
				m.step = stepAgentMenu
			}
		case "q", "esc":
			m.step = stepWelcome
		}
	}
	return m, nil
}

func (m setupModel) updateAgentMenu(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.agentMenuCursor > 0 {
				m.agentMenuCursor--
			}
		case "down", "j":
			if m.agentMenuCursor < len(m.agentMenuOptions)-1 {
				m.agentMenuCursor++
			}
		case "enter":
			switch m.agentMenuOptions[m.agentMenuCursor] {
			case "View":
				content, _ := m.loadAgentContent(m.agentSelected)
				m.agentViewContent = content
				m.step = stepAgentView
			case "Edit":
				// Load agent data into edit fields
				m.loadAgentForEdit(m.agentSelected)
				m.step = stepAgentEdit
			case "Delete":
				m.agentToDelete = m.agentSelected
				m.step = stepAgentDeleteConfirm
			case "Back":
				m.step = stepAgentList
			}
		case "q", "esc":
			m.step = stepAgentList
		}
	}
	return m, nil
}

func (m setupModel) updateAgentView(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "enter":
			m.step = stepAgentMenu
		}
	}
	return m, nil
}

type editorFinishedMsg struct {
	content string
	err     error
}

func openEditorSync(initialContent string) editorFinishedMsg {
	// Create temp file
	tmpFile, err := os.CreateTemp("", "agent-edit-*.md")
	if err != nil {
		return editorFinishedMsg{err: err}
	}
	defer os.Remove(tmpFile.Name())

	// Write initial content
	if _, err := tmpFile.WriteString(initialContent); err != nil {
		return editorFinishedMsg{err: err}
	}
	tmpFile.Close()

	// Determine editor
	editor := os.Getenv("EDITOR")
	if editor == "" {
		editor = "nano" // fallback
	}

	// Open editor
	cmd := exec.Command(editor, tmpFile.Name())
	cmd.Stdin = os.Stdin
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	if err := cmd.Run(); err != nil {
		return editorFinishedMsg{err: err}
	}

	// Read back the content
	content, err := os.ReadFile(tmpFile.Name())
	if err != nil {
		return editorFinishedMsg{err: err}
	}

	return editorFinishedMsg{content: string(content)}
}

// formatForEditor adds line breaks to make content more readable in the editor
func formatForEditor(content string) string {
	// Add line breaks after markdown headers
	content = strings.ReplaceAll(content, "# ", "\n# ")
	content = strings.ReplaceAll(content, "## ", "\n## ")
	content = strings.ReplaceAll(content, "### ", "\n### ")

	// Add line breaks before list items
	content = strings.ReplaceAll(content, "- ", "\n- ")
	content = strings.ReplaceAll(content, "* ", "\n* ")

	// Add line breaks after periods followed by uppercase (likely new sentences)
	content = strings.ReplaceAll(content, ". ", ".\n")

	// Clean up multiple consecutive newlines
	for strings.Contains(content, "\n\n\n") {
		content = strings.ReplaceAll(content, "\n\n\n", "\n\n")
	}

	// Trim leading/trailing whitespace
	content = strings.TrimSpace(content)

	return content
}

func (m setupModel) updateAgentEdit(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.agentEditField > 0 {
				m.agentEditField--
			}
		case "down", "j":
			if m.agentEditField < 1 {
				m.agentEditField++
			}
		case "enter":
			// Open external editor for selected field
			var initialContent string
			if m.agentEditField == 0 {
				initialContent = m.agentDescInput.Value()
			} else {
				initialContent = m.agentPromptInput.Value()
			}
			// Format content for better readability in editor
			initialContent = formatForEditor(initialContent)
			// Execute editor synchronously
			result := openEditorSync(initialContent)
			if result.err == nil && result.content != "" {
				if m.agentEditField == 0 {
					m.agentDescInput.SetValue(strings.TrimSpace(result.content))
				} else {
					m.agentPromptInput.SetValue(strings.TrimSpace(result.content))
				}
			}
		case "s":
			// Save changes
			m.saveAgentEdit(m.agentSelected)
			m.agentList = m.loadAgentList()
			m.step = stepAgentMenu
		case "q", "esc":
			m.step = stepAgentMenu
		}
	case editorFinishedMsg:
		if msg.err == nil && msg.content != "" {
			// Update the appropriate field
			if m.agentEditField == 0 {
				m.agentDescInput.SetValue(strings.TrimSpace(msg.content))
			} else {
				m.agentPromptInput.SetValue(strings.TrimSpace(msg.content))
			}
		}
	}
	return m, nil
}

func (m *setupModel) loadAgentForEdit(name string) {
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}

	filePath := filepath.Join(agentsDir, name+".md")
	content, err := os.ReadFile(filePath)
	if err != nil {
		return
	}

	contentStr := string(content)

	// Parse frontmatter to get description
	if strings.HasPrefix(contentStr, "---") {
		endIdx := strings.Index(contentStr[3:], "---")
		if endIdx > 0 {
			frontmatter := contentStr[3 : endIdx+3]
			// Extract description
			if descIdx := strings.Index(frontmatter, "description:"); descIdx >= 0 {
				lines := strings.Split(frontmatter[descIdx:], "\n")
				if len(lines) > 0 {
					desc := strings.TrimPrefix(lines[0], "description:")
					m.agentDescInput.SetValue(strings.TrimSpace(desc))
				}
			}
			// Get prompt (content after frontmatter)
			promptStart := endIdx + 6 // After "---\n"
			if promptStart < len(contentStr) {
				prompt := strings.TrimSpace(contentStr[promptStart:])
				m.agentPromptInput.SetValue(prompt)
			}
		}
	}

	m.agentEditField = 0
	m.agentDescInput.Focus()
}

func (m *setupModel) saveAgentEdit(name string) error {
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}

	// Read existing file to get mode and tools
	filePath := filepath.Join(agentsDir, name+".md")
	existingContent, err := os.ReadFile(filePath)
	mode := "subagent"
	toolsConfig := ""

	if err == nil {
		contentStr := string(existingContent)
		if strings.HasPrefix(contentStr, "---") {
			endIdx := strings.Index(contentStr[3:], "---")
			if endIdx > 0 {
				frontmatter := contentStr[3 : endIdx+3]
				// Extract mode
				if modeIdx := strings.Index(frontmatter, "mode:"); modeIdx >= 0 {
					lines := strings.Split(frontmatter[modeIdx:], "\n")
					if len(lines) > 0 {
						mode = strings.TrimSpace(strings.TrimPrefix(lines[0], "mode:"))
					}
				}
				// Extract tools
				if toolsIdx := strings.Index(frontmatter, "tools:"); toolsIdx >= 0 {
					// Find end of tools section
					toolsEnd := strings.Index(frontmatter[toolsIdx:], "\n\n")
					if toolsEnd < 0 {
						toolsEnd = len(frontmatter) - toolsIdx
					}
					toolsConfig = frontmatter[toolsIdx:toolsIdx+toolsEnd] + "\n"
				}
			}
		}
	}

	description := strings.TrimSpace(m.agentDescInput.Value())
	if description == "" {
		description = fmt.Sprintf("Agent %s", name)
	}

	prompt := strings.TrimSpace(m.agentPromptInput.Value())
	if prompt == "" {
		prompt = fmt.Sprintf("You are %s, a helpful assistant.", name)
	}

	content := fmt.Sprintf(`---
description: %s
mode: %s
%s---
%s
`, description, mode, toolsConfig, prompt)

	// Save to OpenCode
	if err := os.WriteFile(filePath, []byte(content), 0644); err != nil {
		return err
	}

	// Save to Copilot
	copilotDir := filepath.Join(os.Getenv("HOME"), ".github", "copilot", "agents")
	copilotPath := filepath.Join(copilotDir, name+".md")
	os.MkdirAll(copilotDir, 0755)
	os.WriteFile(copilotPath, []byte(content), 0644)

	return nil
}

func (m setupModel) loadAgentContent(name string) (string, error) {
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}

	filePath := filepath.Join(agentsDir, name+".md")
	content, err := os.ReadFile(filePath)
	if err != nil {
		return "", err
	}
	return string(content), nil
}

func (m setupModel) updateAgentDeleteConfirm(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "y":
			if m.agentToDelete != "" {
				m.deleteAgentFile(m.agentToDelete)
				m.agentList = m.loadAgentList()
				if m.agentListCursor >= len(m.agentList) {
					m.agentListCursor = len(m.agentList) - 1
					if m.agentListCursor < 0 {
						m.agentListCursor = 0
					}
				}
			}
			m.agentToDelete = ""
			m.step = stepAgentList
		case "n", "esc":
			m.agentToDelete = ""
			m.step = stepAgentList
		}
	}
	return m, nil
}

func (m setupModel) deleteAgentFile(name string) error {
	// Delete from OpenCode
	agentsDir := filepath.Join(os.Getenv("HOME"), ".config", "opencode", "agents")
	if xdgConfig := os.Getenv("XDG_CONFIG_HOME"); xdgConfig != "" {
		agentsDir = filepath.Join(xdgConfig, "opencode", "agents")
	}
	opencodePath := filepath.Join(agentsDir, name+".md")
	os.Remove(opencodePath)

	// Delete from Copilot
	copilotDir := filepath.Join(os.Getenv("HOME"), ".github", "copilot", "agents")
	copilotPath := filepath.Join(copilotDir, name+".md")
	os.Remove(copilotPath)

	return nil
}

// File browser methods

func (m setupModel) loadFileBrowser(dir string) []os.DirEntry {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return []os.DirEntry{}
	}

	// Filter to show only directories and .md files
	var filtered []os.DirEntry
	for _, entry := range entries {
		if entry.IsDir() || strings.HasSuffix(entry.Name(), ".md") {
			filtered = append(filtered, entry)
		}
	}
	return filtered
}

func (m setupModel) updateFileBrowser(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.fileBrowserCursor > 0 {
				m.fileBrowserCursor--
			}
		case "down", "j":
			if m.fileBrowserCursor < len(m.fileBrowserEntries)-1 {
				m.fileBrowserCursor++
			}
		case "enter":
			if m.fileBrowserCursor < len(m.fileBrowserEntries) {
				entry := m.fileBrowserEntries[m.fileBrowserCursor]
				m.pathInput.SetValue(filepath.Join(m.fileBrowserDir, entry.Name()))
				m.step = stepPath
				m.pathInput.Focus()
			} else {
				m.pathInput.SetValue(m.fileBrowserDir)
				m.step = stepPath
				m.pathInput.Focus()
			}
		case "ctrl+l":
			if m.fileBrowserCursor < len(m.fileBrowserEntries) {
				entry := m.fileBrowserEntries[m.fileBrowserCursor]
				if entry.IsDir() {
					// Navigate into directory
					m.fileBrowserDir = filepath.Join(m.fileBrowserDir, entry.Name())
					m.fileBrowserEntries = m.loadFileBrowser(m.fileBrowserDir)
					m.fileBrowserCursor = 0
				}
			}
		case "ctrl+b":
			// Go up one directory
			parent := filepath.Dir(m.fileBrowserDir)
			if parent != m.fileBrowserDir {
				m.fileBrowserDir = parent
				m.fileBrowserEntries = m.loadFileBrowser(m.fileBrowserDir)
				m.fileBrowserCursor = 0
			}
		case "ctrl+q", "esc":
			m.step = stepPath
			m.pathInput.Focus()
		}
	}
	return m, nil
}

func (m setupModel) renderFileBrowserStep() string {
	box := activeBoxStyle.Render("File Browser")

	// Current path
	pathLine := infoStyle.Render("Current: " + m.fileBrowserDir)

	if len(m.fileBrowserEntries) == 0 {
		return lipgloss.JoinVertical(
			lipgloss.Left,
			box,
			"",
			pathLine,
			"",
			infoStyle.Render("No directories or .md files found."),
			"",
			helpStyle.Render("Press q to go back"),
		)
	}

	var items []string
	for idx, entry := range m.fileBrowserEntries {
		prefix := "  "
		s := itemStyle

		if idx == m.fileBrowserCursor {
			prefix = "▸ "
			s = selectedItemStyle
		}

		name := entry.Name()
		if entry.IsDir() {
			name = "📁 " + name + "/"
		} else {
			name = "📄 " + name
		}

		items = append(items, s.Render(prefix+name))
	}

	content := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		pathLine,
		"",
		infoStyle.Render("Enter selects the highlighted item. Use Ctrl+L to open a folder."),
		"",
		content,
		"",
		helpStyle.Render("Tip: press esc to go back without changing the path."),
	)
}

func (m setupModel) renderAgentMenuStep() string {
	box := activeBoxStyle.Render("Agent Menu")

	var items []string
	for idx, option := range m.agentMenuOptions {
		prefix := "  "
		s := itemStyle

		if idx == m.agentMenuCursor {
			prefix = "▸ "
			s = selectedItemStyle
		}

		items = append(items, s.Render(prefix+option))
	}

	menu := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render(fmt.Sprintf("Agent: %s", m.agentSelected)),
		"",
		menu,
	)
}

func (m setupModel) renderAgentViewStep() string {
	box := activeBoxStyle.Render("View Agent")

	// Split content into lines and limit to screen height
	lines := strings.Split(m.agentViewContent, "\n")
	var contentLines []string
	for i, line := range lines {
		if i >= 20 { // Limit to 20 lines
			contentLines = append(contentLines, "...")
			break
		}
		contentLines = append(contentLines, line)
	}

	content := lipgloss.NewStyle().
		Foreground(lipgloss.Color("250")).
		Render(strings.Join(contentLines, "\n"))

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render(fmt.Sprintf("Agent: %s", m.agentSelected)),
		"",
		content,
		"",
		helpStyle.Render("Press Enter or q to go back"),
	)
}

func (m setupModel) renderAgentEditStep() string {
	box := activeBoxStyle.Render("Edit Agent")

	fields := []struct {
		label string
		input string
	}{
		{"Description:", m.agentDescInput.View()},
		{"Prompt:", m.agentPromptInput.View()},
		{"Tools:", "[read] [write] [edit] [bash] (use create new to change)"},
	}

	var items []string
	for idx, field := range fields {
		prefix := "  "
		s := itemStyle

		if idx == m.agentEditField {
			prefix = "▸ "
			s = selectedItemStyle
		}

		line := fmt.Sprintf("%s%s\n    %s", prefix, field.label, field.input)
		items = append(items, s.Render(line))
	}

	content := lipgloss.JoinVertical(lipgloss.Left, items...)

	return lipgloss.JoinVertical(
		lipgloss.Left,
		box,
		"",
		infoStyle.Render(fmt.Sprintf("Editing: %s", m.agentSelected)),
		"",
		content,
		"",
		helpStyle.Render("↑↓ select • Enter open editor • s save • q cancel"),
	)
}

// ── Global Tools ────────────────────────────────────────────────────

func (m setupModel) updateGlobalTools(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "up", "k":
			if m.globalToolCursor > 0 {
				m.globalToolCursor--
			}
		case "down", "j":
			if m.globalToolCursor < len(m.globalToolNames)-1 {
				m.globalToolCursor++
			}
		case " ":
			m.globalToolValues[m.globalToolCursor] = !m.globalToolValues[m.globalToolCursor]
		case "a":
			allSelected := true
			for _, v := range m.globalToolValues {
				if !v {
					allSelected = false
					break
				}
			}
			for i := range m.globalToolValues {
				m.globalToolValues[i] = !allSelected
			}
		case "enter":
			m.step = stepGlobalToolsRunning
			m.globalToolOutput = ""
			return m, tea.Tick(0, func(t time.Time) tea.Msg {
				return globalToolsStartMsg{}
			})
		case "q", "esc":
			m.step = stepWelcome
		}
	}
	return m, nil
}

type globalToolsStartMsg struct{}
type globalToolsDoneMsg struct{ output string }
type globalToolsLogMsg struct{ line string }

func (m setupModel) updateGlobalToolsRunning(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case globalToolsStartMsg:
		m.spinner, _ = m.spinner.Update(spinner.TickMsg{})
		return m, func() tea.Msg {
			var buf strings.Builder
			flags := &installer.Flags{
				Force:   true,
				Silent:  false,
				DryRun:  false,
				Channel: "stable",
			}

			inst := installer.New(flags)

			for i, name := range m.globalToolNames {
				if !m.globalToolValues[i] {
					continue
				}
				line := fmt.Sprintf("  %s ...\n", name)
				buf.WriteString(line)

				switch i {
				case 0: // GA
					if err := inst.UpdateGA(); err != nil {
						buf.WriteString(fmt.Sprintf("    ✗ %v\n", err))
					} else {
						buf.WriteString("    ✓ done\n")
					}
				case 1: // SDD
					if err := inst.UpdateSDD(); err != nil {
						buf.WriteString(fmt.Sprintf("    ✗ %v\n", err))
					} else {
						buf.WriteString("    ✓ done\n")
					}
				case 2: // Global agents
					if err := inst.UpdateGlobalAgents(); err != nil {
						buf.WriteString(fmt.Sprintf("    ✗ %v\n", err))
					} else {
						buf.WriteString("    ✓ done\n")
					}
				case 3: // Engram
					if err := inst.UpdateEngram(); err != nil {
						buf.WriteString(fmt.Sprintf("    ✗ %v\n", err))
					} else {
						buf.WriteString("    ✓ done\n")
					}
				case 4: // Context7
					if err := inst.UpdateContext7(); err != nil {
						buf.WriteString(fmt.Sprintf("    ✗ %v\n", err))
					} else {
						buf.WriteString("    ✓ done\n")
					}
				}
			}

			buf.WriteString("\nDone.")
			return globalToolsDoneMsg{output: buf.String()}
		}
	case globalToolsDoneMsg:
		m.globalToolOutput = msg.output
		m.globalToolDone = true
		m.step = stepGlobalTools
		return m, nil
	case spinner.TickMsg:
		var cmd tea.Cmd
		m.spinner, cmd = m.spinner.Update(msg)
		return m, cmd
	}
	return m, nil
}

func (m setupModel) renderGlobalToolsStep() string {
	subtitle := subtitleStyle.Render("Select which global tools to update (no repo needed)")

	var items []string
	for idx, name := range m.globalToolNames {
		marker := "[ ]"
		if m.globalToolValues[idx] {
			marker = "[✓]"
		}
		line := fmt.Sprintf("%s %s", marker, name)
		if idx == m.globalToolCursor {
			items = append(items, selectedItemStyle.Render("▸ "+line))
		} else {
			items = append(items, itemStyle.Render("  "+line))
		}
	}

	menu := lipgloss.JoinVertical(lipgloss.Left, items...)

	parts := []string{
		subtitle,
		"",
		infoStyle.Render("Space toggle • a select all • Enter confirm • q back"),
		"",
		menu,
	}

	if m.globalToolOutput != "" {
		parts = append(parts, "", boxStyle.Render(m.globalToolOutput))
	}

	return lipgloss.JoinVertical(lipgloss.Left, parts...)
}

func (m setupModel) renderGlobalToolsRunningStep() string {
	return lipgloss.JoinVertical(
		lipgloss.Left,
		subtitleStyle.Render("Updating global tools..."),
		"",
		m.spinner.View()+" Working...",
	)
}
