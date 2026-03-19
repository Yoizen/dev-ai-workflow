package main

import (
	"fmt"
	"os"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	syncpkg "github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/sync"
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
	stepAgentType
	stepAgentName
	stepAgentDescription
	stepAgentPrompt
	stepAgentTools
	stepAgentConfirm
	stepAgentDone
	stepAgentList
	stepAgentMenu
	stepAgentView
	stepAgentEdit
	stepAgentDeleteConfirm
	stepFileBrowser
	stepGlobalTools
	stepGlobalToolsRunning
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

	agentList        []AgentInfo
	agentListCursor  int
	agentToDelete    string
	agentSelected    string
	agentMenuCursor  int
	agentMenuOptions []string
	agentViewContent string
	agentEditField   int

	fileBrowserDir     string
	fileBrowserEntries []os.DirEntry
	fileBrowserCursor  int

	skillInstallMode bool
	skillOptions     []syncpkg.SkillInfo
	skillValues      []bool
	skillCursor      int
	skillLoadError   error

	globalToolNames  []string
	globalToolValues []bool
	globalToolCursor int
	globalToolDone   bool
	globalToolOutput string
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
		componentValues:    []bool{true, true, true, true, false, false},
		agentTypeIdx:       0,
		agentTypeOptions:   []string{"primary", "subagent"},
		agentNameInput:     nameTi,
		agentDescInput:     descTi,
		agentPromptInput:   promptTi,
		agentToolNames:     []string{"read", "write", "edit", "bash"},
		agentToolValues:    []bool{true, true, true, false},
		agentToolCursor:    0,
		agentCreated:       false,
		agentError:         nil,
		agentList:          []AgentInfo{},
		agentListCursor:    0,
		agentToDelete:      "",
		agentSelected:      "",
		agentMenuCursor:    0,
		agentMenuOptions:   []string{"View", "Edit", "Delete", "Back"},
		agentViewContent:   "",
		agentEditField:     0,
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

	if m.width == 0 || m.height == 0 {
		return ""
	}

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
