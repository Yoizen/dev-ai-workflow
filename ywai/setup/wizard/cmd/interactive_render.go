package main

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
)

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
