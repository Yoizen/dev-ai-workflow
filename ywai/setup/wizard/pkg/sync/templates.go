package sync

import (
	"path/filepath"
	"regexp"
	"strings"
)

func (s *Sync) analyzeAgentsMD() *AgentsMDChanges {
	changes := &AgentsMDChanges{}

	typeConfig, ok := s.typesCfg.Types[s.projectType]
	if !ok {
		return changes
	}

	templatePath := s.resolveTemplatePath(typeConfig.AgentsMD, "AGENTS.md")
	if templatePath == "" {
		return changes
	}

	templateContent := s.readFile(templatePath)

	currentPath := filepath.Join(s.targetDir, "AGENTS.md")
	currentContent := ""
	if s.fileExists(currentPath) {
		currentContent = s.readFile(currentPath)
	}

	changes.NewSections = s.findNewSections(templateContent, currentContent)
	changes.UpdatedTables = s.findUpdatedTables(templateContent, currentContent)
	changes.ManagedBlocks = s.extractManagedBlocks(templateContent)

	return changes
}

func (s *Sync) analyzeReviewMD() *ReviewMDChanges {
	changes := &ReviewMDChanges{}

	typeConfig, ok := s.typesCfg.Types[s.projectType]
	if !ok {
		return changes
	}

	templatePath := s.resolveTemplatePath(typeConfig.ReviewMD, "REVIEW.md")
	if templatePath == "" {
		return changes
	}

	templateContent := s.readFile(templatePath)

	currentPath := filepath.Join(s.targetDir, "REVIEW.md")
	currentContent := ""
	if s.fileExists(currentPath) {
		currentContent = s.readFile(currentPath)
	}

	changes.NewRules = s.findNewRules(templateContent, currentContent)

	return changes
}

func (s *Sync) resolveTemplatePath(relativePath, filename string) string {
	var candidates []string

	if s.repoRoot != "" {
		candidates = []string{
			filepath.Join(s.repoRoot, relativePath),
			filepath.Join(s.repoRoot, "ywai", relativePath),
			filepath.Join(s.repoRoot, "ywai", "setup", relativePath),
			filepath.Join(s.repoRoot, "types", strings.TrimPrefix(relativePath, "setup/types/")),
			filepath.Join(s.repoRoot, "ywai", "types", strings.TrimPrefix(relativePath, "setup/types/")),
		}
	}

	candidates = append(candidates,
		filepath.Join(s.targetDir, relativePath),
		filepath.Join(s.targetDir, "ywai", relativePath),
		filepath.Join(s.targetDir, "ywai", "setup", relativePath),
		filepath.Join(s.targetDir, "types", strings.TrimPrefix(relativePath, "setup/types/")),
		filepath.Join(s.targetDir, "ywai", "types", strings.TrimPrefix(relativePath, "setup/types/")),
	)

	for _, path := range candidates {
		if s.fileExists(path) {
			return path
		}
	}

	return ""
}

func (s *Sync) findNewSections(template, current string) []SectionInfo {
	var sections []SectionInfo

	templateSections := extractSections(template)
	currentSections := extractSections(current)

	for _, ts := range templateSections {
		if !sectionExists(currentSections, ts.Title) {
			sections = append(sections, SectionInfo{
				Title:   ts.Title,
				After:   findPreviousSection(templateSections, ts.Title),
				Content: ts.Content,
			})
		}
	}

	return sections
}

type section struct {
	Title   string
	Content string
}

func extractSections(content string) []section {
	var sections []section

	sectionRegex := regexp.MustCompile(`(?m)^##\s+(.+)$`)
	matches := sectionRegex.FindAllStringSubmatchIndex(content, -1)

	for i, match := range matches {
		title := content[match[2]:match[3]]

		start := match[1]
		end := len(content)
		if i+1 < len(matches) {
			end = matches[i+1][0]
		}

		sectionContent := strings.TrimSpace(content[start:end])

		sections = append(sections, section{
			Title:   strings.TrimSpace(title),
			Content: sectionContent,
		})
	}

	return sections
}

func sectionExists(sections []section, title string) bool {
	for _, s := range sections {
		if strings.EqualFold(s.Title, title) {
			return true
		}
	}
	return false
}

func findPreviousSection(sections []section, title string) string {
	for i, s := range sections {
		if s.Title == title && i > 0 {
			return sections[i-1].Title
		}
	}
	return ""
}

