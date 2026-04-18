package main

import (
	"errors"

	"github.com/charmbracelet/lipgloss"
)

var (
	// Primary brand colors
	primaryColor = lipgloss.Color("99")   // purple
	secondaryColor = lipgloss.Color("86") // cyan
	tertiaryColor = lipgloss.Color("208") // amber

	// Semantic colors
	successColor = lipgloss.Color("84")  // green
	errorColor = lipgloss.Color("167")   // red
	warningColor = lipgloss.Color("208") // amber
	infoColor = lipgloss.Color("245")    // gray-blue

	// Neutral scale
	textPrimary = lipgloss.Color("255")   // white
	textSecondary = lipgloss.Color("245") // light gray
	textMuted = lipgloss.Color("241")    // gray
	borderColor = lipgloss.Color("236")   // dark gray
	surfaceColor = lipgloss.Color("235")  // very dark gray

	brandStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(secondaryColor).
			Background(borderColor).
			Padding(0, 1)

	titleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(primaryColor)

	subtitleStyle = lipgloss.NewStyle().
			Foreground(textSecondary)

	infoStyle = lipgloss.NewStyle().
			Foreground(textMuted)

	helpStyle = lipgloss.NewStyle().
			Foreground(textMuted)

	itemStyle = lipgloss.NewStyle().
			PaddingLeft(2)

	selectedItemStyle = lipgloss.NewStyle().
				Bold(true).
				Foreground(secondaryColor).
				Background(surfaceColor).
				Padding(0, 1)

	errorStyle = lipgloss.NewStyle().
			Foreground(errorColor)

	successStyle = lipgloss.NewStyle().
			Foreground(successColor)

	warningStyle = lipgloss.NewStyle().
			Foreground(warningColor)

	boxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(borderColor).
			Padding(1, 2)

	activeBoxStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(primaryColor).
			Foreground(textPrimary).
			Padding(1, 2)

	// New card styles for visual hierarchy
	cardStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(borderColor).
			Padding(1, 2)

	cardActiveStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(primaryColor).
			Padding(1, 2)

	cardSuccessStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(successColor).
			Padding(1, 2)

	cardErrorStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(errorColor).
			Padding(1, 2)

	// Typography hierarchy
	h1Style = lipgloss.NewStyle().
			Bold(true).
			Foreground(primaryColor)

	h2Style = lipgloss.NewStyle().
			Bold(true).
			Foreground(textPrimary)

	h3Style = lipgloss.NewStyle().
			Bold(true).
			Foreground(textPrimary)

	bodyStyle = lipgloss.NewStyle().
			Foreground(textSecondary)

	captionStyle = lipgloss.NewStyle().
			Foreground(textMuted)

	monoStyle = lipgloss.NewStyle().
			Foreground(secondaryColor)
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
