package main

import (
	"os"
	"strings"

	"github.com/Yoizen/dev-ai-workflow/ywai/setup/wizard/pkg/installer"
	tea "github.com/charmbracelet/bubbletea"
)

type installLogMsg struct {
	line string
}

type installFinishedMsg struct {
	err error
}

func (m setupModel) buildProjectInstallFlags() installer.Flags {
	flags := installer.Flags{}
	if m.baseFlags != nil {
		flags = *m.baseFlags
	}

	target := strings.TrimSpace(m.pathInput.Value())
	if target == "" {
		if wd, err := os.Getwd(); err == nil {
			target = wd
		}
	}

	flags.Target = target
	flags.ProjectType = m.projectTypeValues[m.projectTypeIdx]
	flags.Provider = m.providerValues[m.providerIdx]
	flags.UpdateAll = m.updateMode

	flags.InstallGA = m.componentValues[0]
	flags.InstallSDD = m.componentValues[1]
	flags.InstallVSCode = m.componentValues[2]
	flags.InstallExt = m.componentValues[3]
	flags.InstallGlobal = m.componentValues[4]
	flags.DryRun = m.componentValues[5]
	flags.Silent = true

	if strings.EqualFold(flags.Provider, "opencode") && !flags.SkipVSCode && !flags.InstallVSCode {
		flags.InstallVSCode = true
	}
	if strings.EqualFold(flags.Provider, "opencode") && !flags.InstallExt {
		flags.InstallExt = true
	}
	if strings.EqualFold(flags.Provider, "opencode") && !flags.InstallGlobal {
		flags.InstallGlobal = true
	}

	if !flags.UpdateAll && flags.InstallGA && flags.InstallSDD && flags.InstallVSCode && flags.InstallExt {
		flags.All = true
	}

	return flags
}

func (m setupModel) installPhaseTotal(flags installer.Flags) int {
	total := 0

	if !flags.SkipGA {
		total++
	}
	if flags.InstallSDD && !flags.SkipSDD {
		total++
	}
	if flags.InstallVSCode && !flags.SkipVSCode {
		total++
	}

	// OpenCode, project configuration, and extensions are always part of the
	// main installation flow.
	total += 3

	if total <= 0 {
		total = 1
	}

	return total
}

func (m setupModel) beginProjectInstallation() (tea.Model, tea.Cmd) {
	flags := m.buildProjectInstallFlags()

	if m.installStream == nil {
		m.installStream = &streamState{}
	}

	m.installLogs = nil
	m.installCurrent = ""
	m.installProgress = 0
	m.installTotal = m.installPhaseTotal(flags)
	m.installSeenStages = map[string]bool{}
	m.installErr = nil
	m.err = nil
	m.done = false
	m.step = stepInstalling

	return m, m.startInstallerCmd(flags)
}

func (m setupModel) startInstallerCmd(flags installer.Flags) tea.Cmd {
	stream := m.installStream

	return func() tea.Msg {
		if stream != nil {
			flags.Output = stream.writer
		}

		inst := installer.New(&flags)
		err := inst.Run()

		if err == nil {
			inst.ShowNextSteps()
		}

		if flusher, ok := flags.Output.(interface{ Flush() }); ok {
			flusher.Flush()
		}

		return installFinishedMsg{err: err}
	}
}

func (m setupModel) updateInstallLog(msg installLogMsg) (tea.Model, tea.Cmd) {
	line := strings.TrimRight(msg.line, "\r")
	if line == "" {
		return m, nil
	}

	m.installLogs = append(m.installLogs, line)
	if len(m.installLogs) > 18 {
		m.installLogs = append([]string(nil), m.installLogs[len(m.installLogs)-18:]...)
	}

	if stage := m.detectInstallStage(line); stage != "" {
		if m.installSeenStages == nil {
			m.installSeenStages = map[string]bool{}
		}
		if !m.installSeenStages[stage] {
			m.installSeenStages[stage] = true
			if m.installProgress < m.installTotal {
				m.installProgress++
			}
		}
		m.installCurrent = stage
	}

	return m, nil
}

func (m setupModel) updateInstallFinished(msg installFinishedMsg) (tea.Model, tea.Cmd) {
	m.installErr = msg.err
	m.done = true
	m.step = stepDone
	if msg.err == nil {
		m.installProgress = m.installTotal
	}
	return m, nil
}

func (m setupModel) detectInstallStage(line string) string {
	clean := strings.ToLower(strings.TrimSpace(line))

	switch {
	case strings.Contains(clean, "ga already installed"):
		return "Installing GA"
	case strings.Contains(clean, "installing ga"):
		return "Installing GA"
	case strings.Contains(clean, "sdd orchestrator installed"):
		return "Installing SDD"
	case strings.Contains(clean, "installing sdd"):
		return "Installing SDD"
	case strings.Contains(clean, "vs code cli not available"):
		return "Installing VS Code extensions"
	case strings.Contains(clean, "installing vs code extensions"):
		return "Installing VS Code extensions"
	case strings.Contains(clean, "opencode cli already installed"):
		return "Installing OpenCode CLI"
	case strings.Contains(clean, "opencode cli installed"):
		return "Installing OpenCode CLI"
	case strings.Contains(clean, "installing opencode cli"):
		return "Installing OpenCode CLI"
	case strings.Contains(clean, "configuring project"):
		return "Configuring project"
	case strings.Contains(clean, "installing extensions"):
		return "Installing extensions"
	default:
		return ""
	}
}
