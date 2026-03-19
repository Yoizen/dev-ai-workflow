package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
)

type editorFinishedMsg struct {
	content string
	err     error
}

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
