package main

import (
	"errors"

	"github.com/charmbracelet/lipgloss"
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
