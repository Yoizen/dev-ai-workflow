package main

import (
	"fmt"
	"strings"
	"time"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	"github.com/charmbracelet/bubbles/spinner"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

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
		maxW := 50
		if m.width > 0 {
			maxW = m.width / 2
			if maxW < 40 {
				maxW = 40
			}
		}
		box := boxStyle.Width(maxW).Render(m.globalToolOutput)
		parts = append(parts, "", box)
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
