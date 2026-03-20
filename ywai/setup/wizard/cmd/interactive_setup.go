package main

import (
	"fmt"
	"os"
	"path/filepath"
	"strings"

	syncpkg "github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/sync"
	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/ui"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

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
			return m.beginProjectInstallation()
		case "n", "b":
			m.step = stepComponents
		}
	}
	return m, nil
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