func (s *Sync) findUpdatedTables(template, current string) []TableInfo {
	var tables []TableInfo

	tableRegex := regexp.MustCompile(`(?m)^\|\s*(.+?)\s*\|.*\|\s*$`)
	tableNameRegex := regexp.MustCompile(`(?m)^###?\s+(.+?)(?:\s+Table)?\s*$`)

	templateTables := extractTables(template)
	currentTables := extractTables(current)

	for name, templateRows := range templateTables {
		currentRows, exists := currentTables[name]
		if !exists {
			continue
		}

		var newRows []string
		for _, row := range templateRows {
			if !rowExists(currentRows, row) {
				newRows = append(newRows, row)
			}
		}

		if len(newRows) > 0 {
			tables = append(tables, TableInfo{
				Name:    name,
				AddRows: newRows,
			})
		}
	}

	_ = tableRegex
	_ = tableNameRegex

	return tables
}

func extractTables(content string) map[string][]string {
	tables := make(map[string][]string)

	lines := strings.Split(content, "\n")
	var currentTable string
	var inTable bool

	for _, line := range lines {
		if strings.HasPrefix(line, "### ") || strings.HasPrefix(line, "## ") {
			if inTable {
				inTable = false
			}
			currentTable = strings.TrimSpace(strings.TrimPrefix(strings.TrimPrefix(line, "### "), "## "))
			continue
		}

		if strings.HasPrefix(line, "|") && strings.Contains(line, "|") {
			if !inTable {
				inTable = true
			}
			if currentTable != "" {
				if !strings.Contains(line, "---") {
					tables[currentTable] = append(tables[currentTable], line)
				}
			}
		} else if inTable && line == "" {
			inTable = false
		}
	}

	return tables
}

func rowExists(rows []string, row string) bool {
	normalizedRow := normalizeTableRow(row)
	for _, r := range rows {
		if normalizeTableRow(r) == normalizedRow {
			return true
		}
	}
	return false
}

func normalizeTableRow(row string) string {
	row = strings.TrimSpace(row)
	row = regexp.MustCompile(`\s+`).ReplaceAllString(row, " ")
	return row
}

func (s *Sync) extractManagedBlocks(content string) []ManagedBlock {
	var blocks []ManagedBlock

	startRegex := regexp.MustCompile(`(?s)<!--\s*YWAI:SYNC:START:(\w+)\s*-->(.*?)<!--\s*YWAI:SYNC:END:\w+\s*-->`)
	matches := startRegex.FindAllStringSubmatch(content, -1)

	for _, match := range matches {
		if len(match) >= 3 {
			blocks = append(blocks, ManagedBlock{
				BlockID: match[1],
				Content: strings.TrimSpace(match[2]),
			})
		}
	}

	return blocks
}

func (s *Sync) findNewRules(template, current string) []RuleInfo {
	var rules []RuleInfo

	templateRules := extractRules(template)
	currentRules := extractRules(current)

	for _, tr := range templateRules {
		if !ruleExists(currentRules, tr.Title) {
			rules = append(rules, RuleInfo{
				Title:       tr.Title,
				After:       findPreviousRule(templateRules, tr.Title),
				Description: tr.Description,
			})
		}
	}

	return rules
}

type rule struct {
	Title       string
	Description string
}

func extractRules(content string) []rule {
	var rules []rule

	lines := strings.Split(content, "\n")
	var currentSection string

	for _, line := range lines {
		trimmed := strings.TrimSpace(line)

		if strings.HasPrefix(trimmed, "## ") {
			currentSection = strings.TrimPrefix(trimmed, "## ")
			continue
		}

		if strings.HasPrefix(trimmed, "- ") || strings.HasPrefix(trimmed, "* ") {
			ruleText := strings.TrimPrefix(strings.TrimPrefix(trimmed, "- "), "* ")

			if strings.HasPrefix(ruleText, "❌") {
				ruleText = strings.TrimPrefix(ruleText, "❌")
			}
			ruleText = strings.TrimSpace(ruleText)

			if ruleText != "" {
				rules = append(rules, rule{
					Title:       currentSection + " > " + ruleText,
					Description: ruleText,
				})
			}
		}
	}

	return rules
}

func ruleExists(rules []rule, title string) bool {
	for _, r := range rules {
		if strings.EqualFold(r.Title, title) {
			return true
		}
	}
	return false
}

func findPreviousRule(rules []rule, title string) string {
	for i, r := range rules {
		if r.Title == title && i > 0 {
			return rules[i-1].Title
		}
	}
	return ""
}
